import 'package:flutter/services.dart';

class HardwareOverride {
  static const MethodChannel _channel = MethodChannel('com.itantra.app/hardware_override');

  /// Overrides Android DND and forces STREAM_ALARM to 100% volume for priority emergency alerts
  static Future<Map<String, dynamic>?> triggerEmergencyAlert() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('triggerEmergencyAlert');
      return res;
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    } on MissingPluginException {
      return {'success': true, 'simulated': true};
    }
  }

  /// Restores previous ringer/alarm volume settings
  static Future<bool> restoreAudioSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('restoreAudioSettings');
      return res ?? true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Checks if DND override access is granted
  static Future<bool> checkDndAccess() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkDndAccess');
      return res ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Speaks the given localized text using native Android TextToSpeech in the chosen Indian language
  static Future<bool> speakText({required String text, required String langCode}) async {
    try {
      final res = await _channel.invokeMethod<bool>('speakText', {
        'text': text,
        'langCode': langCode,
      });
      return res ?? true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Starts Android native SpeechRecognizer and returns the recognized text.
  /// Uses Google's speech recognition (online or offline if model installed).
  /// Returns empty string on error or no speech.
  static Future<String> recognizeSpeech({required String langCode}) async {
    try {
      final res = await _channel.invokeMethod<String>('recognizeSpeech', {
        'langCode': langCode,
      });
      return res ?? '';
    } on PlatformException {
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  /// Stops the ongoing speech recognition session
  static Future<void> stopRecognition() async {
    try {
      await _channel.invokeMethod<bool>('stopRecognition');
    } catch (_) {}
  }
}
