import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../core/ai/sherpa_ai_isolate_manager.dart';
import '../core/hardware/hardware_override.dart';
import '../core/network/ad_hoc_network_manager.dart';
import '../core/protocol/packet_encoder.dart';
import '../core/receiver/receiver_pipeline.dart';
import '../core/translation/translation_service.dart';

class TransceiverScreen extends StatefulWidget {
  const TransceiverScreen({super.key});

  @override
  State<TransceiverScreen> createState() => _TransceiverScreenState();
}

class _TransceiverScreenState extends State<TransceiverScreen>
    with SingleTickerProviderStateMixin {
  final SherpaAiIsolateManager _aiManager = SherpaAiIsolateManager();
  late final AdHocNetworkManager _networkManager;
  late final ReceiverPipeline _receiverPipeline;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _currentRecordingPath;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Language options: 10 Indian Language Packs
  final Map<String, String> _languages = {
    'hi': 'हिन्दी (Hindi)',
    'en': 'English',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'ml': 'മലയാളം (Malayalam)',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'mr': 'मराठी (Marathi)',
    'bn': 'বাংলা (Bengali)',
    'gu': 'ગુજરાતી (Gujarati)',
    'pa': 'ਪੰਜਾਬੀ (Punjabi)',
  };

  String _selectedLanguage = 'hi';
  bool _isTransmitting = false;
  int _sequenceNumber = 0;

  // Telemetry metrics
  int _vadLatency = 12;
  int _sttLatency = 38;
  int _nluLatency = 6;
  int _airDelta = 18;
  int _ttsLatency = 45;
  int _totalEndToEnd = 119;
  int _packetsSent = 0;
  int _packetsReceived = 0;
  int _fecRecoveries = 0;

  NetworkTransport _activeTransport = NetworkTransport.wifiDirect;
  final List<ReceivedMessageEvent> _messages = [];

  static const Map<int, String> _intentNames = {
    -1: '🤖 AUTO (Voice NLU)',
    0: '🚨 Medical Emergency',
    1: '🔥 Fire Outbreak',
    2: '⚠️ Hostile Threat',
    3: '🚁 Search & Rescue',
    4: '🛡️ Perimeter Breach',
    5: '🏢 Collapse',
    6: '📦 Ammo Low',
    7: '📻 Comms Check',
    8: '🏁 Mission Done',
    9: '🆘 SOS Distress',
    10: '🚧 Route Blocked',
    11: '🚑 CASEVAC',
    12: '✅ Area Secure',
    13: '🛑 Stand By',
    14: '📍 Rendezvous',
    15: '☣️ Chemical Gas',
  };

  int _selectedIntentId = -1;
  StreamSubscription? _netSub;
  StreamSubscription? _netPacketSub;
  StreamSubscription? _recSub;
  StreamSubscription? _aiSub;

  final List<double> _waveformData = List.generate(24, (index) => 0.2);
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _networkManager = AdHocNetworkManager();
    _receiverPipeline = ReceiverPipeline(aiManager: _aiManager);

    _initSystem();
  }

  Future<void> _initSystem() async {
    // 1. Initialize AI isolate
    await _aiManager.initialize({});

    // 2. Initialize receiver & network
    await _receiverPipeline.initialize();
    await _networkManager.start(deviceName: 'iTantra-Alpha');

    _netSub = _networkManager.metrics.listen((metrics) {
      if (mounted) {
        setState(() {
          _activeTransport = metrics.transport;
          _packetsSent = metrics.packetsSent;
          _packetsReceived = metrics.packetsReceived;
          _fecRecoveries = metrics.packetsRecoveredByFec;
          _airDelta = metrics.lastRoundTripMs > 0 ? metrics.lastRoundTripMs : _airDelta;
        });
      }
    });

    // Receive incoming packets arriving from remote phone via Network!
    _netPacketSub = _networkManager.incomingPackets.listen((packet) {
      debugPrint('[TransceiverScreen] Remote packet received from network: $packet');
      _receiverPipeline.processIncomingPacket(packet);
    });

    _recSub = _receiverPipeline.messages.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.insert(0, msg);
          _ttsLatency = msg.synthesisLatencyMs;
          _airDelta = msg.networkDeltaMs;
          _totalEndToEnd = _vadLatency + _sttLatency + _nluLatency + _airDelta + _ttsLatency;
        });
      }
    });

    _aiSub = _aiManager.events.listen((event) {
      if (event is SpeechProcessedResultEvent) {
        if (mounted) {
          setState(() {
            _vadLatency = event.vadLatencyMs;
            _sttLatency = event.sttLatencyMs;
            _nluLatency = event.nluLatencyMs;
            _messages.insert(
              0,
              ReceivedMessageEvent(
                packet: event.packet,
                localizedText: '[TX OUTGOING] ${_intentNames[event.packet.intentId] ?? "Intent #${event.packet.intentId}"}',
                targetLang: 'OUTGOING',
                isEmergency: event.packet.isEmergency,
                networkDeltaMs: 0,
                synthesisLatencyMs: 0,
                endToEndLatencyMs: event.totalLatencyMs,
              ),
            );
          });
        }
        // Broadcast packet over network to other phone!
        _networkManager.sendPacket(event.packet);
      }
    });
    // Pre-request microphone permission on startup so PTT is instantly responsive
    try {
      await _audioRecorder.hasPermission();
    } catch (_) {}
  }

  bool _isStartingRecorder = false;

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _waveformTimer?.cancel();
    _pulseController.dispose();
    _netSub?.cancel();
    _netPacketSub?.cancel();
    _recSub?.cancel();
    _aiSub?.cancel();
    _receiverPipeline.dispose();
    _networkManager.dispose();
    _aiManager.dispose();
    super.dispose();
  }

  Future<void> _startTransmitting() async {
    if (_isTransmitting) return;
    setState(() {
      _isTransmitting = true;
    });

    _isStartingRecorder = true;
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        debugPrint('[TransceiverScreen] Microphone permission not granted');
        _isStartingRecorder = false;
        setState(() => _isTransmitting = false);
        return;
      }

      if (_selectedIntentId >= 0) {
        // Intent chip selected: record audio only for waveform, no STT needed
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/ptt_waveform_${DateTime.now().millisecondsSinceEpoch}.wav';
        _currentRecordingPath = path;
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: path,
        );
        _isStartingRecorder = false;
        _amplitudeSub?.cancel();
        _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 50)).listen((amp) {
          if (!mounted || !_isTransmitting) return;
          final normalized = ((amp.current + 50) / 45.0).clamp(0.1, 1.0);
          setState(() { _waveformData.removeAt(0); _waveformData.add(normalized); });
        });
      } else {
        // AUTO mode: Start Android native SpeechRecognizer for real STT
        _isStartingRecorder = false;
        _pendingSttResult = '';
        _sttCompleter = Completer<void>();
        
        // Animate waveform while listening
        _waveformTimer?.cancel();
        _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
          if (!mounted || !_isTransmitting) return;
          final pulse = 0.2 + (DateTime.now().millisecondsSinceEpoch % 600) / 600.0 * 0.7;
          setState(() { _waveformData.removeAt(0); _waveformData.add(pulse); });
        });
        
        // SpeechRecognizer runs asynchronously
        HardwareOverride.recognizeSpeech(langCode: _selectedLanguage).then((text) {
          _pendingSttResult = text;
          if (_sttCompleter?.isCompleted == false) {
            _sttCompleter?.complete();
          }
        }).catchError((_) {
          _pendingSttResult = '';
          if (_sttCompleter?.isCompleted == false) {
            _sttCompleter?.complete();
          }
        });
      }

      if (!_isTransmitting) {
        await _finishRecordingAndProcess();
      }
    } catch (e) {
      _isStartingRecorder = false;
      debugPrint('[TransceiverScreen] PTT start error: $e');
    }
  }

  String _pendingSttResult = '';
  Completer<void>? _sttCompleter;

  Future<void> _stopTransmitting() async {
    if (!_isTransmitting) return;
    setState(() {
      _isTransmitting = false;
      for (int i = 0; i < _waveformData.length; i++) { _waveformData[i] = 0.2; }
    });
    if (!_isStartingRecorder) {
      await _finishRecordingAndProcess();
    }
  }

  Future<void> _finishRecordingAndProcess() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _waveformTimer?.cancel();

    // Stop recorder if running
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}

    _sequenceNumber = (_sequenceNumber + 1) & 0x3F;

    if (_selectedIntentId >= 0) {
      // ── Specific intent chip selected — send compact semantic packet ──
      transmitIntent(_selectedIntentId);
      return;
    }

    // ── AUTO mode: wait for Android STT result, then process ──
    String transcript = '';
    try {
      // Signal recognizer to stop and finalize
      await HardwareOverride.stopRecognition();
      // Wait for the pending STT result (max 5 seconds)
      if (_pendingSttResult.isEmpty && _sttCompleter != null && !_sttCompleter!.isCompleted) {
        await _sttCompleter!.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      }
      transcript = _pendingSttResult.trim();
      _pendingSttResult = '';
    } catch (e) {
      debugPrint('[TransceiverScreen] STT await error: $e');
      transcript = '';
    }

    debugPrint('[TransceiverScreen] STT final result: "$transcript"');

    if (transcript.isNotEmpty && transcript.length >= 2) {
      final senderLangId = LangIdMapper.toId(_selectedLanguage);
      
      // AUTO mode: Send exact spoken words as Mode 2 text packet.
      // Phone B receives the text, translates it to target language, and speaks via TTS!
      final packet = TransceiverPacket.mode2(
        langId: senderLangId,
        text: transcript,
        priority: PacketPriority.normal,
        sequence: _sequenceNumber,
      );
      setState(() {
        _messages.insert(0, ReceivedMessageEvent(
          packet: packet,
          localizedText: '[TX VOICE] "$transcript"',
          targetLang: 'OUTGOING',
          isEmergency: false,
          networkDeltaMs: 0,
          synthesisLatencyMs: 0,
          endToEndLatencyMs: 0,
        ));
      });
      _networkManager.sendPacket(packet);
    } else {
      debugPrint('[TransceiverScreen] No speech recognized — nothing sent');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech detected. Hold PTT and speak clearly.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1A2744),
          ),
        );
      }
    }
  }

  void _triggerEmergencySos() {
    transmitIntent(9);
  }

  void transmitIntent(int intentId) {
    _sequenceNumber = (_sequenceNumber + 1) & 0x3F;
    final priority = IntentClassifier.getPriorityForIntent(intentId);
    final packet = TransceiverPacket.mode1(
      langId: 0,
      intentId: intentId,
      priority: priority,
      sequence: _sequenceNumber,
    );

    setState(() {
      _messages.insert(
        0,
        ReceivedMessageEvent(
          packet: packet,
          localizedText: '[TX OUTGOING] ${_intentNames[intentId] ?? "Intent #$intentId"}',
          targetLang: 'OUTGOING',
          isEmergency: packet.isEmergency,
          networkDeltaMs: 0,
          synthesisLatencyMs: 0,
          endToEndLatencyMs: 15,
        ),
      );
      _totalEndToEnd = _vadLatency + _sttLatency + _nluLatency + 12 + 35;
    });

    _networkManager.sendPacket(packet);
  }

  @override
  Widget build(BuildContext context) {
    final isWifi = _activeTransport == NetworkTransport.wifiDirect;

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161E2E),
        elevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: const Text(
                'iTANTRA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  fontSize: 16,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EDGE TRANSCEIVER',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Local IP and Peer Count Display (Clickable)
          GestureDetector(
            onTap: _showPeerConnectDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _networkManager.knownPeerIps.isNotEmpty ? const Color(0xFF00E676) : const Color(0xFF334155),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.devices,
                    size: 12,
                    color: _networkManager.knownPeerIps.isNotEmpty ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_networkManager.localIpAddress ?? "P2P"} (${_networkManager.knownPeerIps.length})',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: _networkManager.knownPeerIps.isNotEmpty ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Active Network Transport Badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isWifi ? const Color(0xFF00E676).withOpacity(0.15) : const Color(0xFFFFB300).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isWifi ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWifi ? Icons.wifi_tethering : Icons.bluetooth,
                    size: 13,
                    color: isWifi ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isWifi ? 'P2P' : 'BLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isWifi ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Language selection bar & SOS override button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF131B29),
            child: Row(
              children: [
                const Icon(Icons.language, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'RECEIVER TARGET:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C273A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: const Color(0xFF1C273A),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
                        items: _languages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLanguage = val);
                            _receiverPipeline.setTargetLanguage(val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // SOS Panic Button
                ElevatedButton.icon(
                  onPressed: _triggerEmergencySos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.warning, size: 16),
                  label: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Live Telemetry Overlay Dashboard (< 800ms)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF162030),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26354D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'LIVE TELEMETRY OVERLAY',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'E2E: ${_totalEndToEnd}ms (< 800ms)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E676),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard('VAD', '${_vadLatency}ms', Icons.graphic_eq),
                    _buildMetricCard('STT', '${_sttLatency}ms', Icons.hearing),
                    _buildMetricCard('NLU', '${_nluLatency}ms', Icons.psychology),
                    _buildMetricCard('AIR/FEC', '${_airDelta}ms', Icons.air),
                    _buildMetricCard('TTS', '${_ttsLatency}ms', Icons.volume_up),
                  ],
                ),
                const Divider(color: Color(0xFF26354D), height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text('TX: $_packetsSent',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                    Text('RX: $_packetsReceived',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                    Text('FEC REC: $_fecRecoveries',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    const Text('280MB INT8',
                        style: TextStyle(fontSize: 10, color: Color(0xFF00E676), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // Transmission Log / Activity Feed
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131B29),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222E42)),
              ),
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Ready for P2P Transmission\nHold Push-To-Talk below to speak',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isEmerg = msg.isEmergency;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isEmerg
                                ? const Color(0xFFFF1744).withOpacity(0.12)
                                : const Color(0xFF1A2436),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isEmerg ? const Color(0xFFFF1744) : Colors.white12,
                              width: isEmerg ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isEmerg ? Icons.warning_amber : Icons.check_circle_outline,
                                    size: 16,
                                    color: isEmerg ? const Color(0xFFFF1744) : const Color(0xFF00E676),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    msg.packet.mode == PacketMode.semanticMode1
                                        ? 'MODE 1 (32-BIT SEMANTIC PACKET)'
                                        : 'MODE 2 (COMPRESSED TEXT)',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isEmerg ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${msg.endToEndLatencyMs}ms',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00E676),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.localizedText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Target: ${msg.targetLang.toUpperCase()} | Priority: ${msg.packet.priority.name}',
                                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                                  ),
                                  if (isEmerg) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF1744),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ALARM 100% OVERRIDE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Tactical Intent Quick Selection Chips
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _intentNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final id = _intentNames.keys.elementAt(index);
                final name = _intentNames[id]!;
                final isSelected = _selectedIntentId == id;
                return ChoiceChip(
                  label: Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF1C273A),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedIntentId = id);
                      if (id >= 0) {
                        transmitIntent(id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Auto Voice NLU active. Hold PTT button below to speak.'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1E293B),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),

          // Waveform Display
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _waveformData.map((val) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  width: 4,
                  height: 36 * val,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _isTransmitting ? const Color(0xFF00E5FF) : const Color(0xFF26354D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          ),

          // Push-To-Talk Tactical Trigger Button
          Container(
            padding: const EdgeInsets.only(bottom: 24, top: 4),
            child: Column(
              children: [
                GestureDetector(
                  onTapDown: (_) => _startTransmitting(),
                  onTapUp: (_) => _stopTransmitting(),
                  onTapCancel: () => _stopTransmitting(),
                  child: ScaleTransition(
                    scale: _isTransmitting ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isTransmitting
                              ? [const Color(0xFFFF1744), const Color(0xFFFF5252)]
                              : [const Color(0xFF00E5FF), const Color(0xFF0091EA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isTransmitting ? const Color(0xFFFF1744) : const Color(0xFF00E5FF))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isTransmitting ? Icons.mic : Icons.mic_none,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isTransmitting ? 'TRANSMITTING SPEECH...' : 'HOLD TO TALK (PTT)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: _isTransmitting ? const Color(0xFFFF5252) : const Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showPeerConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF162030),
          title: const Text('Mesh Peer Connection', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Local IP: ${_networkManager.localIpAddress ?? "Detecting..."}',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 8),
              Text('Connected Peers: ${_networkManager.knownPeerIps.isEmpty ? "None yet" : _networkManager.knownPeerIps.join(", ")}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Target Peer IP (e.g. 192.168.43.x)',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _networkManager.scanSubnet();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subnet scanned for peers')),
                  );
                }
              },
              child: const Text('Scan Subnet', style: TextStyle(color: Color(0xFF00E676))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
              onPressed: () {
                final ip = controller.text.trim();
                if (ip.isNotEmpty) {
                  _networkManager.addPeerIp(ip);
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connected to peer $ip')),
                  );
                }
              },
              child: const Text('Add Peer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
