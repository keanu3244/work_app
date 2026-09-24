import 'package:flutter/material.dart';
import 'package:flutter_boilerplate/feature/auth/widget/sign_in_page.dart';
import 'package:flutter_boilerplate/feature/container/work_container_page.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_boilerplate/feature/session/auth_client.dart';
import 'package:flutter_boilerplate/shared/widget/loading_widget.dart';

class AppStartPage extends StatelessWidget {
  const AppStartPage({super.key});

  Future<AppSession?> _restoreSession() async {
    const store = AppSessionStore();
    final session = await store.read();
    if (session == null || !session.isExpired) return session;
    try {
      final refreshed = await AuthClient().refresh(session.refreshToken);
      await store.write(refreshed);
      return refreshed;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSession?>(
      future: _restoreSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingWidget();
        }
        final session = snapshot.data;
        if (session == null) {
          return const SignInPage();
        }
        return WorkContainerPage(session: session);
      },
    );
  }
}
