import 'package:flutter/material.dart';
import '../core/hardware/hardware_override.dart';

/// Language Pack Setup Screen - shown on first launch.
/// Checks & installs TTS voice packs for all 10 ISRO languages.
class LanguageSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const LanguageSetupScreen({super.key, required this.onComplete});

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  static const _langNames = {
    'hi': 'हिन्दी (Hindi)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'ml': 'മലയാളം (Malayalam)',
    'mr': 'मराठी (Marathi)',
    'bn': 'বাংলা (Bengali)',
    'gu': 'ગુજરાતી (Gujarati)',
    'or': 'ଓଡ଼ିଆ (Odia)',
    'en': 'English',
  };

  Map<String, String> _packStatus = {};
  bool _checking = true;
  bool _allInstalled = false;

  @override
  void initState() {
    super.initState();
    _checkPacks();
  }

  Future<void> _checkPacks() async {
    setState(() => _checking = true);
    final status = await HardwareOverride.checkLanguagePacks();
    final allOk = status.values.every((s) => s == 'AVAILABLE');
    setState(() {
      _packStatus = status;
      _checking = false;
      _allInstalled = allOk;
    });
  }

  Future<void> _installPacks() async {
    await HardwareOverride.installLanguagePacks();
    // After user installs in system settings and comes back, re-check
    await Future.delayed(const Duration(seconds: 3));
    await _checkPacks();
  }

  @override
  Widget build(BuildContext context) {
    const peachBg = Color(0xFFF6ECE3);
    const darkBrown = Color(0xFF5A3E36);
    const softRed = Color(0xFFC84B4B);
    const shadowLight = Colors.white;
    const shadowDark = Color(0xFFE2D2C5);

    final missingLangs = _packStatus.entries
        .where((e) => e.value != 'AVAILABLE')
        .map((e) => e.key)
        .toList();

    return Scaffold(
      backgroundColor: peachBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: peachBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: shadowLight, offset: Offset(-4, -4), blurRadius: 8),
                        BoxShadow(color: shadowDark, offset: Offset(4, 4), blurRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.translate_rounded, size: 32, color: darkBrown),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iTANTRA',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: darkBrown, letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Language Setup',
                        style: TextStyle(fontSize: 14, color: Color(0xFF8C6F66), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E4D9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFE0CFBE), offset: Offset(3, 3), blurRadius: 6),
                    BoxShadow(color: shadowLight, offset: Offset(-3, -3), blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _checking
                          ? 'Checking language packs...'
                          : _allInstalled
                              ? '✅ All 10 language packs installed!'
                              : '${missingLangs.length} language pack(s) need installation',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: _allInstalled ? const Color(0xFF2E7D32) : darkBrown,
                      ),
                    ),
                    if (!_allInstalled && !_checking)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Tap "Install Packs" below to open Android TTS settings.\nInstall voices for all languages, then come back.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8C6F66), fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Language list
              Expanded(
                child: _checking
                    ? const Center(child: CircularProgressIndicator(color: darkBrown))
                    : ListView(
                        children: _langNames.entries.map((entry) {
                          final status = _packStatus[entry.key] ?? 'UNKNOWN';
                          final isAvail = status == 'AVAILABLE';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: peachBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: shadowLight, offset: Offset(-3, -3), blurRadius: 6),
                                BoxShadow(color: shadowDark, offset: Offset(3, 3), blurRadius: 6),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAvail ? Icons.check_circle_rounded : Icons.download_rounded,
                                  color: isAvail ? const Color(0xFF2E7D32) : softRed,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: isAvail ? darkBrown : const Color(0xFF8C6F66),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAvail
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFCE4EC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isAvail ? 'READY' : status,
                                    style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w800,
                                      color: isAvail ? const Color(0xFF2E7D32) : softRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  if (!_allInstalled) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _installPacks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: peachBg,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(color: shadowLight, offset: Offset(-4, -4), blurRadius: 8),
                              BoxShadow(color: shadowDark, offset: Offset(4, 4), blurRadius: 8),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.download_rounded, color: softRed, size: 24),
                              SizedBox(height: 4),
                              Text(
                                'Install Packs',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: softRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _checkPacks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: peachBg,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(color: shadowLight, offset: Offset(-4, -4), blurRadius: 8),
                              BoxShadow(color: shadowDark, offset: Offset(4, 4), blurRadius: 8),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.refresh_rounded, color: Color(0xFF5A3E36), size: 24),
                              SizedBox(height: 4),
                              Text(
                                'Re-check',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: Color(0xFF5A3E36),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onComplete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _allInstalled ? const Color(0xFF2E7D32) : peachBg,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: shadowLight, offset: Offset(-4, -4), blurRadius: 8),
                            BoxShadow(color: shadowDark, offset: Offset(4, 4), blurRadius: 8),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: _allInstalled ? Colors.white : const Color(0xFF8C6F66),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _allInstalled ? 'Start App' : 'Skip',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                color: _allInstalled ? Colors.white : const Color(0xFF8C6F66),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
