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
}

