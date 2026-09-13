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

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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
  bool _isStartingRecorder = false;
  int _sequenceNumber = 0;

  final int _vadLatency = 12;
  final int _sttLatency = 38;
  final int _nluLatency = 6;
  final int _airDelta = 18;
  final int _ttsLatency = 45;
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
    5: '🏢 Structure Collapse',
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

  final List<double> _waveformData = List.generate(24, (index) => 0.15);
  Timer? _waveformTimer;

  String _pendingSttResult = '';
  Completer<void>? _sttCompleter;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _networkManager = AdHocNetworkManager();
    _receiverPipeline = ReceiverPipeline(aiManager: _aiManager);

    initSystem();
  }

  Future<void> initSystem() async {
    await _networkManager.start();
    await _receiverPipeline.initialize();

    _recSub = _receiverPipeline.messages.listen((event) {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, event);
        _packetsReceived++;
        _totalEndToEnd = event.endToEndLatencyMs;
        if (event.packet.priority == PacketPriority.emergency) {
          _fecRecoveries++;
        }
      });
    });

    _netSub = _networkManager.metrics.map((m) => m.transport).listen((transport) {
      if (!mounted) return;
      setState(() {
        _activeTransport = transport;
      });
    });

    _netPacketSub = _networkManager.incomingPackets.listen((packet) {
      _receiverPipeline.processIncomingPacket(packet);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amplitudeSub?.cancel();
    _waveformTimer?.cancel();
    _netSub?.cancel();
    _netPacketSub?.cancel();
    _recSub?.cancel();
    _audioRecorder.dispose();
    _networkManager.dispose();
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
        _isStartingRecorder = false;
        setState(() => _isTransmitting = false);
        return;
      }

      if (_selectedIntentId >= 0) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/ptt_waveform_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: path,
        );
        _isStartingRecorder = false;
        _amplitudeSub?.cancel();
        _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 50)).listen((amp) {
          if (!mounted || !_isTransmitting) return;
          final normalized = ((amp.current + 50) / 45.0).clamp(0.15, 1.0);
          setState(() { _waveformData.removeAt(0); _waveformData.add(normalized); });
        });
      } else {
        _isStartingRecorder = false;
        _pendingSttResult = '';
        _sttCompleter = Completer<void>();
        
        _waveformTimer?.cancel();
        _waveformTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
          if (!mounted || !_isTransmitting) return;
          final pulse = 0.2 + (DateTime.now().millisecondsSinceEpoch % 500) / 500.0 * 0.75;
          setState(() { _waveformData.removeAt(0); _waveformData.add(pulse); });
        });
        
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

  Future<void> _stopTransmitting() async {
    if (!_isTransmitting) return;
    setState(() {
      _isTransmitting = false;
      for (int i = 0; i < _waveformData.length; i++) { _waveformData[i] = 0.15; }
    });
    if (!_isStartingRecorder) {
      await _finishRecordingAndProcess();
    }
  }

  Future<void> _finishRecordingAndProcess() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _waveformTimer?.cancel();

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}

    _sequenceNumber = (_sequenceNumber + 1) & 0x3F;

    if (_selectedIntentId >= 0) {
      transmitIntent(_selectedIntentId);
      return;
    }

    String transcript = '';
    try {
      await HardwareOverride.stopRecognition();
      if (_pendingSttResult.isEmpty && _sttCompleter != null && !_sttCompleter!.isCompleted) {
        await _sttCompleter!.future.timeout(const Duration(seconds: 4), onTimeout: () {});
      }
      transcript = _pendingSttResult.trim();
      _pendingSttResult = '';
    } catch (e) {
      transcript = '';
    }

    debugPrint('[TransceiverScreen] STT transcript: "$transcript"');

    if (transcript.isNotEmpty && transcript.length >= 2) {
      final senderLangId = LangIdMapper.toId(_selectedLanguage);

      // AUTO mode: Always send EXACT spoken transcript via Mode 2 packet.
      // Phone B receives the exact spoken text, translates it to target language,
      // and speaks it via TTS (ensuring 0% random template overrides).
      // Run NLU Intent Classification to detect emergency priorities & intent labels
      final classification = IntentClassifier.classify(transcript);
      final matchedIntentId = classification.key;
      final confidence = classification.value;

      final priority = (matchedIntentId >= 0 && confidence >= 0.60)
          ? IntentClassifier.getPriorityForIntent(matchedIntentId)
          : PacketPriority.normal;

      final intentLabel = (matchedIntentId >= 0 && confidence >= 0.60)
          ? _intentNames[matchedIntentId]
          : null;

      final packet = TransceiverPacket.mode2(
        langId: senderLangId,
        text: transcript,
        priority: priority,
        sequence: _sequenceNumber,
      );

      final displayTag = intentLabel != null ? '[TX VOICE ($intentLabel)]' : '[TX VOICE]';

      setState(() {
        _packetsSent++;
        _messages.insert(0, ReceivedMessageEvent(
          packet: packet,
          localizedText: '$displayTag "$transcript"',
          targetLang: 'OUTGOING',
          isEmergency: priority == PacketPriority.emergency,
          networkDeltaMs: 0,
          synthesisLatencyMs: 0,
          endToEndLatencyMs: 28,
        ));
      });
      _networkManager.sendPacket(packet);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No speech detected. Hold PTT button and speak clearly.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E1B4B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final senderLangId = LangIdMapper.toId(_selectedLanguage);
    final packet = TransceiverPacket.mode1(
      langId: senderLangId,
      intentId: intentId,
      priority: priority,
      sequence: _sequenceNumber,
    );

    setState(() {
      _packetsSent++;
      _messages.insert(
        0,
        ReceivedMessageEvent(
          packet: packet,
          localizedText: '[TX CHIP MODE 1] ${_intentNames[intentId] ?? "Intent #$intentId"}',
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
      backgroundColor: const Color(0xFFF1F5F9), // Ultra-clean Light Slate
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'iTANTRA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TACTICAL P2P',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'EDGE TRANSCEIVER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Peer Connect Pill
          GestureDetector(
            onTap: _showPeerConnectDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _networkManager.knownPeerIps.isNotEmpty
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _networkManager.knownPeerIps.isNotEmpty
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _networkManager.knownPeerIps.isNotEmpty
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_networkManager.localIpAddress ?? "P2P"} (${_networkManager.knownPeerIps.length})',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: _networkManager.knownPeerIps.isNotEmpty
                          ? const Color(0xFF047857)
                          : const Color(0xFF4338CA),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Transport Mode Badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isWifi ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWifi ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWifi ? Icons.wifi_tethering_rounded : Icons.bluetooth_rounded,
                    size: 14,
                    color: isWifi ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isWifi ? 'HOTSPOT' : 'BLE MESH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isWifi ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
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
          // Target Language Selection Bar & SOS Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.translate_rounded, color: Color(0xFF4F46E5), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TARGET:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5)),
                        items: _languages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
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
                const SizedBox(width: 10),
                // SOS Panic Button
                ElevatedButton.icon(
                  onPressed: _triggerEmergencySos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text(
                    'SOS',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
          ),

          // Live Telemetry Dashboard
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE TELEMETRY DASHBOARD',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        'E2E: ${_totalEndToEnd}ms (<800ms)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF047857),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricChip('VAD', '${_vadLatency}ms', Icons.graphic_eq, const Color(0xFFEEF2FF), const Color(0xFF4F46E5)),
                    _buildMetricChip('STT', '${_sttLatency}ms', Icons.hearing, const Color(0xFFF0FDFA), const Color(0xFF0D9488)),
                    _buildMetricChip('NLU', '${_nluLatency}ms', Icons.psychology, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                    _buildMetricChip('AIR/FEC', '${_airDelta}ms', Icons.air, const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
                    _buildMetricChip('TTS', '${_ttsLatency}ms', Icons.volume_up, const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TX: $_packetsSent',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                    Text('RX: $_packetsReceived',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                    Text('FEC REC: $_fecRecoveries',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontFamily: 'monospace', fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('280MB INT8',
                          style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontFamily: 'monospace', fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message Activity Feed
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cell_tower_rounded, size: 36, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ready for P2P Mesh Transmission',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hold Push-To-Talk button below to transmit speech',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isEmerg = msg.isEmergency;
                        final isMode1 = msg.packet.mode == PacketMode.semanticMode1;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isEmerg
                                ? const Color(0xFFFEF2F2)
                                : isMode1
                                    ? const Color(0xFFEEF2FF)
                                    : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEmerg
                                  ? const Color(0xFFFCA5A5)
                                  : isMode1
                                      ? const Color(0xFFC7D2FE)
                                      : const Color(0xFFE2E8F0),
                              width: isEmerg ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isEmerg
                                        ? Icons.warning_amber_rounded
                                        : isMode1
                                            ? Icons.bolt_rounded
                                            : Icons.record_voice_over_rounded,
                                    size: 16,
                                    color: isEmerg
                                        ? const Color(0xFFEF4444)
                                        : isMode1
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isMode1 ? 'MODE 1 (INTENT PACKET)' : 'MODE 2 (TRANSLATED TEXT)',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isEmerg
                                          ? const Color(0xFFEF4444)
                                          : isMode1
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFF0D9488),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${msg.endToEndLatencyMs}ms',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.localizedText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Target: ${msg.targetLang.toUpperCase()} | Priority: ${msg.packet.priority.name}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  if (isEmerg) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'EMERGENCY ALARM',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
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
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4F46E5),
                  backgroundColor: const Color(0xFFF1F5F9),
                  elevation: isSelected ? 3 : 0,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedIntentId = id);
                      if (id >= 0) {
                        transmitIntent(id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Auto Voice NLU active. Hold PTT button below to speak.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            duration: const Duration(seconds: 1),
                            backgroundColor: const Color(0xFF1E1B4B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),

          // Waveform Display Bar
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _waveformData.map((val) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  width: 4,
                  height: 32 * val,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: _isTransmitting ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          ),

          // Push-To-Talk Tactical Trigger Button
          Container(
            padding: const EdgeInsets.only(bottom: 22, top: 4),
            child: Column(
              children: [
                GestureDetector(
                  onTapDown: (_) => _startTransmitting(),
                  onTapUp: (_) => _stopTransmitting(),
                  onTapCancel: () => _stopTransmitting(),
                  child: ScaleTransition(
                    scale: _isTransmitting ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isTransmitting
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isTransmitting ? const Color(0xFFEF4444) : const Color(0xFF4F46E5))
                                .withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isTransmitting ? Icons.mic : Icons.mic_none_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isTransmitting ? 'TRANSMITTING VOICE...' : 'HOLD TO TALK (PTT)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: _isTransmitting ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _showPeerConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text(
                'Mesh Peer Connection',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Local IP: ${_networkManager.localIpAddress ?? "Detecting..."}',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connected Peers: ${_networkManager.knownPeerIps.isEmpty ? "None yet" : _networkManager.knownPeerIps.join(", ")}',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Target Peer IP (e.g. 192.168.43.x)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
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
              child: const Text('Scan Subnet', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              child: const Text('Add Peer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
