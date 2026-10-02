/// Inloggning (F2). Samma konto som på hemsidan. Google-inloggning kommer senare.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'nanosuit_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app, this.versionLabel = ''});
  final AppController app;

  /// T.ex. "MK2 DEV · build 21" — Niklas ska se direkt vid inloggning om
  /// rätt version är installerad.
  final String versionLabel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() => widget.app.signIn(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: text.labelSmall,
          filled: true,
          fillColor: c.background.withValues(alpha: .6),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
        );
    return ChainScaffold(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
          children: [
            Text('THE', style: text.displaySmall),
            Text('CHAIN',
                style: text.displaySmall!.copyWith(
                  color: c.accent,
                  shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 14)],
                )),
            const SizedBox(height: 32),
            Glass(
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Sign in with your account', style: text.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    decoration: deco('EMAIL'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: text.bodyMedium!.copyWith(color: c.textStrong),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: deco('PASSWORD'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    style: text.bodyMedium!.copyWith(color: c.textStrong),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: widget.app.busy ? null : _submit,
                    child: Raised(
                      material: c.raisedActive,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: Text(widget.app.busy ? 'SIGNING IN…' : 'SIGN IN', style: text.labelLarge)),
                    ),
                  ),
                  if (widget.app.error != null) ...[
                    const SizedBox(height: 12),
                    Text(widget.app.error!, style: text.bodySmall!.copyWith(color: const Color(0xFFFF6B6B))),
                  ],
                  if (widget.versionLabel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(widget.versionLabel, style: text.labelSmall, textAlign: TextAlign.center),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
