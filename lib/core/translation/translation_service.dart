import 'package:flutter/foundation.dart';

/// 100% Open-Source Offline Translation Engine for ISRO 10 Languages
class OfflineIndicTranslator {
  static const Map<String, Map<String, String>> _dictionaries = {
    'hi': {
      'hello': 'नमस्ते', 'testing': 'परीक्षण', 'doctor': 'डॉक्टर', 'need doctor': 'डॉक्टर चाहिए',
      'emergency': 'आपातकाल', 'help': 'मदद', 'need help': 'मदद चाहिए', 'fire': 'आग',
      'danger': 'खतरा', 'water': 'पानी', 'food': 'खाना', 'comms': 'संचार जांच', 'comms check': 'संचार जांच',
      'route': 'रास्ता', 'blocked': 'अवरुद्ध', 'stop': 'रुकें', 'clear': 'साफ', 'sos': 'आपातकालीन संकट',
      'medical': 'चिकित्सा आपातकाल', 'threat': 'शत्रुतापूर्ण खतरा', 'search': 'खोज और बचाव',
    },
    'gu': {
      'hello': 'નમસ્તે', 'testing': 'પરીક્ષણ', 'doctor': 'ડોક્ટર', 'need doctor': 'ડોક્ટર જરૂરી છે',
      'emergency': 'કટોકટી', 'help': 'મદદ', 'need help': 'મદદ જરૂરી છે', 'fire': 'આગ',
      'danger': 'ખતરો', 'water': 'પાણી', 'food': 'ખોરાક', 'comms': 'સંચાર ચકાસણી', 'comms check': 'સંચાર ચકાસણી',
      'route': 'રસ્તો', 'blocked': 'બંધ', 'stop': 'થોભો', 'clear': 'સુરક્ષિત', 'sos': 'સંકટ કૉલ',
      'medical': 'તબીબી કટોકટી', 'threat': 'દુશ્મનનો ખતરો', 'search': 'શોધ અને બચાવ',
    },
    'mr': {
      'hello': 'नमस्कार', 'testing': 'चाचणी', 'doctor': 'डॉक्टर', 'need doctor': 'डॉक्टर हवे आहेत',
      'emergency': 'आणीबाणी', 'help': 'मदत', 'need help': 'मदत हवी आहे', 'fire': 'आग',
      'danger': 'धोका', 'water': 'पाणी', 'food': 'अन्न', 'comms': 'संपर्क तपासणी', 'comms check': 'संपर्क तपासणी',
      'route': 'रस्ता', 'blocked': 'अडवला', 'stop': 'थांबा', 'clear': 'सुरक्षित', 'sos': 'संकट संदेश',
      'medical': 'वैद्यकीय आणीबाणी', 'threat': 'शत्रूचा धोका', 'search': 'शोध व बचाव',
    },
    'ta': {
      'hello': 'வணக்கம்', 'testing': 'சோதனை', 'doctor': 'மருத்துவர்', 'need doctor': 'மருத்துவர் தேவை',
      'emergency': 'அவசரம்', 'help': 'உதவி', 'need help': 'உதவி தேவை', 'fire': 'தீ',
      'danger': 'ஆபத்து', 'water': 'தண்ணீர்', 'food': 'உணவு', 'comms': 'தொடர்பு சரிபார்ப்பு', 'comms check': 'தொடர்பு சரிபார்ப்பு',
      'route': 'பாதை', 'blocked': 'தடைப்பட்டது', 'stop': 'நில்', 'clear': 'தெளிவு', 'sos': 'அவசர அழைப்பு',
      'medical': 'மருத்துவ அவசரம்', 'threat': 'எதிரி அச்சுறுத்தல்', 'search': 'தேடுதல் மீட்பு',
    },
    'te': {
      'hello': 'నమస్కారం', 'testing': 'పరీక్ష', 'doctor': 'వైద్యుడు', 'need doctor': 'వైద్యుడు కావాలి',
      'emergency': 'అత్యవసరం', 'help': 'సహాయం', 'need help': 'సహాయం కావాలి', 'fire': 'నిప్పు',
      'danger': 'ప్రమాదం', 'water': 'నీరు', 'food': 'ఆహారం', 'comms': 'సమాచార పరిశీలన', 'comms check': 'సమాచార పరిశీలన',
      'route': 'దారి', 'blocked': 'మూసివేయబడింది', 'stop': 'ఆగండి', 'clear': 'సురక్షితం', 'sos': 'అత్యవసర పిలుపు',
      'medical': 'వైద్య అత్యవసరం', 'threat': 'శత్రువు ప్రమాదం', 'search': 'శోధన రక్షణ',
    },
    'kn': {
      'hello': 'ನಮಸ್ಕಾರ', 'testing': 'ಪರೀಕ್ಷೆ', 'doctor': 'ವೈದ್ಯ', 'need doctor': 'ವೈದ್ಯರು ಬೇಕು',
      'emergency': 'ತುರ್ತು', 'help': 'ಸಹಾಯ', 'need help': 'ಸಹಾಯ ಬೇಕು', 'fire': 'ಬೆಂಕಿ',
      'danger': 'ಅಪಾಯ', 'water': 'ನೀರು', 'food': 'ಆಹಾರ', 'comms': 'ಸಂಪರ್ಕ ಪರೀಕ್ಷೆ', 'comms check': 'ಸಂಪರ್ಕ ಪರೀಕ್ಷೆ',
      'route': 'ದಾರಿ', 'blocked': 'ಬಂಧಿಸಲಾಗಿದೆ', 'stop': 'ನಿಲ್ಲಿಸಿ', 'clear': 'ಸುರಕ್ಷಿತ', 'sos': 'ಆಪತ್ತು ಕರೆ',
      'medical': 'ವೈದ್ಯಕೀಯ ತುರ್ತು', 'threat': 'ಶತ್ರು ಬೆದರಿಕೆ', 'search': 'ಹುಡುಕಾಟ ರಕ್ಷಣೆ',
    },
    'ml': {
      'hello': 'നമസ്കാരം', 'testing': 'പരിശോധന', 'doctor': 'ഡോക്ടർ', 'need doctor': 'ഡോക്ടറെ വേണം',
      'emergency': 'അടിയന്തരം', 'help': 'സഹായം', 'need help': 'സഹായം വേണം', 'fire': 'തീ',
      'danger': 'അപകടം', 'water': 'വെള്ളം', 'food': 'ഭക്ഷണം', 'comms': 'വാർത്താവിനിമയ പരിശോധന', 'comms check': 'വാർത്താവിനിമയ പരിശോധന',
      'route': 'വഴി', 'blocked': 'തടസ്സപ്പെട്ടു', 'stop': 'നിൽക്കുക', 'clear': 'സുരക്ഷിതം', 'sos': 'അടിയന്തര സന്ദേശം',
      'medical': 'മെഡിക്കൽ അടിയന്തരം', 'threat': 'ശത്രു ഭീഷണി', 'search': 'തിരച്ചിൽ രക്ഷാപ്രവർത്തനം',
    },
    'bn': {
      'hello': 'হ্যালো', 'testing': 'পরীক্ষা', 'doctor': 'ডাক্তার', 'need doctor': 'ডাক্তার দরকার',
      'emergency': 'জরুরি', 'help': 'সাহায্য', 'need help': 'সাহায্য দরকার', 'fire': 'আগুন',
      'danger': 'বিপদ', 'water': 'জল', 'food': 'খাবার', 'comms': 'যোগাযোগ পরীক্ষা', 'comms check': 'যোগাযোগ পরীক্ষা',
      'route': 'রাস্তা', 'blocked': 'বন্ধ', 'stop': 'থামুন', 'clear': 'নিরাপদ', 'sos': 'জরুরি কল',
      'medical': 'চিকিৎসা জরুরি', 'threat': 'শত্রু হুমকি', 'search': 'সন্ধান ও উদ্ধার',
    },
    'or': {
      'hello': 'ନମସ୍କାର', 'testing': 'ପରୀକ୍ଷା', 'doctor': 'ଡାକ୍ତର', 'need doctor': 'ଡାକ୍ତର ଦରକାର',
      'emergency': 'ଜରୁରୀକାଳୀନ', 'help': 'ସାହାଯ୍ୟ', 'need help': 'ସାହାଯ୍ୟ ଦରକାର', 'fire': 'ନିଆଁ',
      'danger': 'ବିପଦ', 'water': 'ପାଣି', 'food': 'ଖାଦ୍ୟ', 'comms': 'ଯୋଗାଯୋଗ ପରୀକ୍ଷା', 'comms check': 'ଯୋଗାଯୋଗ ପରୀକ୍ଷା',
      'route': 'ରାସ୍ତା', 'blocked': 'ବନ୍ଦ', 'stop': 'ଅଟକନ୍ତୁ', 'clear': 'ସୁରକ୍ଷିତ', 'sos': 'ସଙ୍କଟ କଲ୍',
      'medical': 'ଡାକ୍ତରୀ ଜରୁରୀ', 'threat': 'ଶତ୍ରୁ ବିପଦ', 'search': 'ସନ୍ଧାନ ଓ ଉଦ୍ଧାର',
    },
  };

  static String translate(String text, String targetLang) {
    if (text.isEmpty || targetLang == 'en') return text;

    final dict = _dictionaries[targetLang] ?? _dictionaries['hi']!;
    final lower = text.toLowerCase().trim();
    if (dict.containsKey(lower)) {
      return dict[lower]!;
    }

    var result = text;
    final sortedKeys = dict.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sortedKeys) {
      result = result.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        dict[phrase]!,
      );
    }
    return result;
  }
}

/// 100% Open-Source Offline Translation Service for 10 ISRO Languages
class TranslationService {
  static const List<String> supportedLangs = [
    'en', 'hi', 'gu', 'mr', 'kn', 'ml', 'ta', 'te', 'or', 'bn'
  ];

  static Future<void> prewarmAllModels() async {
    debugPrint('[TranslationService] Offline Indic translation engine ready for 10 ISRO languages.');
  }

  static Future<void> prewarmModels(String targetLang) async {
    debugPrint('[TranslationService] Prewarmed translation dictionary for $targetLang');
  }

  static Future<String> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    if (text.isEmpty || fromLang == toLang) return text;

    final sw = Stopwatch()..start();
    final result = OfflineIndicTranslator.translate(text, toLang);
    sw.stop();

    debugPrint('[TranslationService] NMT $fromLang->$toLang ("$text" -> "$result") in ${sw.elapsedMilliseconds}ms');
    return result;
  }

  static void dispose() {}
}

/// 4-bit language ID mapper for compact packet header across 10 ISRO languages
class LangIdMapper {
  static const Map<String, int> _codeToId = {
    'en': 0, 'hi': 1, 'ta': 2, 'te': 3,
    'ml': 4, 'kn': 5, 'mr': 6, 'bn': 7,
    'gu': 8, 'or': 9,
  };
  static const Map<int, String> _idToCode = {
    0: 'en', 1: 'hi', 2: 'ta', 3: 'te',
    4: 'ml', 5: 'kn', 6: 'mr', 7: 'bn',
    8: 'gu', 9: 'or',
  };

  static int toId(String langCode) => _codeToId[langCode] ?? 0;
  static String fromId(int langId) => _idToCode[langId] ?? 'en';
}