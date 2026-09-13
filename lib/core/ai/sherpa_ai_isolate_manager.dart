import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../protocol/packet_encoder.dart';

abstract class AiWorkerCommand {}

class ProcessAudioPcmCommand extends AiWorkerCommand {
  final Float32List pcmData;
  final int sampleRate;
  ProcessAudioPcmCommand(this.pcmData, {this.sampleRate = 16000});
}

class SynthesizeSpeechCommand extends AiWorkerCommand {
  final String text;
  final String targetLang;
  final int requestId;
  SynthesizeSpeechCommand({required this.text, required this.targetLang, required this.requestId});
}

abstract class AiWorkerEvent {}

class SpeechProcessedResultEvent extends AiWorkerEvent {
  final TransceiverPacket packet;
  final String transcriptText;
  final int intentId;
  final double confidenceScore;
  SpeechProcessedResultEvent({
    required this.packet,
    required this.transcriptText,
    required this.intentId,
    required this.confidenceScore,
  });
}

class SpeechSynthesizedResultEvent extends AiWorkerEvent {
  final int requestId;
  final Uint8List audioWavBytes;
  final int latencyMs;
  SpeechSynthesizedResultEvent({
    required this.requestId,
    required this.audioWavBytes,
    required this.latencyMs,
  });
}

class AiErrorEvent extends AiWorkerEvent {
  final String error;
  AiErrorEvent(this.error);
}

/// Enhanced Multi-Language NLU Rule & Intent Classifier for Mode 1 Intent Packets
class IntentClassifier {
  static final Map<int, List<String>> _intentKeywords = {
    0: [ // Medical Emergency
      'medical', 'doctor', 'ambulance', 'medic', 'injured', 'bleeding', 'hospital', 'wound', 'heart', 'patient', 'health',
      'डॉक्टर', 'अस्पताल', 'इलाज', 'चोट', 'मरीज', 'एम्बुलेंस', 'चिकित्सा', 'घायल',
      'மருத்துவர்', 'மருத்துவமனை', 'ஆம்புலன்ஸ்', 'காயம்',
      'వైద్యుడు', 'ఆసుపత్రి', 'గాయం',
      'ವೈದ್ಯ', 'ಆಸ್ಪತ್ರೆ',
    ],
    1: [ // Fire Outbreak
      'fire', 'flames', 'smoke', 'burning', 'blaze', 'extinguish', 'fire outbreak',
      'आग', 'धुआं', 'जल रहा', 'अग्नि',
      'தீ', 'புகை',
      'నిప్పు', 'పొగ',
      'ಬೆಂಕಿ',
    ],
    2: [ // Hostile Threat
      'hostile', 'threat', 'enemy', 'shooter', 'gunfire', 'cover', 'ambush', 'weapon', 'sniper', 'attack',
      'दुश्मन', 'हमला', 'खतरा', 'गोली', 'हथियार',
      'எதிரி', 'தாக்குதல்', 'ஆபத்து',
      'శత్రువు', 'దాడి',
      'ಶತ್ರು',
    ],
    3: [ // Search & Rescue
      'search', 'rescue', 'coordinates', 'locate', 'missing', 'find', 'search team',
      'खोज', 'बचाव', 'तलाशी', 'टीम',
      'தேடுதல்', 'மீட்பு',
      'శోధన', 'రక్షణ',
      'ಹುಡುಕಾಟ',
    ],
    4: [ // Perimeter Breach
      'perimeter', 'breach', 'infiltrate', 'reinforcement', 'fence', 'gate', 'backup', 'security',
      'घुसपैठ', 'सुरक्षा', 'गेट', 'बाड़', 'बैकअप',
      'ஊடுருவல்', 'பாதுகாப்பு',
      'రక్షణ', 'చొరబాటు',
    ],
    5: [ // Structure Collapse
      'collapse', 'structural', 'rubble', 'trapped', 'debris', 'fall', 'cave',
      'मलबा', 'गिर गया', 'फंसा', 'इमारत गिरी',
      'இடிபாடு', 'சிக்கிய',
      'శిథిలాలు',
    ],
    6: [ // Ammo & Supplies Low
      'ammunition', 'ammo', 'supplies', 'resupply', 'bullets', 'ration', 'water', 'food', 'low supplies',
      'खाना', 'पानी', 'गोली', 'राशन', 'सामग्री', 'कम',
      'உணவு', 'தண்ணீர்', 'தோட்டா',
      'ఆహారం', 'నీరు',
    ],
    7: [ // Comms Check
      'communications', 'comms', 'check', 'radio', 'report', 'status', 'signal', 'hello', 'testing', 'mic test',
      'हेलो', 'परीक्षण', 'संपर्क', 'आवाज', 'सिग्नल', 'हेलो टेस्टिंग',
      'வணக்கம்', 'சோதனை',
      'హలో', 'పరీక్ష',
    ],
    8: [ // Mission Complete
      'mission', 'complete', 'returning', 'base', 'objective', 'rtb', 'finished', 'done',
      'मिशन पूरा', 'खत्म', 'हो गया', 'वापसी', 'काम पूरा',
      'முடிந்தது', 'பணி',
      'పూర్తయింది',
    ],
    9: [ // SOS Distress
      'sos', 'mayday', 'emergency', 'distress', 'critical', 'urgent', 'help', 'save us', 'save me',
      'मदद', 'बचाओ', 'आपातकाल', 'जरूरी', 'मदद करो', 'एसओएस',
      'உதவி', 'காப்பாற்று',
      'సహాయం', 'కాపాడు',
      'ಸಹಾಯ',
    ],
    10: [ // Route Blocked
      'route', 'blocked', 'obstacle', 'alternate', 'detour', 'impassable', 'barrier', 'road closed',
      'रास्ता बंद', 'रुकावट', 'मार्ग बंद', 'सड़क बंद',
      'பாதை அடைப்பு', 'வழி',
      'దారి మూసివేత',
    ],
    11: [ // CASEVAC / Airlift
      'casevac', 'casualty', 'airlift', 'evacuation', 'critical patient', 'stretcher', 'evacuate',
      'इवेक्यूएशन', 'गंभीर मरीज', 'स्ट्रैचर',
      'வெளியேற்றம்', 'நோயாளி',
    ],
    12: [ // Area Secure
      'clear', 'secured', 'all clear', 'safe', 'area secure', 'protected',
      'सुरक्षित', 'साफ', 'सब ठीक', 'क्षेत्र सुरक्षित',
      'பாதுகாப்பானது', 'தெளிவு',
      'సురక్షితం',
    ],
    13: [ // Stand By / Wait
      'standby', 'wait', 'awaiting', 'hold', 'pause', 'instructions', 'hold position',
      'रुको', 'इंतजार', 'तैयार रहो', 'ठहरो',
      'காத்திரு', 'பொறு',
      'వేచి ఉండండి',
    ],
    14: [ // Rendezvous / Exfil
      'rendezvous', 'extraction', 'rv', 'exfil', 'rally', 'pickup point', 'meet point',
      'मिलने का स्थान', 'पिकअप', 'मीटिंग',
      'சந்திப்பு இடம்',
      'కలిసే స్థలం',
    ],
    15: [ // Chemical / Gas Hazard
      'hazard', 'chemical', 'gas', 'toxic', 'leak', 'fumes', 'radiation', 'poison',
      'जहरीली गैस', 'गैस लीक', 'रासायनिक',
      'நச்சு வாயு', 'வாயு கசிவு',
    ],
  };

  static MapEntry<int, double> classify(String text) {
    if (text.isEmpty) return const MapEntry(-1, 0.0);
    final lower = text.toLowerCase().trim();

    int bestIntent = -1;
    double highestScore = 0.0;

    for (final entry in _intentKeywords.entries) {
      int matches = 0;
      for (final keyword in entry.value) {
        final kwLower = keyword.toLowerCase();
        if (lower == kwLower) {
          matches += 3; // Exact match bonus
        } else if (lower.contains(kwLower)) {
          matches += 1;
        }
      }
      if (matches > 0) {
        // Base confidence starts at 0.65 for keyword match, up to 1.0
        final score = min(1.0, 0.65 + (matches * 0.10));
        if (score > highestScore) {
          highestScore = score;
          bestIntent = entry.key;
        }
      }
    }

    return MapEntry(bestIntent, highestScore);
  }

  static PacketPriority getPriorityForIntent(int intentId) {
    switch (intentId) {
      case 0: // Medical
      case 1: // Fire
      case 2: // Hostile
      case 5: // Collapse
      case 9: // SOS
      case 11: // CASEVAC
      case 15: // Chemical
        return PacketPriority.emergency;
      case 3: // Search & Rescue
      case 4: // Breach
      case 6: // Ammo Low
      case 10: // Route blocked
        return PacketPriority.high;
      default:
        return PacketPriority.normal;
    }
  }
}

/// Offline Marian / Opus-MT Simulated Indic Translator for Mode 2 Raw Text
class OfflineMachineTranslator {
  static final Map<String, String> _indicGlossary = {
    'danger': 'खतरा',
    'help': 'मदद',
    'doctor': 'डॉक्टर',
    'route': 'रास्ता',
    'water': 'पानी',
    'fire': 'आग',
    'clear': 'साफ',
    'emergency': 'आपातकाल',
  };

  static String translateToIndic(String text, String targetLang) {
    if (targetLang == 'en') return text;
    var result = text;
    _indicGlossary.forEach((en, hi) {
      result = result.replaceAll(RegExp(en, caseSensitive: false), hi);
    });
    return result;
  }
}

/// Worker Isolate for Audio Processing & Speech Synthesis (Mock/Fallback)
class SherpaAiIsolateManager {
  final StreamController<AiWorkerEvent> _eventController = StreamController<AiWorkerEvent>.broadcast();
  Stream<AiWorkerEvent> get events => _eventController.stream;

  bool _isReady = false;
  bool get isReady => _isReady;

  SherpaAiIsolateManager() {
    _initIsolate();
  }

  Future<void> _initIsolate() async {
    await Future.delayed(const Duration(milliseconds: 50));
    _isReady = true;
  }

  void processAudioPcm(Float32List pcmData, {int sampleRate = 16000}) {
    // Legacy PCM processing pathway if used directly
  }

  void synthesizeSpeech({required String text, required String targetLang, required int requestId}) {
    final bytes = Uint8List(0);
    _eventController.add(SpeechSynthesizedResultEvent(
      requestId: requestId,
      audioWavBytes: bytes,
      latencyMs: 35,
    ));
  }

  void dispose() {
    _eventController.close();
  }
}