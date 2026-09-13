import 'package:flutter/foundation.dart';

/// 100% Open-Source Offline Translation Engine for ISRO 10 Languages
class OfflineIndicTranslator {
  // ---------------------------------------------------------------------------
  // Common phrase overrides (checked before word-by-word)
  // ---------------------------------------------------------------------------
  static const Map<String, Map<String, String>> _phrases = {
    'hi': {
      'i need help': 'मुझे मदद चाहिए',
      'need help': 'मदद चाहिए',
      'need doctor': 'डॉक्टर चाहिए',
      'i am injured': 'मैं घायल हूं',
      'people are trapped': 'लोग फंसे हैं',
      'building collapsed': 'इमारत ढह गई',
      'send rescue team': 'बचाव दल भेजें',
      'fire outbreak': 'आग लग गई',
      'need water': 'पानी चाहिए',
      'need food': 'खाना चाहिए',
      'i am here': 'मैं यहाँ हूं',
      'come here': 'यहाँ आओ',
      'move out': 'बाहर निकलो',
      'all clear': 'सब सुरक्षित',
      'take cover': 'छुप जाओ',
      'stand by': 'तैयार रहो',
      'we are coming': 'हम आ रहे हैं',
      'route blocked': 'रास्ता बंद है',
      'road blocked': 'सड़क बंद है',
    },
    'ta': {
      'i need help': 'எனக்கு உதவி வேண்டும்',
      'need help': 'உதவி வேண்டும்',
      'need doctor': 'மருத்துவர் தேவை',
      'i am injured': 'நான் காயமடைந்தேன்',
      'people are trapped': 'மக்கள் சிக்கியுள்ளனர்',
      'building collapsed': 'கட்டிடம் இடிந்தது',
      'send rescue team': 'மீட்புக்குழு அனுப்பு',
      'fire outbreak': 'தீ வெடித்தது',
      'need water': 'தண்ணீர் வேண்டும்',
      'need food': 'உணவு வேண்டும்',
      'i am here': 'நான் இங்கே இருக்கிறேன்',
      'come here': 'இங்கே வா',
      'move out': 'வெளியே போ',
      'all clear': 'அனைத்தும் பாதுகாப்பானது',
      'take cover': 'மறைந்துகொள்',
      'stand by': 'தயாராக இரு',
      'we are coming': 'நாங்கள் வருகிறோம்',
      'route blocked': 'பாதை தடைப்பட்டது',
      'road blocked': 'சாலை தடைப்பட்டது',
    },
    'te': {
      'i need help': 'నాకు సహాయం కావాలి',
      'need help': 'సహాయం కావాలి',
      'need doctor': 'వైద్యుడు కావాలి',
      'i am injured': 'నేను గాయపడ్డాను',
      'people are trapped': 'ప్రజలు చిక్కుకున్నారు',
      'building collapsed': 'భవనం కుప్పకూలింది',
      'send rescue team': 'రక్షణ బృందాన్ని పంపండి',
      'fire outbreak': 'అగ్ని ప్రమాదం జరిగింది',
      'need water': 'నీరు కావాలి',
      'need food': 'ఆహారం కావాలి',
      'i am here': 'నేను ఇక్కడ ఉన్నాను',
      'come here': 'ఇక్కడికి రండి',
      'move out': 'బయటకు వెళ్ళండి',
      'all clear': 'అన్నీ సురక్షితం',
      'take cover': 'దాక్కోండి',
      'stand by': 'సిద్ధంగా ఉండండి',
      'we are coming': 'మేము వస్తున్నాం',
      'route blocked': 'దారి మూసివేయబడింది',
      'road blocked': 'రోడ్డు మూసివేయబడింది',
    },
    'kn': {
      'i need help': 'ನನಗೆ ಸಹಾಯ ಬೇಕು',
      'need help': 'ಸಹಾಯ ಬೇಕು',
      'need doctor': 'ವೈದ್ಯರು ಬೇಕು',
      'i am injured': 'ನಾನು ಗಾಯಗೊಂಡಿದ್ದೇನೆ',
      'people are trapped': 'ಜನರು ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡಿದ್ದಾರೆ',
      'building collapsed': 'ಕಟ್ಟಡ ಕುಸಿದಿದೆ',
      'send rescue team': 'ರಕ್ಷಣಾ ತಂಡ ಕಳುಹಿಸಿ',
      'fire outbreak': 'ಬೆಂಕಿ ಹೊತ್ತಿಕೊಂಡಿದೆ',
      'need water': 'ನೀರು ಬೇಕು',
      'need food': 'ಆಹಾರ ಬೇಕು',
      'i am here': 'ನಾನು ಇಲ್ಲಿ ಇದ್ದೇನೆ',
      'come here': 'ಇಲ್ಲಿ ಬನ್ನಿ',
      'move out': 'ಹೊರಗೆ ಹೋಗಿ',
      'all clear': 'ಎಲ್ಲವೂ ಸುರಕ್ಷಿತ',
      'take cover': 'ಆಶ್ರಯ ತೆಗೆದುಕೊಳ್ಳಿ',
      'stand by': 'ಸಿದ್ಧರಾಗಿರಿ',
      'we are coming': 'ನಾವು ಬರುತ್ತಿದ್ದೇವೆ',
      'route blocked': 'ದಾರಿ ಮುಚ್ಚಿದೆ',
      'road blocked': 'ರಸ್ತೆ ಮುಚ್ಚಿದೆ',
    },
    'ml': {
      'i need help': 'എനിക്ക് സഹായം വേണം',
      'need help': 'സഹായം വേണം',
      'need doctor': 'ഡോക്ടറെ വേണം',
      'i am injured': 'ഞാൻ പരിക്കേറ്റു',
      'people are trapped': 'ആളുകൾ കുടുങ്ങിയിരിക്കുന്നു',
      'building collapsed': 'കെട്ടിടം തകർന്നു',
      'send rescue team': 'രക്ഷാസംഘം അയയ്ക്കൂ',
      'fire outbreak': 'തീ പൊട്ടിപ്പുറപ്പെട്ടു',
      'need water': 'വെള്ളം വേണം',
      'need food': 'ഭക്ഷണം വേണം',
      'i am here': 'ഞാൻ ഇവിടെ ഉണ്ട്',
      'come here': 'ഇവിടെ വരൂ',
      'move out': 'പുറത്ത് പോകൂ',
      'all clear': 'എല്ലാം സുരക്ഷിതം',
      'take cover': 'മറഞ്ഞിരിക്കൂ',
      'stand by': 'സജ്ജരാകൂ',
      'we are coming': 'ഞങ്ങൾ വരുന്നു',
      'route blocked': 'വഴി തടഞ്ഞിരിക്കുന്നു',
      'road blocked': 'റോഡ് തടഞ്ഞിരിക്കുന്നു',
    },
    'mr': {
      'i need help': 'मला मदत हवी आहे',
      'need help': 'मदत हवी आहे',
      'need doctor': 'डॉक्टर हवे आहेत',
      'i am injured': 'मी जखमी आहे',
      'people are trapped': 'लोक अडकले आहेत',
      'building collapsed': 'इमारत कोसळली',
      'send rescue team': 'बचाव पथक पाठवा',
      'fire outbreak': 'आग लागली',
      'need water': 'पाणी हवे आहे',
      'need food': 'अन्न हवे आहे',
      'i am here': 'मी इथे आहे',
      'come here': 'इथे या',
      'move out': 'बाहेर जा',
      'all clear': 'सर्व सुरक्षित',
      'take cover': 'आश्रय घ्या',
      'stand by': 'तयार राहा',
      'we are coming': 'आम्ही येत आहोत',
      'route blocked': 'रस्ता अडवला आहे',
      'road blocked': 'रस्ता बंद आहे',
    },
    'gu': {
      'i need help': 'મને મદદ જોઈએ છે',
      'need help': 'મદદ જોઈએ છે',
      'need doctor': 'ડૉક્ટર જોઈએ છે',
      'i am injured': 'હું ઘવાયો છું',
      'people are trapped': 'લોકો ફસાઈ ગયા છે',
      'building collapsed': 'ઈમારત ધ્વસ્ત થઈ',
      'send rescue team': 'બચાવ ટીમ મોકલો',
      'fire outbreak': 'આગ લાગી',
      'need water': 'પાણી જોઈએ',
      'need food': 'ખોરાક જોઈએ',
      'i am here': 'હું અહીં છું',
      'come here': 'અહીં આવો',
      'move out': 'બહાર જાઓ',
      'all clear': 'બધું સુરક્ષિત',
      'take cover': 'આશ્રય લો',
      'stand by': 'તૈયાર રહો',
      'we are coming': 'અમે આવી રહ્યા છીએ',
      'route blocked': 'રસ્તો બંધ છે',
      'road blocked': 'સડક બંધ છે',
    },
    'bn': {
      'i need help': 'আমার সাহায্য দরকার',
      'need help': 'সাহায্য দরকার',
      'need doctor': 'ডাক্তার দরকার',
      'i am injured': 'আমি আহত',
      'people are trapped': 'মানুষ আটকে আছে',
      'building collapsed': 'ভবন ভেঙে পড়েছে',
      'send rescue team': 'উদ্ধারকারী দল পাঠান',
      'fire outbreak': 'আগুন লেগেছে',
      'need water': 'জল দরকার',
      'need food': 'খাবার দরকার',
      'i am here': 'আমি এখানে আছি',
      'come here': 'এখানে আসুন',
      'move out': 'বাইরে যান',
      'all clear': 'সব নিরাপদ',
      'take cover': 'আশ্রয় নিন',
      'stand by': 'প্রস্তুত থাকুন',
      'we are coming': 'আমরা আসছি',
      'route blocked': 'পথ বন্ধ',
      'road blocked': 'রাস্তা বন্ধ',
    },
    'or': {
      'i need help': 'ମୋର ସାହାଯ୍ୟ ଦରକାର',
      'need help': 'ସାହାଯ୍ୟ ଦରକାର',
      'need doctor': 'ଡାକ୍ତର ଦରକାର',
      'i am injured': 'ମୁଁ ଆହତ',
      'people are trapped': 'ଲୋକ ଫଙ୍ଗ ହୋଇଛନ୍ତି',
      'building collapsed': 'ବିଲ୍ଡିଂ ଭାଙ୍ଗି ଗଲା',
      'send rescue team': 'ଉଦ୍ଧାର ଦଳ ପଠାନ୍ତୁ',
      'fire outbreak': 'ନିଆଁ ଲାଗିଛି',
      'need water': 'ପାଣି ଦରକାର',
      'need food': 'ଖାଦ୍ୟ ଦରକାର',
      'i am here': 'ମୁଁ ଏଠାରେ ଅଛି',
      'come here': 'ଏଠାକୁ ଆସ',
      'move out': 'ବାହାରକୁ ଯାଅ',
      'all clear': 'ସବୁ ସୁରକ୍ଷିତ',
      'take cover': 'ଆଶ୍ରୟ ନିଅ',
      'stand by': 'ପ୍ରସ୍ତୁତ ରୁହ',
      'we are coming': 'ଆମେ ଆସୁଛୁ',
      'route blocked': 'ରାସ୍ତା ବନ୍ଦ',
      'road blocked': 'ସଡ଼କ ବନ୍ଦ',
    },
  };

  // ---------------------------------------------------------------------------
  // Word-level dictionaries (fallback for unknown phrases)
  // ---------------------------------------------------------------------------
  static const Map<String, Map<String, String>> _dictionaries = {
    'hi': {
      // Greetings
      'hello': 'नमस्ते', 'hi': 'नमस्ते', 'namaste': 'नमस्ते', 'testing': 'परीक्षण',
      // Pronouns
      'i': 'मैं', 'we': 'हम', 'you': 'आप', 'they': 'वे', 'he': 'वह', 'she': 'वह',
      'my': 'मेरा', 'our': 'हमारा', 'your': 'आपका', 'their': 'उनका',
      'this': 'यह', 'that': 'वह', 'here': 'यहाँ', 'there': 'वहाँ',
      // Verbs
      'am': 'हूं', 'is': 'है', 'are': 'हैं', 'was': 'था', 'were': 'थे',
      'need': 'चाहिए', 'want': 'चाहते हैं', 'have': 'है', 'has': 'है',
      'send': 'भेजें', 'come': 'आओ', 'go': 'जाओ', 'stop': 'रुकें',
      'call': 'बुलाओ', 'evacuate': 'निकालो', 'move': 'हटो',
      // Emergency words
      'help': 'मदद', 'emergency': 'आपातकाल', 'danger': 'खतरा', 'sos': 'आपातकालीन संकट',
      'fire': 'आग', 'water': 'पानी', 'food': 'खाना', 'doctor': 'डॉक्टर',
      'medical': 'चिकित्सा', 'police': 'पुलिस', 'rescue': 'बचाव',
      // Status words
      'injured': 'घायल', 'wounded': 'जखमी', 'sick': 'बीमार', 'dead': 'मृत',
      'trapped': 'फंसे', 'stuck': 'अटके', 'missing': 'लापता', 'lost': 'खोया',
      'safe': 'सुरक्षित', 'clear': 'साफ', 'blocked': 'अवरुद्ध', 'open': 'खुला',
      // Nouns
      'people': 'लोग', 'team': 'टीम', 'unit': 'दल', 'group': 'समूह',
      'building': 'इमारत', 'road': 'सड़क', 'route': 'रास्ता', 'bridge': 'पुल',
      'area': 'क्षेत्र', 'zone': 'इलाका', 'location': 'स्थान', 'position': 'जगह',
      'name': 'नाम', 'number': 'संख्या',
      // Direction/action
      'urgent': 'तत्काल', 'immediately': 'तुरंत', 'quickly': 'जल्दी', 'now': 'अभी',
      'please': 'कृपया', 'alert': 'सतर्क', 'warning': 'चेतावनी',
      // Comms
      'comms': 'संचार जांच', 'comms check': 'संचार जांच', 'threat': 'शत्रुतापूर्ण खतरा', 'search': 'खोज और बचाव',
    },
    'ta': {
      'hello': 'வணக்கம்', 'hi': 'வணக்கம்', 'testing': 'சோதனை',
      'i': 'நான்', 'we': 'நாங்கள்', 'you': 'நீங்கள்', 'they': 'அவர்கள்', 'he': 'அவன்', 'she': 'அவள்',
      'my': 'என்', 'our': 'எங்கள்', 'your': 'உங்கள்', 'their': 'அவர்கள்',
      'this': 'இது', 'that': 'அது', 'here': 'இங்கே', 'there': 'அங்கே',
      'am': 'இருக்கிறேன்', 'is': 'இருக்கிறது', 'are': 'இருக்கிறார்கள்', 'was': 'இருந்தது', 'were': 'இருந்தனர்',
      'need': 'வேண்டும்', 'want': 'வேண்டும்', 'have': 'இருக்கிறது', 'has': 'இருக்கிறது',
      'send': 'அனுப்பு', 'come': 'வா', 'go': 'போ', 'stop': 'நில்',
      'call': 'அழை', 'evacuate': 'வெளியேறு', 'move': 'நகர்',
      'help': 'உதவி', 'emergency': 'அவசரம்', 'danger': 'ஆபத்து', 'sos': 'அவசர அழைப்பு',
      'fire': 'தீ', 'water': 'தண்ணீர்', 'food': 'உணவு', 'doctor': 'மருத்துவர்',
      'medical': 'மருத்துவ', 'police': 'காவல்துறை', 'rescue': 'மீட்பு',
      'injured': 'காயமடைந்த', 'wounded': 'காயப்பட்ட', 'sick': 'நோய்வாய்ப்பட்ட', 'dead': 'இறந்த',
      'trapped': 'சிக்கியுள்ள', 'stuck': 'மாட்டிக்கொண்ட', 'missing': 'காணாமல்போன', 'lost': 'தொலைந்த',
      'safe': 'பாதுகாப்பான', 'clear': 'தெளிவு', 'blocked': 'தடைப்பட்டது', 'open': 'திறந்த',
      'people': 'மக்கள்', 'team': 'குழு', 'unit': 'அலகு', 'group': 'கூட்டம்',
      'building': 'கட்டிடம்', 'road': 'சாலை', 'route': 'பாதை', 'bridge': 'பாலம்',
      'area': 'பகுதி', 'zone': 'மண்டலம்', 'location': 'இடம்', 'position': 'நிலை',
      'name': 'பெயர்', 'number': 'எண்',
      'urgent': 'அவசரமான', 'immediately': 'உடனடியாக', 'quickly': 'விரைவாக', 'now': 'இப்போது',
      'please': 'தயவுசெய்து', 'alert': 'எச்சரிக்கை', 'warning': 'எச்சரிக்கை',
      'comms': 'தொடர்பு சரிபார்ப்பு', 'comms check': 'தொடர்பு சரிபார்ப்பு', 'threat': 'எதிரி அச்சுறுத்தல்', 'search': 'தேடுதல் மீட்பு',
    },
    'te': {
      'hello': 'నమస్కారం', 'hi': 'నమస్కారం', 'testing': 'పరీక్ష',
      'i': 'నేను', 'we': 'మేము', 'you': 'మీరు', 'they': 'వారు', 'he': 'అతను', 'she': 'ఆమె',
      'my': 'నా', 'our': 'మా', 'your': 'మీ', 'their': 'వారి',
      'this': 'ఇది', 'that': 'అది', 'here': 'ఇక్కడ', 'there': 'అక్కడ',
      'am': 'ఉన్నాను', 'is': 'ఉంది', 'are': 'ఉన్నారు', 'was': 'ఉంది', 'were': 'ఉన్నారు',
      'need': 'కావాలి', 'want': 'కావాలి', 'have': 'ఉంది', 'has': 'ఉంది',
      'send': 'పంపండి', 'come': 'రండి', 'go': 'వెళ్ళండి', 'stop': 'ఆగండి',
      'call': 'పిలవండి', 'evacuate': 'తరలించండి', 'move': 'కదలండి',
      'help': 'సహాయం', 'emergency': 'అత్యవసరం', 'danger': 'ప్రమాదం', 'sos': 'అత్యవసర పిలుపు',
      'fire': 'నిప్పు', 'water': 'నీరు', 'food': 'ఆహారం', 'doctor': 'వైద్యుడు',
      'medical': 'వైద్య', 'police': 'పోలీసు', 'rescue': 'శోధన రక్షణ',
      'injured': 'గాయపడ్డ', 'wounded': 'గాయపడిన', 'sick': 'అనారోగ్యంగా', 'dead': 'మరణించిన',
      'trapped': 'చిక్కుకున్న', 'stuck': 'ఇరుక్కున్న', 'missing': 'తప్పిపోయిన', 'lost': 'పోయిన',
      'safe': 'సురక్షితం', 'clear': 'స్పష్టం', 'blocked': 'మూసివేయబడింది', 'open': 'తెరవబడింది',
      'people': 'ప్రజలు', 'team': 'బృందం', 'unit': 'యూనిట్', 'group': 'గుంపు',
      'building': 'భవనం', 'road': 'రోడ్డు', 'route': 'దారి', 'bridge': 'వంతెన',
      'area': 'ప్రాంతం', 'zone': 'జోన్', 'location': 'స్థానం', 'position': 'స్థానం',
      'name': 'పేరు', 'number': 'సంఖ్య',
      'urgent': 'అత్యవసరమైన', 'immediately': 'వెంటనే', 'quickly': 'త్వరగా', 'now': 'ఇప్పుడు',
      'please': 'దయచేసి', 'alert': 'హెచ్చరిక', 'warning': 'హెచ్చరిక',
      'comms': 'సమాచార పరిశీలన', 'comms check': 'సమాచార పరిశీలన', 'threat': 'శత్రువు ప్రమాదం', 'search': 'శోధన రక్షణ',
    },
    'kn': {
      'hello': 'ನಮಸ್ಕಾರ', 'hi': 'ನಮಸ್ಕಾರ', 'testing': 'ಪರೀಕ್ಷೆ',
      'i': 'ನಾನು', 'we': 'ನಾವು', 'you': 'ನೀವು', 'they': 'ಅವರು', 'he': 'ಅವನು', 'she': 'ಅವಳು',
      'my': 'ನನ್ನ', 'our': 'ನಮ್ಮ', 'your': 'ನಿಮ್ಮ', 'their': 'ಅವರ',
      'this': 'ಇದು', 'that': 'ಅದು', 'here': 'ಇಲ್ಲಿ', 'there': 'ಅಲ್ಲಿ',
      'am': 'ಇದ್ದೇನೆ', 'is': 'ಇದೆ', 'are': 'ಇದ್ದಾರೆ', 'was': 'ಇತ್ತು', 'were': 'ಇದ್ದರು',
      'need': 'ಬೇಕು', 'want': 'ಬೇಕು', 'have': 'ಇದೆ', 'has': 'ಇದೆ',
      'send': 'ಕಳುಹಿಸಿ', 'come': 'ಬನ್ನಿ', 'go': 'ಹೋಗಿ', 'stop': 'ನಿಲ್ಲಿಸಿ',
      'call': 'ಕರೆ', 'evacuate': 'ಸ್ಥಳಾಂತರ', 'move': 'ಚಲಿಸಿ',
      'help': 'ಸಹಾಯ', 'emergency': 'ತುರ್ತು', 'danger': 'ಅಪಾಯ', 'sos': 'ಆಪತ್ತು ಕರೆ',
      'fire': 'ಬೆಂಕಿ', 'water': 'ನೀರು', 'food': 'ಆಹಾರ', 'doctor': 'ವೈದ್ಯ',
      'medical': 'ವೈದ್ಯಕೀಯ', 'police': 'ಪೊಲೀಸ್', 'rescue': 'ಹುಡುಕಾಟ ರಕ್ಷಣೆ',
      'injured': 'ಗಾಯಗೊಂಡ', 'wounded': 'ಗಾಯಾಳು', 'sick': 'ಅನಾರೋಗ್ಯ', 'dead': 'ಮೃತ',
      'trapped': 'ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡ', 'stuck': 'ಸಿಲುಕಿದ', 'missing': 'ಕಾಣೆಯಾದ', 'lost': 'ತಪ್ಪಿದ',
      'safe': 'ಸುರಕ್ಷಿತ', 'clear': 'ಸ್ಪಷ್ಟ', 'blocked': 'ಬಂಧಿಸಲಾಗಿದೆ', 'open': 'ತೆರೆದ',
      'people': 'ಜನರು', 'team': 'ತಂಡ', 'unit': 'ಘಟಕ', 'group': 'ಗುಂಪು',
      'building': 'ಕಟ್ಟಡ', 'road': 'ರಸ್ತೆ', 'route': 'ದಾರಿ', 'bridge': 'ಸೇತುವೆ',
      'area': 'ಪ್ರದೇಶ', 'zone': 'ವಲಯ', 'location': 'ಸ್ಥಳ', 'position': 'ಸ್ಥಾನ',
      'name': 'ಹೆಸರು', 'number': 'ಸಂಖ್ಯೆ',
      'urgent': 'ತುರ್ತು', 'immediately': 'ತಕ್ಷಣ', 'quickly': 'ಬೇಗ', 'now': 'ಈಗ',
      'please': 'ದಯವಿಟ್ಟು', 'alert': 'ಎಚ್ಚರಿಕೆ', 'warning': 'ಎಚ್ಚರಿಕೆ',
      'comms': 'ಸಂಪರ್ಕ ಪರೀಕ್ಷೆ', 'comms check': 'ಸಂಪರ್ಕ ಪರೀಕ್ಷೆ', 'threat': 'ಶತ್ರು ಬೆದರಿಕೆ', 'search': 'ಹುಡುಕಾಟ ರಕ್ಷಣೆ',
    },
    'ml': {
      'hello': 'നമസ്കാരം', 'hi': 'ഹലോ', 'testing': 'പരിശോധന',
      'i': 'ഞാൻ', 'we': 'ഞങ്ങൾ', 'you': 'നിങ്ങൾ', 'they': 'അവർ', 'he': 'അവൻ', 'she': 'അവൾ',
      'my': 'എന്റെ', 'our': 'ഞങ്ങളുടെ', 'your': 'നിങ്ങളുടെ', 'their': 'അവരുടെ',
      'this': 'ഇത്', 'that': 'അത്', 'here': 'ഇവിടെ', 'there': 'അവിടെ',
      'am': 'ആണ്', 'is': 'ആണ്', 'are': 'ആണ്', 'was': 'ആയിരുന്നു', 'were': 'ആയിരുന്നു',
      'need': 'വേണം', 'want': 'ആഗ്രഹം', 'have': 'ഉണ്ട്', 'has': 'ഉണ്ട്',
      'send': 'അയക്കൂ', 'come': 'വരൂ', 'go': 'പോകൂ', 'stop': 'നിൽക്കുക',
      'call': 'വിളിക്കൂ', 'evacuate': 'ഒഴിപ്പിക്കൂ', 'move': 'നീങ്ങൂ',
      'help': 'സഹായം', 'emergency': 'അടിയന്തരം', 'danger': 'അപകടം', 'sos': 'അടിയന്തര സന്ദേശം',
      'fire': 'തീ', 'water': 'വെള്ളം', 'food': 'ഭക്ഷണം', 'doctor': 'ഡോക്ടർ',
      'medical': 'മെഡിക്കൽ', 'police': 'പോലീസ്', 'rescue': 'തിരച്ചിൽ രക്ഷാപ്രവർത്തനം',
      'injured': 'പരിക്കേറ്റ', 'wounded': 'മുറിവേറ്റ', 'sick': 'രോഗം', 'dead': 'മരിച്ച',
      'trapped': 'കുടുങ്ങിയ', 'stuck': 'ഉടക്കിയ', 'missing': 'കാണാതായ', 'lost': 'നഷ്ടപ്പെട്ട',
      'safe': 'സുരക്ഷിതം', 'clear': 'വ്യക്തം', 'blocked': 'തടഞ്ഞ', 'open': 'തുറന്ന',
      'people': 'ആളുകൾ', 'team': 'ടീം', 'unit': 'യൂണിറ്റ്', 'group': 'ഗ്രൂപ്പ്',
      'building': 'കെട്ടിടം', 'road': 'റോഡ്', 'route': 'വഴി', 'bridge': 'പാലം',
      'area': 'പ്രദേശം', 'zone': 'സോൺ', 'location': 'സ്ഥലം', 'position': 'സ്ഥാനം',
      'name': 'പേര്', 'number': 'നമ്പർ',
      'urgent': 'അടിയന്തിര', 'immediately': 'ഉടൻ', 'quickly': 'വേഗം', 'now': 'ഇപ്പോൾ',
      'please': 'ദയവായി', 'alert': 'ജാഗ്രത', 'warning': 'മുന്നറിയിപ്പ്',
      'comms': 'വാർത്താവിനിമയ പരിശോധന', 'comms check': 'വാർത്താവിനിമയ പരിശോധന', 'threat': 'ശത്രു ഭീഷണി', 'search': 'തിരച്ചിൽ രക്ഷാപ്രവർത്തനം',
    },
    'mr': {
      'hello': 'नमस्कार', 'hi': 'नमस्कार', 'testing': 'चाचणी',
      'i': 'मी', 'we': 'आम्ही', 'you': 'तुम्ही', 'they': 'ते', 'he': 'तो', 'she': 'ती',
      'my': 'माझे', 'our': 'आमचे', 'your': 'तुमचे', 'their': 'त्यांचे',
      'this': 'हे', 'that': 'ते', 'here': 'इथे', 'there': 'तिथे',
      'am': 'आहे', 'is': 'आहे', 'are': 'आहेत', 'was': 'होते', 'were': 'होते',
      'need': 'हवे', 'want': 'हवे', 'have': 'आहे', 'has': 'आहे',
      'send': 'पाठवा', 'come': 'या', 'go': 'जा', 'stop': 'थांबा',
      'call': 'बोलवा', 'evacuate': 'बाहेर काढा', 'move': 'हला',
      'help': 'मदत', 'emergency': 'आणीबाणी', 'danger': 'धोका', 'sos': 'संकट संदेश',
      'fire': 'आग', 'water': 'पाणी', 'food': 'अन्न', 'doctor': 'डॉक्टर',
      'medical': 'वैद्यकीय', 'police': 'पोलीस', 'rescue': 'शोध व बचाव',
      'injured': 'जखमी', 'wounded': 'जखमी', 'sick': 'आजारी', 'dead': 'मृत',
      'trapped': 'अडकलेले', 'stuck': 'फसलेले', 'missing': 'बेपत्ता', 'lost': 'हरवलेले',
      'safe': 'सुरक्षित', 'clear': 'स्पष्ट', 'blocked': 'अडवला', 'open': 'उघडे',
      'people': 'लोक', 'team': 'पथक', 'unit': 'तुकडी', 'group': 'गट',
      'building': 'इमारत', 'road': 'रस्ता', 'route': 'मार्ग', 'bridge': 'पूल',
      'area': 'भाग', 'zone': 'विभाग', 'location': 'ठिकाण', 'position': 'स्थान',
      'name': 'नाव', 'number': 'क्रमांक',
      'urgent': 'तातडीचे', 'immediately': 'लगेच', 'quickly': 'लवकर', 'now': 'आत्ता',
      'please': 'कृपया', 'alert': 'सतर्क', 'warning': 'इशारा',
      'comms': 'संपर्क तपासणी', 'comms check': 'संपर्क तपासणी', 'threat': 'शत्रूचा धोका', 'search': 'शोध व बचाव',
    },
    'gu': {
      'hello': 'નમસ્તે', 'hi': 'નમસ્તે', 'testing': 'પરીક્ષણ',
      'i': 'હું', 'we': 'અમે', 'you': 'તમે', 'they': 'તેઓ', 'he': 'તે', 'she': 'તે',
      'my': 'મારો', 'our': 'અમારો', 'your': 'તમારો', 'their': 'તેઓનો',
      'this': 'આ', 'that': 'તે', 'here': 'અહીં', 'there': 'ત્યાં',
      'am': 'છું', 'is': 'છે', 'are': 'છે', 'was': 'હતો', 'were': 'હતા',
      'need': 'જોઈએ', 'want': 'જોઈએ', 'have': 'છે', 'has': 'છે',
      'send': 'મોકલો', 'come': 'આવો', 'go': 'જાઓ', 'stop': 'થોભો',
      'call': 'બોલાવો', 'evacuate': 'ખાલી કરો', 'move': 'ખસો',
      'help': 'મદદ', 'emergency': 'કટોકટી', 'danger': 'ખતરો', 'sos': 'સંકટ કૉલ',
      'fire': 'આગ', 'water': 'પાણી', 'food': 'ખોરાક', 'doctor': 'ડૉક્ટર',
      'medical': 'તબીબી', 'police': 'પોલીસ', 'rescue': 'શોધ અને બચાવ',
      'injured': 'ઘવાયેલ', 'wounded': 'ઘાયલ', 'sick': 'બીમાર', 'dead': 'મૃત',
      'trapped': 'ફસાઈ ગયેલ', 'stuck': 'અટવાઈ ગયેલ', 'missing': 'ગૂમ', 'lost': 'ખોવાઈ ગયેલ',
      'safe': 'સુરક્ષિત', 'clear': 'સ્પષ્ટ', 'blocked': 'બંધ', 'open': 'ખુલ્લું',
      'people': 'લોકો', 'team': 'ટીમ', 'unit': 'એકમ', 'group': 'જૂથ',
      'building': 'ઈમારત', 'road': 'સડક', 'route': 'રસ્તો', 'bridge': 'પૂલ',
      'area': 'વિસ્તાર', 'zone': 'ઝોન', 'location': 'સ્થળ', 'position': 'સ્થાન',
      'name': 'નામ', 'number': 'નંબર',
      'urgent': 'તાત્કાલિક', 'immediately': 'તુરંત', 'quickly': 'ઝડપથી', 'now': 'અત્યારે',
      'please': 'કૃપા કરીને', 'alert': 'ચેતવણી', 'warning': 'ચેતવણી',
      'comms': 'સંચાર ચકાસણી', 'comms check': 'સંચાર ચકાસણી', 'threat': 'દુશ્મનનો ખતરો', 'search': 'શોધ અને બચાવ',
    },
    'bn': {
      'hello': 'হ্যালো', 'hi': 'হ্যালো', 'testing': 'পরীক্ষা',
      'i': 'আমি', 'we': 'আমরা', 'you': 'আপনি', 'they': 'তারা', 'he': 'সে', 'she': 'সে',
      'my': 'আমার', 'our': 'আমাদের', 'your': 'আপনার', 'their': 'তাদের',
      'this': 'এটি', 'that': 'ওটি', 'here': 'এখানে', 'there': 'সেখানে',
      'am': 'আছি', 'is': 'আছে', 'are': 'আছেন', 'was': 'ছিল', 'were': 'ছিলেন',
      'need': 'দরকার', 'want': 'চাই', 'have': 'আছে', 'has': 'আছে',
      'send': 'পাঠান', 'come': 'আসুন', 'go': 'যান', 'stop': 'থামুন',
      'call': 'ডাকুন', 'evacuate': 'সরিয়ে নিন', 'move': 'সরুন',
      'help': 'সাহায্য', 'emergency': 'জরুরি', 'danger': 'বিপদ', 'sos': 'জরুরি কল',
      'fire': 'আগুন', 'water': 'জল', 'food': 'খাবার', 'doctor': 'ডাক্তার',
      'medical': 'চিকিৎসা', 'police': 'পুলিশ', 'rescue': 'সন্ধান ও উদ্ধার',
      'injured': 'আহত', 'wounded': 'আঘাতপ্রাপ্ত', 'sick': 'অসুস্থ', 'dead': 'মৃত',
      'trapped': 'আটকা', 'stuck': 'আটকে', 'missing': 'নিখোঁজ', 'lost': 'হারিয়ে',
      'safe': 'নিরাপদ', 'clear': 'পরিষ্কার', 'blocked': 'বন্ধ', 'open': 'খোলা',
      'people': 'মানুষ', 'team': 'দল', 'unit': 'ইউনিট', 'group': 'গোষ্ঠী',
      'building': 'ভবন', 'road': 'রাস্তা', 'route': 'পথ', 'bridge': 'সেতু',
      'area': 'এলাকা', 'zone': 'অঞ্চল', 'location': 'অবস্থান', 'position': 'স্থান',
      'name': 'নাম', 'number': 'নম্বর',
      'urgent': 'জরুরি', 'immediately': 'অবিলম্বে', 'quickly': 'দ্রুত', 'now': 'এখনই',
      'please': 'দয়া করে', 'alert': 'সতর্কতা', 'warning': 'সতর্কীকরণ',
      'comms': 'যোগাযোগ পরীক্ষা', 'comms check': 'যোগাযোগ পরীক্ষা', 'threat': 'শত্রু হুমকি', 'search': 'সন্ধান ও উদ্ধার',
    },
    'or': {
      'hello': 'ନମସ୍କାର', 'hi': 'ହ୍ୟାଲୋ', 'testing': 'ପରୀକ୍ଷା',
      'i': 'ମୁଁ', 'we': 'ଆମେ', 'you': 'ଆପଣ', 'they': 'ସେମାନେ', 'he': 'ସେ', 'she': 'ସେ',
      'my': 'ମୋର', 'our': 'ଆମର', 'your': 'ଆପଣଙ୍କ', 'their': 'ସେମାନଙ୍କ',
      'this': 'ଏହା', 'that': 'ତାହା', 'here': 'ଏଠାରେ', 'there': 'ସେଠାରେ',
      'am': 'ଅଛି', 'is': 'ଅଛି', 'are': 'ଅଛନ୍ତି', 'was': 'ଥିଲା', 'were': 'ଥିଲେ',
      'need': 'ଦରକାର', 'want': 'ଚାହୁଁ', 'have': 'ଅଛି', 'has': 'ଅଛି',
      'send': 'ପଠାନ୍ତୁ', 'come': 'ଆସନ୍ତୁ', 'go': 'ଯାଆନ୍ତୁ', 'stop': 'ଅଟକନ୍ତୁ',
      'call': 'ଡାକନ୍ତୁ', 'evacuate': 'ସ୍ଥାନ ଛାଡ଼ନ୍ତୁ', 'move': 'ଚଲନ୍ତୁ',
      'help': 'ସାହାଯ୍ୟ', 'emergency': 'ଜରୁରୀକାଳୀନ', 'danger': 'ବିପଦ', 'sos': 'ସଙ୍କଟ କଲ୍',
      'fire': 'ନିଆଁ', 'water': 'ପାଣି', 'food': 'ଖାଦ୍ୟ', 'doctor': 'ଡାକ୍ତର',
      'medical': 'ଡାକ୍ତରୀ', 'police': 'ପୋଲିସ', 'rescue': 'ସନ୍ଧାନ ଓ ଉଦ୍ଧାର',
      'injured': 'ଆହତ', 'wounded': 'ଆଘାତ ପ୍ରାପ୍ତ', 'sick': 'ଅସୁସ୍ଥ', 'dead': 'ମୃତ',
      'trapped': 'ଫଙ୍ଗ', 'stuck': 'ଆଟକି', 'missing': 'ନିଖୋଜ', 'lost': 'ହଜିଯାଇ',
      'safe': 'ସୁରକ୍ଷିତ', 'clear': 'ସ୍ପଷ୍ଟ', 'blocked': 'ବନ୍ଦ', 'open': 'ଖୋଲା',
      'people': 'ଲୋକ', 'team': 'ଦଳ', 'unit': 'ୟୁନିଟ', 'group': 'ଗୋଷ୍ଠୀ',
      'building': 'ଭବନ', 'road': 'ସଡ଼କ', 'route': 'ରାସ୍ତା', 'bridge': 'ପୋଲ',
      'area': 'ଅଞ୍ଚଳ', 'zone': 'ଜୋନ', 'location': 'ସ୍ଥାନ', 'position': 'ଅବସ୍ଥାନ',
      'name': 'ନାମ', 'number': 'ସଂଖ୍ୟା',
      'urgent': 'ଜରୁରୀ', 'immediately': 'ଶୀଘ୍ର', 'quickly': 'ଦ୍ରୁତ', 'now': 'ଏବେ',
      'please': 'ଦୟାକରି', 'alert': 'ସଜାଗ', 'warning': 'ସତର୍କ',
      'comms': 'ଯୋଗାଯୋଗ ପରୀକ୍ଷା', 'comms check': 'ଯୋଗାଯୋଗ ପରୀକ୍ଷା', 'threat': 'ଶତ୍ରୁ ବିପଦ', 'search': 'ସନ୍ଧାନ ଓ ଉଦ୍ଧାର',
    },
  };

  static String translate(String text, String targetLang) {
    if (text.isEmpty || targetLang == 'en') return text;

    final lower = text.toLowerCase().trim();
    final phraseDict = _phrases[targetLang] ?? {};
    final wordDict = _dictionaries[targetLang] ?? _dictionaries['hi']!;

    // 1. Direct exact phrase match (full sentence)
    if (phraseDict.containsKey(lower)) return phraseDict[lower]!;
    if (wordDict.containsKey(lower)) return wordDict[lower]!;

    // 2. Try longest phrase match within the text
    String result = lower;
    final sortedPhrases = phraseDict.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // longest first
    for (final phrase in sortedPhrases) {
      if (result.contains(phrase)) {
        result = result.replaceAll(phrase, phraseDict[phrase]!);
      }
    }

    // 3. Word-by-word translation on remaining text
    final words = result.split(RegExp(r'\s+'));
    final translated = words.map((w) {
      final clean = w.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (wordDict.containsKey(clean)) return wordDict[clean]!;
      return w; // keep original (proper nouns, unknown words)
    }).join(' ');

    return translated;
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
