import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boilerplate/feature/container/work_container_page.dart';
import 'package:flutter_boilerplate/feature/session/app_session.dart';
import 'package:flutter_boilerplate/feature/session/auth_client.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nickController = TextEditingController();
  final _authClient = AuthClient();
  final _store = const AppSessionStore();

  bool _registering = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = _registering
          ? await _authClient.register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              nick: _nickController.text.trim(),
            )
          : await _authClient.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      await _store.write(session);
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => WorkContainerPage(session: session),
        ),
        (_) => false,
      );
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.only(left: 20, right: 20),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 150),
            Text(
              _registering ? 'sign_up'.tr() : 'sign_in'.tr(),
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
            ),
            Form(
              child: Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'email'.tr()),
                    controller: _emailController,
                  ),
                  if (_registering)
                    TextFormField(
                      decoration: const InputDecoration(labelText: '昵称'),
                      controller: _nickController,
                    ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'password'.tr()),
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 30),
                      _widgetSignInButton(context),
                      const SizedBox(height: 30),
                      _widgetSignUpButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _widgetSignInButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        child: Text(
          _submitting
              ? '处理中...'
              : (_registering ? 'sign_up'.tr() : 'sign_in'.tr()),
        ),
      ),
    );
  }

  Widget _widgetSignUpButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          setState(() {
            _registering = !_registering;
            _error = null;
          });
        },
        child: Text(_registering ? 'sign_in'.tr() : 'sign_up'.tr()),
      ),
    );
  }
}
