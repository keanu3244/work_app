import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_boilerplate/feature/auth/widget/sign_in_page.dart';
import 'package:flutter_boilerplate/feature/notification/local_notification_service.dart';
import 'package:flutter_boilerplate/feature/notification/push_registration_service.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_boilerplate/feature/session/auth_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WorkContainerPage extends StatefulWidget {
  const WorkContainerPage({required this.session, super.key});

  final AppSession session;

  @override
  State<WorkContainerPage> createState() => _WorkContainerPageState();
}

class _WorkContainerPageState extends State<WorkContainerPage> {
  final _store = const AppSessionStore();
  final _authClient = AuthClient();
  static const _systemChannel = MethodChannel('work_app/system');
  int _reloadKey = 0;
  late final String _webCacheKey;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _webCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
    _registerPushToken();
  }

  Future<void> _registerPushToken() async {
    try {
      await PushRegistrationService.instance.registerCurrentDevice(
        authClient: _authClient,
        session: widget.session,
      );
    } catch (_) {
      // 推送注册失败不影响 H5 主业务。
    }
  }

  String get _launchUrl {
    final raw =
        dotenv.env['WORK_APP_B_URL'] ?? 'http://43.155.239.210/work-app-b/';
    final uri = Uri.parse(raw);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'uid': widget.session.uid,
        'sid': widget.session.sid,
        'token': widget.session.accessToken,
        'app_v': _webCacheKey,
      },
    ).toString();
  }

  String get _bootstrapScript {
    final payload = jsonEncode({
      'uid': widget.session.uid,
      'sid': widget.session.sid,
      'access_token': widget.session.accessToken,
      'nick': widget.session.nick,
      'app_version_name': dotenv.env['APP_VERSION_NAME'] ?? '1.0.0',
      'app_version_code':
          int.tryParse(dotenv.env['APP_VERSION_CODE'] ?? '') ?? 1,
    });
    return 'window.__WORK_APP_SESSION__ = $payload;';
  }

  Future<bool> _openExternalUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      return await _systemChannel.invokeMethod<bool>(
            'openUrl',
            {'url': url},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _logout() async {
    try {
      await PushRegistrationService.instance.deleteCurrentDevice(
        authClient: _authClient,
        session: widget.session,
      );
    } catch (_) {
      // 推送注销失败不影响退出。
    }
    try {
      await _authClient.logout(widget.session.accessToken);
    } catch (_) {
      // 本地退出不依赖网络。
    }
    await _store.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SignInPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              key: ValueKey(_reloadKey),
              initialSettings: InAppWebViewSettings(
                cacheEnabled: false,
                clearCache: true,
              ),
              initialUrlRequest: URLRequest(url: WebUri(_launchUrl)),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: _bootstrapScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) {
                controller
                  ..addJavaScriptHandler(
                    handlerName: 'workAppLogout',
                    callback: (_) async {
                      await _logout();
                      return true;
                    },
                  )
                  ..addJavaScriptHandler(
                    handlerName: 'workAppNotify',
                    callback: (arguments) async {
                      final payload = arguments.isNotEmpty
                          ? arguments.first
                          : const <String, dynamic>{};
                      final data =
                          payload is Map ? payload : const <String, dynamic>{};
                      final title = data['title']?.toString() ?? 'Work IM';
                      final body = data['body']?.toString() ?? '你收到一条新消息';
                      final shown =
                          await LocalNotificationService.instance.showMessage(
                        title: title,
                        body: body,
                      );
                      return shown;
                    },
                  )
                  ..addJavaScriptHandler(
                    handlerName: 'workAppOpenUrl',
                    callback: (arguments) async {
                      final payload = arguments.isNotEmpty
                          ? arguments.first
                          : const <String, dynamic>{};
                      final data =
                          payload is Map ? payload : const <String, dynamic>{};
                      final url = data['url']?.toString() ?? '';
                      return _openExternalUrl(url);
                    },
                  );
              },
              onLoadStart: (_, __) {
                setState(() {
                  _loading = true;
                  _error = null;
                });
              },
              onLoadStop: (_, __) {
                setState(() {
                  _loading = false;
                });
              },
              onReceivedError: (_, request, error) {
                if (!(request.isForMainFrame ?? true)) return;
                setState(() {
                  _loading = false;
                  _error = error.description;
                });
              },
            ),
            if (_loading && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _reloadKey += 1;
                            _loading = true;
                            _error = null;
                          });
                        },
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
