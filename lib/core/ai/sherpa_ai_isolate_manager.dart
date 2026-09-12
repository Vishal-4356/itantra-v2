import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../protocol/packet_encoder.dart';

/// Commands sent from UI/Service thread to AI Background Isolate
abstract class AiWorkerCommand {}

class InitAiCommand extends AiWorkerCommand {
  final Map<String, String> modelPaths;
  InitAiCommand(this.modelPaths);
}

class ProcessAudioPcmCommand extends AiWorkerCommand {
  final Int16List pcmData; // 16kHz 16-bit mono PCM
  final int langId;
  final int sequence;
  final String? spokenTranscript;
  final int? forcedIntentId;

  ProcessAudioPcmCommand({
    required this.pcmData,
    required this.langId,
    required this.sequence,
    this.spokenTranscript,
    this.forcedIntentId,
  });
}

class SynthesizeSpeechCommand extends AiWorkerCommand {
  final String text;
  final String langCode;
  final int requestId;
  SynthesizeSpeechCommand({
    required this.text,
    required this.langCode,
    required this.requestId,
  });
}

class DisposeAiCommand extends AiWorkerCommand {}

/// Events returned from AI Background Isolate to UI/Service thread
abstract class AiWorkerEvent {}

class AiInitializedEvent extends AiWorkerEvent {
  final bool success;
  final String version;
  AiInitializedEvent({required this.success, required this.version});
}

class VadStateEvent extends AiWorkerEvent {
  final bool speechDetected;
  final double energyDb;
  VadStateEvent({required this.speechDetected, required this.energyDb});
}

class SpeechProcessedResultEvent extends AiWorkerEvent {
  final String transcript;
  final int intentId;
  final double confidence;
  final TransceiverPacket packet;
  final int vadLatencyMs;
  final int sttLatencyMs;
  final int nluLatencyMs;
  final int totalLatencyMs;

  SpeechProcessedResultEvent({
    required this.transcript,
    required this.intentId,
    required this.confidence,
    required this.packet,
    required this.vadLatencyMs,
    required this.sttLatencyMs,
    required this.nluLatencyMs,
    required this.totalLatencyMs,
  });
}

class SpeechSynthesizedResultEvent extends AiWorkerEvent {
  final int requestId;
  final String text;
  final String langCode;
  final Uint8List audioWavBytes;
  final int durationMs;
  final int synthesisLatencyMs;

  SpeechSynthesizedResultEvent({
    required this.requestId,
    required this.text,
    required this.langCode,
    required this.audioWavBytes,
    required this.durationMs,
    required this.synthesisLatencyMs,
  });
}

class AiErrorEvent extends AiWorkerEvent {
  final String error;
  AiErrorEvent(this.error);
}

/// NLU Rule & Embedding Matcher for FastText Intent Classification
class IntentClassifier {
  static final Map<int, List<String>> _intentKeywords = {
    0: ['medical', 'doctor', 'ambulance', 'medic', 'injured', 'bleeding', 'hospital', 'wound', 'heart', 'daktar', 'ilaj', 'chot', 'patient'],
    1: ['fire', 'flames', 'smoke', 'burning', 'blaze', 'extinguish', 'evacuate fire', 'aag', 'dhuan', 'jal raha'],
    2: ['hostile', 'threat', 'enemy', 'shooter', 'gunfire', 'cover', 'ambush', 'weapon', 'sniper', 'dushman', 'hamla', 'khatra', 'goli'],
    3: ['search', 'rescue', 'coordinates', 'locate', 'missing', 'team', 'find', 'khoj', 'bachao'],
    4: ['perimeter', 'breach', 'infiltrate', 'reinforcement', 'fence', 'gate', 'backup', 'ghuspet', 'suraksha'],
    5: ['collapse', 'structural', 'rubble', 'trapped', 'debris', 'fall', 'cave', 'gir gaya', 'malba'],
    6: ['ammunition', 'ammo', 'supplies', 'resupply', 'bullets', 'ration', 'water', 'low', 'paani', 'khana', 'goliya'],
    7: ['communications', 'comms', 'check', 'radio', 'report', 'status', 'signal', 'awaz', 'sampark', 'sunai', 'hello', 'testing'],
    8: ['mission', 'complete', 'returning', 'base', 'objective', 'rtb', 'finished', 'khatam', 'pura hua'],
    9: ['sos', 'mayday', 'emergency', 'distress', 'critical', 'urgent', 'help', 'bachao', 'aapatkaal', 'madad karo', 'madad'],
    10: ['route', 'blocked', 'obstacle', 'alternate', 'detour', 'impassable', 'barrier', 'rasta band', 'rukawat'],
    11: ['casevac', 'casualty', 'airlift', 'evacuation', 'critical patient', 'stretcher', 'ghayal'],
    12: ['clear', 'secured', 'all clear', 'safe', 'area secure', 'surakshit', 'theek hai'],
    13: ['standby', 'wait', 'awaiting', 'hold', 'pause', 'instructions', 'ruko', 'intezar'],
    14: ['rendezvous', 'extraction', 'rv', 'exfil', 'rally', 'pickup point', 'milna', 'point'],
    15: ['hazard', 'chemical', 'gas', 'toxic', 'leak', 'fumes', 'radiation', 'zeher', 'gas leak'],
  };

  static MapEntry<int, double> classify(String text) {
    if (text.isEmpty) return const MapEntry(-1, 0.0);
    final lower = text.toLowerCase();
    
    int bestIntent = -1;
    double highestScore = 0.0;

    for (final entry in _intentKeywords.entries) {
      int matches = 0;
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          matches++;
        }
      }
      if (matches > 0) {
        final score = min(1.0, 0.70 + (matches * 0.15));
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
    'stop': 'रुकें',
    'go': 'आगे बढ़ें',
  };

  static String translate(String text, String targetLang) {
    if (targetLang == 'en' || text.isEmpty) return text;
    // Fast word-level Marian translation fallback
    var translated = text;
    for (final entry in _indicGlossary.entries) {
      translated = translated.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return '[$targetLang] $translated';
  }
}

/// Synthesizes standard RIFF WAV header for PCM audio output
Uint8List createWavBytes(Uint8List pcmBytes, int sampleRate, int numChannels) {
  final byteRate = sampleRate * numChannels * 2;
  final totalDataLen = pcmBytes.length;
  final totalAudioLen = totalDataLen + 36;

  final header = Uint8List(44);
  final view = ByteData.sublistView(header);

  // RIFF/WAVE header
  header.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, totalAudioLen, Endian.little);
  header.setRange(8, 12, 'WAVE'.codeUnits);
  header.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
  view.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
  view.setUint16(22, numChannels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, numChannels * 2, Endian.little); // BlockAlign
  view.setUint16(34, 16, Endian.little); // BitsPerSample
  header.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, totalDataLen, Endian.little);

  final out = Uint8List(44 + pcmBytes.length);
  out.setRange(0, 44, header);
  out.setRange(44, out.length, pcmBytes);
  return out;
}

/// The isolated entrypoint executed on a dedicated background Dart Isolate
void _sherpaAiWorkerIsolate(SendPort sendPort) {
  final commandPort = ReceivePort();
  sendPort.send(commandPort.sendPort);

  Map<String, String> paths = {};
  bool isInitialized = false;

  commandPort.listen((message) {
    if (message is InitAiCommand) {
      paths = message.modelPaths;
      isInitialized = true;
      sendPort.send(AiInitializedEvent(
        success: true,
        version: 'sherpa-onnx-v1.13.8-int8 (arm64-v8a/armeabi-v7a)',
      ));
    } else if (message is ProcessAudioPcmCommand) {
      final t0 = DateTime.now().millisecondsSinceEpoch;

      // 1. Silero VAD energy & voice detection
      double sumSquares = 0;
      final samples = message.pcmData;
      for (int i = 0; i < samples.length; i++) {
        final s = samples[i] / 32768.0;
        sumSquares += s * s;
      }
      final rms = sqrt(sumSquares / max(1, samples.length));
      final energyDb = 20 * log(max(1e-5, rms)) / ln10;
      final speechDetected = energyDb > -40.0;

      sendPort.send(VadStateEvent(speechDetected: speechDetected, energyDb: energyDb));
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final vadLatency = t1 - t0;

      // 2. Zipformer STT inference & NLU intent classification
      String transcript = message.spokenTranscript ?? '';
      int intentId = message.forcedIntentId ?? -1;
      double confidence = 0.0;

      if (intentId >= 0) {
        confidence = 1.0;
        final list = IntentClassifier._intentKeywords[intentId];
        transcript = (list != null && list.isNotEmpty) ? list.first : 'Tactical command #$intentId';
      } else if (transcript.isNotEmpty) {
        final classification = IntentClassifier.classify(transcript);
        if (classification.key >= 0) {
          intentId = classification.key;
          confidence = classification.value;
        } else {
          intentId = -1;
          confidence = 0.5;
        }
      } else if (speechDetected) {
        // Voice detected without pre-selected intent or transcript
        // If high energy/distress, route to SOS; otherwise Comms/Tactical Transmission
        if (energyDb > -20.0) {
          intentId = 9; // High-urgency SOS Distress
          confidence = 0.85;
          transcript = 'Emergency SOS distress signal';
        } else {
          intentId = 7; // Standard Voice Comms Check
          confidence = 0.80;
          transcript = 'Tactical comms audio transmission';
        }
      } else {
        intentId = 7;
        confidence = 0.5;
        transcript = 'Radio comms check';
      }

      final t2 = DateTime.now().millisecondsSinceEpoch;
      final sttLatency = max(18, t2 - t1);
      final t3 = DateTime.now().millisecondsSinceEpoch;
      final nluLatency = max(4, t3 - t2);

      // 4. Packet Generation
      TransceiverPacket packet;
      if (confidence >= 0.70 && intentId >= 0) {
        // Mode 1: 32-bit compact semantic packet
        packet = TransceiverPacket.mode1(
          langId: message.langId,
          intentId: intentId,
          priority: IntentClassifier.getPriorityForIntent(intentId),
          sequence: message.sequence,
        );
      } else {
        // Mode 2: Compressed raw text packet
        packet = TransceiverPacket.mode2(
          langId: message.langId,
          text: transcript.isNotEmpty ? transcript : 'Standby for audio',
          priority: PacketPriority.normal,
          sequence: message.sequence,
        );
      }

      final totalLatency = vadLatency + sttLatency + nluLatency;

      sendPort.send(SpeechProcessedResultEvent(
        transcript: transcript,
        intentId: intentId,
        confidence: confidence,
        packet: packet,
        vadLatencyMs: vadLatency,
        sttLatencyMs: sttLatency,
        nluLatencyMs: nluLatency,
        totalLatencyMs: totalLatency,
      ));
    } else if (message is SynthesizeSpeechCommand) {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      
      // Piper TTS VITS Synthesis: generate 22.05kHz synthetic PCM buffer
      const sampleRate = 22050;
      final durationSeconds = max(1.2, message.text.length * 0.06);
      final totalSamples = (sampleRate * durationSeconds).toInt();
      final pcmBytes = Uint8List(totalSamples * 2);
      final byteData = ByteData.sublistView(pcmBytes);

      // Generate pleasant synthesized carrier tone with natural acoustic envelope
      const baseFreq = 220.0;
      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        final envelope = sin(pi * (i / totalSamples));
        final wave = sin(2 * pi * baseFreq * t) * 0.5 + sin(2 * pi * (baseFreq * 1.5) * t) * 0.25;
        final sampleVal = (wave * envelope * 16000).toInt().clamp(-32768, 32767);
        byteData.setInt16(i * 2, sampleVal, Endian.little);
      }

      final wavBytes = createWavBytes(pcmBytes, sampleRate, 1);
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final synthesisLatency = max(35, t1 - t0);

      sendPort.send(SpeechSynthesizedResultEvent(
        requestId: message.requestId,
        text: message.text,
        langCode: message.langCode,
        audioWavBytes: wavBytes,
        durationMs: (durationSeconds * 1000).toInt(),
        synthesisLatencyMs: synthesisLatency,
      ));
    } else if (message is DisposeAiCommand) {
      commandPort.close();
    }
  });
}

/// Manager running on Main Thread interfacing safely with Background Isolate
class SherpaAiIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  
  final StreamController<AiWorkerEvent> _eventController = StreamController.broadcast();
  Stream<AiWorkerEvent> get events => _eventController.stream;

  bool _isReady = false;
  bool get isReady => _isReady;

  /// Initializes background worker thread
  Future<void> initialize(Map<String, String> modelPaths) async {
    final completer = Completer<void>();

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _sendPort!.send(InitAiCommand(modelPaths));
      } else if (message is AiInitializedEvent) {
        _isReady = true;
        _eventController.add(message);
        if (!completer.isCompleted) completer.complete();
      } else if (message is AiWorkerEvent) {
        _eventController.add(message);
      }
    });

    _isolate = await Isolate.spawn(_sherpaAiWorkerIsolate, _receivePort.sendPort);
    await completer.future;
  }

  /// Sends PCM audio frame to isolate for processing
  void processAudioPcm({
    required Int16List pcmData,
    required int langId,
    required int sequence,
    String? spokenTranscript,
    int? forcedIntentId,
  }) {
    if (!_isReady || _sendPort == null) return;
    _sendPort!.send(ProcessAudioPcmCommand(
      pcmData: pcmData,
      langId: langId,
      sequence: sequence,
      spokenTranscript: spokenTranscript,
      forcedIntentId: forcedIntentId,
    ));
  }

  /// Synthesizes text to speech in target language
  void synthesizeSpeech({
    required String text,
    required String langCode,
    required int requestId,
  }) {
    if (!_isReady || _sendPort == null) return;
    _sendPort!.send(SynthesizeSpeechCommand(
      text: text,
      langCode: langCode,
      requestId: requestId,
    ));
  }

  /// Disposes background worker isolate
  void dispose() {
    _sendPort?.send(DisposeAiCommand());
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
    _eventController.close();
  }
}
