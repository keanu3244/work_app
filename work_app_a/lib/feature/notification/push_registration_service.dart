import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_boilerplate/feature/session/auth_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pushTokenStorageKey = 'work_app:push_token';
const _pushTokenUidStorageKey = 'work_app:push_token_uid';

class PushRegistrationService {
  PushRegistrationService._();

  static final instance = PushRegistrationService._();
  static const _channel = MethodChannel('work_app/push');

  Future<void> registerCurrentDevice({
    required AuthClient authClient,
    required AppSession session,
  }) async {
    final deviceToken = await _readDeviceToken();
    if (deviceToken == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_pushTokenStorageKey) == deviceToken.token &&
        prefs.getString(_pushTokenUidStorageKey) == session.uid) {
      return;
    }

    await authClient.registerPushToken(
      accessToken: session.accessToken,
      platform: deviceToken.platform,
      provider: deviceToken.provider,
      token: deviceToken.token,
    );
    await prefs.setString(_pushTokenStorageKey, deviceToken.token);
    await prefs.setString(_pushTokenUidStorageKey, session.uid);
  }

  Future<void> deleteCurrentDevice({
    required AuthClient authClient,
    required AppSession session,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pushTokenStorageKey);
    if (token == null || token.isEmpty) return;
    await authClient.deletePushToken(
      accessToken: session.accessToken,
      token: token,
    );
    await prefs.remove(_pushTokenStorageKey);
    await prefs.remove(_pushTokenUidStorageKey);
  }

  Future<_DevicePushToken?> _readDeviceToken() async {
    if (kIsWeb) {
      return null;
    }
    final platform = _pushPlatform;
    if (platform == null) return null;
    final String? token;
    try {
      token = await _channel.invokeMethod<String>('getDevicePushToken');
    } on PlatformException {
      return null;
    }
    if (token == null || token.isEmpty) return null;
    return _DevicePushToken(
      platform: platform,
      provider: platform == 'android' ? 'fcm' : 'apns',
      token: token,
    );
  }

  String? get _pushPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }
}

class _DevicePushToken {
  const _DevicePushToken({
    required this.platform,
    required this.provider,
    required this.token,
  });

  final String platform;
  final String provider;
  final String token;
}
