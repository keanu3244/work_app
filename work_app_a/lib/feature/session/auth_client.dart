import 'package:dio/dio.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthClient {
  AuthClient() {
    _dio.options
      ..baseUrl = dotenv.env['BASE_URL'] ??
          'https://communication-backend.randomness.website/api/v1'
      ..connectTimeout = const Duration(seconds: 8)
      ..receiveTimeout = const Duration(seconds: 8);
  }

  final Dio _dio = Dio();

  Future<AppSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(validateStatus: (status) => true),
    );
    return _readSession(response);
  }

  Future<AppSession> register({
    required String email,
    required String password,
    required String nick,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password, 'nick': nick},
      options: Options(validateStatus: (status) => true),
    );
    return _readSession(response);
  }

  Future<AppSession> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(validateStatus: (status) => true),
    );
    return _readSession(response);
  }

  Future<void> logout(String accessToken) async {
    await _dio.post<void>(
      '/auth/logout',
      data: const {},
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        validateStatus: (status) => true,
      ),
    );
  }

  Future<void> registerPushToken({
    required String accessToken,
    required String platform,
    required String provider,
    required String token,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/im/push/token',
      data: {
        'platform': platform,
        'provider': provider,
        'token': token,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        validateStatus: (status) => true,
      ),
    );
    _ensureSuccess(response, '推送 token 注册失败');
  }

  Future<void> deletePushToken({
    required String accessToken,
    required String token,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/im/push/token/delete',
      data: {'token': token},
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        validateStatus: (status) => true,
      ),
    );
    _ensureSuccess(response, '推送 token 注销失败');
  }

  AppSession _readSession(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (response.statusCode == 401) {
      throw Exception('登录已失效，请重新登录');
    }
    if (body == null) {
      throw Exception('服务无响应');
    }
    if (body['code'] != 0) {
      final message = body['message'];
      throw Exception(message is String ? message : '登录失败');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('登录响应格式不正确');
    }
    return AppSession.fromAuthJson(data);
  }

  void _ensureSuccess(
    Response<Map<String, dynamic>> response,
    String fallbackMessage,
  ) {
    final body = response.data;
    if (body == null) {
      throw Exception(fallbackMessage);
    }
    if (body['code'] != 0) {
      final message = body['message'];
      throw Exception(message is String ? message : fallbackMessage);
    }
  }
}
