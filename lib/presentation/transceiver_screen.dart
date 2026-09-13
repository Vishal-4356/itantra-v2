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
    'or': 'ଓଡ଼ିଆ (Odia)',
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
    -1: 'Auto',
    0: 'Medic',
    1: 'Fire',
    2: 'Threat',
    3: 'Search',
    4: 'Breach',
    5: 'Collapse',
    6: 'Ammo',
    7: 'Comms',
    8: 'Done',
    9: 'SOS',
    10: 'Route',
    11: 'Evac',
    12: 'Secure',
    13: 'Standby',
    14: 'Meet',
    15: 'Gas',
  };

  static const Map<int, IconData> _intentIcons = {
    -1: Icons.sensors_rounded,
    0: Icons.favorite_border_rounded,
    1: Icons.local_fire_department_outlined,
    2: Icons.warning_amber_rounded,
    3: Icons.search_rounded,
    4: Icons.shield_outlined,
    5: Icons.domain_disabled_rounded,
    6: Icons.inventory_2_outlined,
    7: Icons.cell_tower_rounded,
    8: Icons.check_circle_outline_rounded,
    9: Icons.sos_rounded,
    10: Icons.alt_route_rounded,
    11: Icons.medical_services_outlined,
    12: Icons.verified_user_outlined,
    13: Icons.pause_circle_outline_rounded,
    14: Icons.location_on_outlined,
    15: Icons.science_outlined,
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

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
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

    // Zero-config automatic P2P peer discovery & subnet scan on startup
    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _networkManager.scanSubnet();
      if (mounted) setState(() {});
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

    transmitIntent(0); // Default emergency intent if general mic talk
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
          localizedText: '⚠️ SOS DISTRESS SENT',
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
    const peachBg = Color(0xFFF6ECE3);
    const darkBrown = Color(0xFF5A3E36);
    const softRed = Color(0xFFC84B4B);
    const shadowLight = Colors.white;
    const shadowDark = Color(0xFFE2D2C5);

    return Scaffold(
      backgroundColor: peachBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Header: iTANTRA title, Neumorphic IP Connect Button & SOS Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'iTANTRA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: darkBrown,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Dedicated Neumorphic IP / Mesh Connection Button
                  GestureDetector(
                    onTap: _showPeerConnectDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: peachBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: shadowLight,
                            offset: Offset(-3, -3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: shadowDark,
                            offset: Offset(3, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hub_rounded,
                            size: 16,
                            color: _networkManager.knownPeerIps.isNotEmpty ? const Color(0xFF2E7D32) : darkBrown,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_networkManager.localIpAddress ?? "P2P IP"} (${_networkManager.knownPeerIps.length})',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _networkManager.knownPeerIps.isNotEmpty ? const Color(0xFF2E7D32) : darkBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Neumorphic Raised SOS Button
                  GestureDetector(
                    onTap: _triggerEmergencySos,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: peachBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: shadowLight,
                            offset: Offset(-3, -3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: shadowDark,
                            offset: Offset(3, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: softRed),
                          SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: softRed,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sunken Neumorphic Language Dropdown Slot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E4D9), // Recessed slot color
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFE0CFBE),
                      offset: Offset(3, 3),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: shadowLight,
                      offset: Offset(-3, -3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: darkBrown, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          dropdownColor: const Color(0xFFF6ECE3),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: darkBrown),
                          items: _languages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: darkBrown,
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Activity Log Feed / Messages (Neumorphic Recessed Display Slot)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E4D9), // Recessed slot color
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE0CFBE),
                        offset: Offset(3, 3),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: shadowLight,
                        offset: Offset(-3, -3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Ready for P2P Transmission\nHold Push-To-Talk button below to speak',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8C6F66),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(4),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isEmerg = msg.isEmergency;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: peachBg,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: shadowLight,
                                    offset: Offset(-2, -2),
                                    blurRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: shadowDark,
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (isEmerg)
                                    const Icon(Icons.warning_amber_rounded, size: 18, color: softRed)
                                  else
                                    const Icon(Icons.record_voice_over_rounded, size: 18, color: darkBrown),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      msg.localizedText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isEmerg ? softRed : darkBrown,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${msg.endToEndLatencyMs}ms',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isEmerg ? softRed : darkBrown,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Hero PTT Button (Giant Circular Raised Neumorphic Disc)
              GestureDetector(
                onTapDown: (_) => _startTransmitting(),
                onTapUp: (_) => _stopTransmitting(),
                onTapCancel: () => _stopTransmitting(),
                child: ScaleTransition(
                  scale: _isTransmitting ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: peachBg,
                      boxShadow: [
                        BoxShadow(
                          color: shadowLight,
                          offset: const Offset(-10, -10),
                          blurRadius: 20,
                        ),
                        BoxShadow(
                          color: _isTransmitting ? softRed.withOpacity(0.4) : shadowDark,
                          offset: const Offset(10, 10),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isTransmitting ? Icons.mic : Icons.mic_none_outlined,
                          size: 56,
                          color: _isTransmitting ? softRed : darkBrown,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isTransmitting ? 'TRANSMITTING' : 'HOLD TO TALK',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: _isTransmitting ? softRed : darkBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Bottom Neumorphic Action Chips / Intent Selector Buttons
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _intentNames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final id = _intentNames.keys.elementAt(index);
                    final name = _intentNames[id]!;
                    final icon = _intentIcons[id] ?? Icons.radio_button_checked_rounded;
                    final isSelected = _selectedIntentId == id;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIntentId = id);
                        if (id >= 0) {
                          transmitIntent(id);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 72,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECE0D5) : peachBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0xFFDCCBC0),
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: shadowLight,
                                    offset: Offset(-2, -2),
                                    blurRadius: 4,
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: shadowLight,
                                    offset: Offset(-4, -4),
                                    blurRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: shadowDark,
                                    offset: Offset(4, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 22,
                              color: isSelected ? softRed : darkBrown,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? softRed : darkBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeerConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6ECE3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF5A3E36)),
              SizedBox(width: 8),
              Text(
                'Mesh Peer Connection',
                style: TextStyle(color: Color(0xFF5A3E36), fontSize: 16, fontWeight: FontWeight.bold),
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
                  color: Color(0xFF5A3E36),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connected Peers: ${_networkManager.knownPeerIps.isEmpty ? "None yet" : _networkManager.knownPeerIps.join(", ")}',
                style: const TextStyle(color: Color(0xFF7A5A50), fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFF5A3E36), fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Target Peer IP (e.g. 192.168.43.x)',
                  labelStyle: const TextStyle(color: Color(0xFF7A5A50), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF0E4D9),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5A3E36), width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDFCDBF)),
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
              child: const Text('Scan Subnet', style: TextStyle(color: Color(0xFF5A3E36), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A3E36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
