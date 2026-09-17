import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'work_app:session';

class AppSession {
  const AppSession({
    required this.uid,
    required this.sid,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.nick,
  });

  factory AppSession.fromAuthJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final expiresIn = json['expires_in'];
    final nick = json['nick'];
    if (uid is! int ||
        accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresIn is! int ||
        expiresIn <= 0) {
      throw const FormatException('登录响应格式不正确');
    }
    return AppSession(
      uid: uid.toString(),
      sid: _readSessionId(accessToken),
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      nick: nick is String && nick.isNotEmpty ? nick : uid.toString(),
    );
  }

  factory AppSession.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Session payload must be an object.');
    }
    final uid = json['uid'];
    final sid = json['sid'];
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['expiresAt'];
    final nick = json['nick'];
    final parsedExpiresAt =
        expiresAt is String ? DateTime.tryParse(expiresAt) : null;
    if (uid is! String ||
        sid is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        parsedExpiresAt == null) {
      throw const FormatException('Session payload is invalid.');
    }
    return AppSession(
      uid: uid,
      sid: sid,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: parsedExpiresAt.toUtc(),
      nick: nick is String ? nick : uid,
    );
  }

  final String uid;
  final String sid;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String nick;

  bool get isExpired => !expiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'sid': sid,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'nick': nick,
      };
}

class AppSessionStore {
  const AppSessionStore();

  static const _secureStorage = FlutterSecureStorage();

  Future<AppSession?> read() async {
    final secureValue = await _secureStorage.read(key: _sessionStorageKey);
    final prefs = await SharedPreferences.getInstance();
    final value = secureValue ?? prefs.getString(_sessionStorageKey);
    if (value == null || value.isEmpty) return null;
    try {
      return AppSession.fromJson(jsonDecode(value));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AppSession session) async {
    final value = jsonEncode(session.toJson());
    try {
      await _secureStorage.write(key: _sessionStorageKey, value: value);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStorageKey, value);
    }
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _sessionStorageKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
  }
}

String _readSessionId(String accessToken) {
  final parts = accessToken.split('.');
  if (parts.length != 3) return '';
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  final sid = (payload as Map<String, dynamic>)['sid'];
  return sid is String ? sid : '';
}
