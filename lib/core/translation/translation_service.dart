import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

// ---------------------------------------------------------------------------
// Offline dictionary fallback (en->hi only; other pairs need ML Kit models)
// ---------------------------------------------------------------------------
class OfflineIndicTranslator {
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
    'north': 'उत्तर',
    'south': 'दक्षिण',
    'east': 'पूर्व',
    'west': 'पश्चिम',
    'left': 'बाएं',
    'right': 'दाएं',
    'forward': 'आगे',
    'back': 'पीछे',
    'retreat': 'पीछे हटो',
    'advance': 'आगे बढ़ो',
    'camp': 'शिविर',
    'hospital': 'अस्पताल',
    'injured': 'घायल',
    'wounded': 'घायल',
    'dead': 'मृत',
    'ammunition': 'गोला-बारूद',
    'ammo': 'गोला-बारूद',
    'fuel': 'ईंधन',
    'supply': 'आपूर्ति',
    'checkpoint': 'चेकपॉइंट',
    'border': 'सीमा',
    'bridge': 'पुल',
    'building': 'इमारत',
    'vehicle': 'वाहन',
    'helicopter': 'हेलीकॉप्टर',
    'aircraft': 'विमान',
  };

  static String translate(String text, String targetLang) {
    if (text.isEmpty || targetLang == 'en') return text;
    if (targetLang != 'hi') return text;

    final lower = text.toLowerCase().trim();
    if (_hiDict.containsKey(lower)) return _hiDict[lower]!;

    var result = text;
    final sortedKeys = _hiDict.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sortedKeys) {
      result = result.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        _hiDict[phrase]!,
      );
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Hybrid Translation Service: ML Kit + English Pivot + Offline Fallback
// ---------------------------------------------------------------------------
class TranslationService {
  static final Map<String, OnDeviceTranslator> _translators = {};
  static final Set<String> _downloadAttempted = {};

  // All ML Kit supported Indic languages (malayalam and punjabi NOT supported)
  static const List<String> _allSupportedLangs = [
    'en', 'hi', 'ta', 'te', 'kn', 'mr', 'bn', 'gu',
  ];

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

  /// Downloads ALL Indic + English models at app startup (requires internet once).
  /// After this, ALL cross-language pairs work offline forever via the English pivot.
  static Future<void> prewarmAllModels() async {
    final modelManager = OnDeviceTranslatorModelManager();
    for (final langCode in _allSupportedLangs) {
      final mlLang = _toMlKitLang(langCode);
      if (mlLang == null) continue;
      final bcpCode = mlLang.bcpCode;
      if (_downloadAttempted.contains(bcpCode)) continue;
      try {
        final isReady = await modelManager.isModelDownloaded(bcpCode);
        if (!isReady) {
          _downloadAttempted.add(bcpCode);
          await modelManager.downloadModel(bcpCode, isWifiRequired: false);
          debugPrint('[Translation] Downloaded model: $langCode ($bcpCode)');
        } else {
          debugPrint('[Translation] Model already ready: $langCode');
        }
      } catch (e) {
        debugPrint('[Translation] Cannot download $langCode (offline?): $e');
      }
    }
  }

  /// Downloads just the two models needed for a single pair (faster targeted warm-up).
  static Future<void> prewarmModels(String targetLang) async {
    final modelManager = OnDeviceTranslatorModelManager();
    for (final code in ['en', targetLang]) {
      final mlLang = _toMlKitLang(code);
      if (mlLang == null) continue;
      final bcpCode = mlLang.bcpCode;
      if (_downloadAttempted.contains(bcpCode)) continue;
      try {
        if (!await modelManager.isModelDownloaded(bcpCode)) {
          _downloadAttempted.add(bcpCode);
          await modelManager.downloadModel(bcpCode, isWifiRequired: false);
        }
      } catch (_) {}
    }
  }

  // Internal: translate directly between two languages using ML Kit.
  static Future<String> _mlKitTranslate(
    String text, String fromLang, String toLang) async {
    final src = _toMlKitLang(fromLang);
    final tgt = _toMlKitLang(toLang);
    if (src == null || tgt == null) throw Exception('Unsupported lang pair');

    final key = '${fromLang}_$toLang';
    _translators[key] ??= OnDeviceTranslator(
        sourceLanguage: src, targetLanguage: tgt);

    final modelManager = OnDeviceTranslatorModelManager();
    final srcCode = src.bcpCode;
    final tgtCode = tgt.bcpCode;

    var srcReady = await modelManager.isModelDownloaded(srcCode);
    var tgtReady = await modelManager.isModelDownloaded(tgtCode);

    // Try downloading on the fly if not present
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

    if (!srcReady || !tgtReady) throw Exception('Models not ready');

    final result = await _translators[key]!.translateText(text);
    if (result.isEmpty) throw Exception('Empty translation result');
    return result;
  }

  /// Translates text from [fromLang] to [toLang].
  /// 
  /// Strategy:
  /// - Direct pair (e.g., en->hi): one ML Kit call.
  /// - Cross-Indic pair (e.g., ta->hi): English PIVOT — ta->en first, then en->hi.
  ///   This is needed because ML Kit only ships direct en<->X models, not X<->Y.
  /// - Falls back to offline dictionary (en->hi only) if ML Kit unavailable.
  static Future<String> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    if (text.isEmpty || fromLang == toLang) return text;

    try {
      if (fromLang != 'en' && toLang != 'en') {
        // PIVOT: fromLang -> English -> toLang
        final enIntermediate = await _mlKitTranslate(text, fromLang, 'en');
        debugPrint('[Translation] Pivot $fromLang->en: "$text" -> "$enIntermediate"');
        final finalResult = await _mlKitTranslate(enIntermediate, 'en', toLang);
        debugPrint('[Translation] Pivot en->$toLang: "$enIntermediate" -> "$finalResult"');
        return finalResult;
      } else {
        // Direct translation
        final result = await _mlKitTranslate(text, fromLang, toLang);
        debugPrint('[Translation] Direct $fromLang->$toLang: "$text" -> "$result"');
        return result;
      }
    } catch (e) {
      debugPrint('[Translation] MLKit failed ($fromLang->$toLang): $e');
    }

    // Last resort: offline Hindi dictionary (works for simple en->hi words even offline)
    if (toLang == 'hi') {
      final fallback = OfflineIndicTranslator.translate(text, 'hi');
      debugPrint('[Translation] Offline en->hi fallback: "$text" -> "$fallback"');
      return fallback;
    }

    // Return original text if nothing works
    debugPrint('[Translation] No translation available for $fromLang->$toLang, returning original');
    return text;
  }

  static void dispose() {
    for (final t in _translators.values) { t.close(); }
    _translators.clear();
  }
}

// ---------------------------------------------------------------------------
// 4-bit language ID encoder for compact packet header
// ---------------------------------------------------------------------------
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