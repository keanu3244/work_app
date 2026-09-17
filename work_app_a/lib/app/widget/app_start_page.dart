import 'package:flutter/material.dart';
import 'package:flutter_boilerplate/feature/auth/widget/sign_in_page.dart';
import 'package:flutter_boilerplate/feature/container/work_container_page.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_boilerplate/shared/widget/loading_widget.dart';

class AppStartPage extends StatelessWidget {
  const AppStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSession?>(
      future: const AppSessionStore().read(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingWidget();
        }
        final session = snapshot.data;
        if (session == null || session.isExpired) {
          return const SignInPage();
        }
        return WorkContainerPage(session: session);
      },
    );
  }
}
