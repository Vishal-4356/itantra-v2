import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Offline Indic phrase-level translator fallback (works with zero internet)
class OfflineIndicTranslator {
  // English phrase → Hindi translation
  static const Map<String, String> _hiDict = {
    'hello': 'नमस्ते',
    'hello testing': 'हेलो टेस्टिंग',
    'testing': 'परीक्षण',
    'test': 'परीक्षण',
    'doctor': 'डॉक्टर',
    'need doctor': 'डॉक्टर चाहिए',
    'ambulance': 'एम्बुलेंस',
    'emergency': 'आपातकाल',
    'help': 'मदद',
    'need help': 'मदद चाहिए',
    'fire': 'आग',
    'danger': 'खतरा',
    'water': 'पानी',
    'food': 'खाना',
    'route': 'रास्ता',
    'road': 'सड़क',
    'blocked': 'अवरुद्ध',
    'stop': 'रुकें',
    'go': 'जाओ',
    'move': 'आगे बढ़ो',
    'moving': 'आगे बढ़ रहे हैं',
    'safe': 'सुरक्षित',
    'clear': 'साफ',
    'secure': 'सुरक्षित',
    'yes': 'हाँ',
    'no': 'नहीं',
    'ok': 'ठीक है',
    'okay': 'ठीक है',
    'copy': 'समझ गया',
    'roger': 'समझ गया',
    'wait': 'रुको',
    'hold': 'रुको',
    'standby': 'तैयार रहो',
    'enemy': 'दुश्मन',
    'attack': 'हमला',
    'cover': 'छुपो',
    'team': 'टीम',
    'base': 'बेस',
    'sector': 'सेक्टर',
    'position': 'स्थान',
    'location': 'जगह',
    'meet': 'मिलो',
    'come': 'आओ',
    'send': 'भेजो',
    'confirm': 'पुष्टि करो',
    'report': 'रिपोर्ट',
    'status': 'स्थिति',
    'mission': 'मिशन',
    'complete': 'पूरा',
    'done': 'हो गया',
    'we are': 'हम',
    'i am': 'मैं हूं',
    'i need': 'मुझे चाहिए',
    'send help': 'मदद भेजो',
    'urgent': 'जरूरी',
    'immediately': 'तुरंत',
    'now': 'अभी',
  };

  static String translate(String text, String targetLang) {
    if (text.isEmpty || targetLang == 'en') return text;
    if (targetLang != 'hi') return text; // Only Hindi supported fully offline

    final lower = text.toLowerCase().trim();
    
    // Check full phrase match first
    if (_hiDict.containsKey(lower)) {
      return _hiDict[lower]!;
    }
    
    // Word-by-word substitution
    var result = text;
    // Sort by length descending so longer phrases are replaced first
    final sortedKeys = _hiDict.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final enPhrase in sortedKeys) {
      final regExp = RegExp(RegExp.escape(enPhrase), caseSensitive: false);
      result = result.replaceAll(regExp, _hiDict[enPhrase]!);
    }
    return result;
  }
}

/// Hybrid Translation Service: ML Kit (with auto-download) + Offline Fallback
class TranslationService {
  static final Map<String, OnDeviceTranslator> _translators = {};
  static final Set<String> _downloadAttempted = {};

  static TranslateLanguage? _toMlKitLang(String code) {
    switch (code.toLowerCase()) {
      case 'en': return TranslateLanguage.english;
      case 'hi': return TranslateLanguage.hindi;
      case 'ta': return TranslateLanguage.tamil;
      case 'te': return TranslateLanguage.telugu;
      case 'kn': return TranslateLanguage.kannada;
      case 'mr': return TranslateLanguage.marathi;
      case 'bn': return TranslateLanguage.bengali;
      case 'gu': return TranslateLanguage.gujarati;
      default: return null;
    }
  }

  /// Pre-warms ML Kit by downloading models in background (call on app start)
  static Future<void> prewarmModels(String targetLang) async {
    try {
      final src = _toMlKitLang('en');
      final tgt = _toMlKitLang(targetLang);
      if (src == null || tgt == null) return;
      final modelManager = OnDeviceTranslatorModelManager();
      final srcCode = src.bcpCode;
      final tgtCode = tgt.bcpCode;
      final srcReady = await modelManager.isModelDownloaded(srcCode);
      final tgtReady = await modelManager.isModelDownloaded(tgtCode);
      if (!srcReady) await modelManager.downloadModel(srcCode, isWifiRequired: false);
      if (!tgtReady) await modelManager.downloadModel(tgtCode, isWifiRequired: false);
      debugPrint('[Translation] Models ready for en->$targetLang');
    } catch (e) {
      debugPrint('[Translation] Prewarm failed (offline?): $e');
    }
  }

  static Future<String> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    if (text.isEmpty || fromLang == toLang) return text;

    // 1. Try ML Kit Translation
    try {
      final sourceLang = _toMlKitLang(fromLang);
      final targetLang = _toMlKitLang(toLang);

      if (sourceLang != null && targetLang != null) {
        final key = '${fromLang}_$toLang';
        _translators[key] ??= OnDeviceTranslator(
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
        );

        final modelManager = OnDeviceTranslatorModelManager();
        final srcCode = sourceLang.bcpCode;
        final tgtCode = targetLang.bcpCode;

        var srcReady = await modelManager.isModelDownloaded(srcCode);
        var tgtReady = await modelManager.isModelDownloaded(tgtCode);

        // Try downloading if not present (works if internet available)
        if (!srcReady && !_downloadAttempted.contains(srcCode)) {
          _downloadAttempted.add(srcCode);
          try {
            await modelManager.downloadModel(srcCode, isWifiRequired: false);
            srcReady = true;
          } catch (_) {}
        }
        if (!tgtReady && !_downloadAttempted.contains(tgtCode)) {
          _downloadAttempted.add(tgtCode);
          try {
            await modelManager.downloadModel(tgtCode, isWifiRequired: false);
            tgtReady = true;
          } catch (_) {}
        }

        if (srcReady && tgtReady) {
          final result = await _translators[key]!.translateText(text);
          if (result.isNotEmpty) {
            debugPrint('[Translation] MLKit $fromLang->$toLang: "$text" -> "$result"');
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('[Translation] MLKit error: $e');
    }

    // 2. Offline dictionary fallback
    final fallback = OfflineIndicTranslator.translate(text, toLang);
    debugPrint('[Translation] Offline $fromLang->$toLang: "$text" -> "$fallback"');
    return fallback;
  }

  static void dispose() {
    for (final t in _translators.values) { t.close(); }
    _translators.clear();
  }
}

/// Maps language codes to 4-bit packet langId and back
class LangIdMapper {
  static const Map<String, int> _codeToId = {
    'en': 0, 'hi': 1, 'ta': 2, 'te': 3,
    'ml': 4, 'kn': 5, 'mr': 6, 'bn': 7,
    'gu': 8, 'pa': 9,
  };
  static const Map<int, String> _idToCode = {
    0: 'en', 1: 'hi', 2: 'ta', 3: 'te',
    4: 'ml', 5: 'kn', 6: 'mr', 7: 'bn',
    8: 'gu', 9: 'pa',
  };

  static int toId(String langCode) => _codeToId[langCode] ?? 0;
  static String fromId(int langId) => _idToCode[langId] ?? 'en';
}