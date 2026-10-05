/// Inloggning (F2). Samma konto som på hemsidan. Google-inloggning kommer senare.
/// Glömt lösenord: koden ur mejlet + nytt lösenord i samma panel — användaren
/// lämnar aldrig appen (länken i samma mejl går till hemsidan).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'nanosuit_scaffold.dart';

/// Inloggning, glömt lösenord (kod), nytt konto, bekräfta nytt konto (kod).
enum _Mode { signIn, reset, signUp, signUpCode }

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
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();

  _Mode _mode = _Mode.signIn;
  String? _info;

  @override
  void dispose() {
    for (final c in [_email, _password, _code, _newPassword, _confirm, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() => widget.app.signIn(_email.text, _password.text);

  Future<void> _sendCode({bool again = false}) async {
    setState(() => _info = null);
    if (!await widget.app.sendResetCode(_email.text) || !mounted) return;
    setState(() {
      _mode = _Mode.reset;
      _code.clear();
      _info = again ? 'New code sent. Use the latest email.' : null;
    });
  }

  Future<void> _setPassword() =>
      widget.app.resetPassword(_email.text, _code.text, _newPassword.text, _confirm.text);

  Future<void> _createAccount() async {
    final needsCode = await widget.app.signUp(_email.text, _newPassword.text, _confirm.text, _name.text);
    if (!needsCode || !mounted) return;
    setState(() {
      _mode = _Mode.signUpCode;
      _code.clear();
      _info = null;
    });
  }

  Future<void> _resendSignup() async {
    if (await widget.app.resendSignupCode(_email.text) && mounted) {
      setState(() => _info = 'New code sent. Use the latest email.');
    }
  }

  void _go(_Mode m) {
    widget.app.clearError();
    setState(() {
      _mode = m;
      _info = null;
      _code.clear();
      _newPassword.clear();
      _confirm.clear();
    });
  }

  void _backToSignIn() => _go(_Mode.signIn);

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (_mode) {
                      _Mode.signIn => _signInFields(c, text),
                      _Mode.reset => _resetFields(c, text),
                      _Mode.signUp => _signUpFields(c, text),
                      _Mode.signUpCode => _signUpCodeFields(c, text),
                    },
                    if (_info != null && widget.app.error == null) ...[
                      const SizedBox(height: 12),
                      Text(_info!, style: text.bodySmall!.copyWith(color: c.accent)),
                    ],
                    if (widget.app.error != null) ...[
                      const SizedBox(height: 12),
                      Text(widget.app.error!, style: text.bodySmall!.copyWith(color: c.fail)),
                    ],
                    if (widget.versionLabel.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(widget.versionLabel, style: text.labelSmall, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(ChainTheme c, TextTheme text, String label) => InputDecoration(
        labelText: label,
        labelStyle: text.labelSmall,
        filled: true,
        fillColor: c.background.withValues(alpha: .6),
        counterText: '',
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
      );

  Widget _primary(ChainTheme c, TextTheme text, String label, String busyLabel, VoidCallback onTap) => GestureDetector(
        onTap: widget.app.busy ? null : onTap,
        child: Raised(
          material: c.raisedActive,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: Text(widget.app.busy ? busyLabel : label, style: text.labelLarge)),
        ),
      );

  /// Diskret textlänk med full träffyta (48 px).
  Widget _link(ChainTheme c, TextTheme text, String label, VoidCallback onTap) => TextButton(
        onPressed: widget.app.busy ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: c.textMuted,
          disabledForegroundColor: c.textFaint,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(),
          textStyle: text.bodySmall,
        ),
        child: Text(label),
      );

  List<Widget> _signInFields(ChainTheme c, TextTheme text) => [
        Text('Sign in with your account', style: text.titleMedium),
        const SizedBox(height: 16),
        GhostButton(
          label: 'SIGN IN WITH GOOGLE',
          onTap: widget.app.busy ? null : widget.app.signInWithGoogle,
          color: c.textStrong,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Divider(color: c.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: text.bodySmall!.copyWith(color: c.textMuted)),
          ),
          Expanded(child: Divider(color: c.border, height: 1)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          decoration: _deco(c, text, 'EMAIL'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          decoration: _deco(c, text, 'PASSWORD'),
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 20),
        _primary(c, text, 'SIGN IN', 'SIGNING IN…', _submit),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _link(c, text, 'Forgot password?', _sendCode)),
          Expanded(child: _link(c, text, 'Create account', () => _go(_Mode.signUp))),
        ]),
      ];

  TextField _codeField(ChainTheme c, TextTheme text) => TextField(
        controller: _code,
        decoration: _deco(c, text, 'CODE FROM THE EMAIL'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 8, // Supabase-projektets kodlängd är 6 eller 8
        autofillHints: const [AutofillHints.oneTimeCode],
        style: text.titleMedium!.copyWith(color: c.textStrong, letterSpacing: 6, fontFeatures: const [FontFeature.tabularFigures()]),
      );

  List<Widget> _signUpFields(ChainTheme c, TextTheme text) => [
        Text('Create account', style: text.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: _deco(c, text, 'NAME'),
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          decoration: _deco(c, text, 'EMAIL'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPassword,
          decoration: _deco(c, text, 'PASSWORD (8+ CHARACTERS)'),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          decoration: _deco(c, text, 'CONFIRM PASSWORD'),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _createAccount(),
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 20),
        _primary(c, text, 'CREATE ACCOUNT', 'CREATING…', _createAccount),
        const SizedBox(height: 4),
        _link(c, text, 'Back to sign in', _backToSignIn),
      ];

  List<Widget> _signUpCodeFields(ChainTheme c, TextTheme text) => [
        Text('Confirm your email', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(
            'We sent a code to ${_email.text.trim()}. Enter it to finish. '
            'Nothing arrived? The address may already have an account — sign in or reset the password.',
            style: text.bodySmall!.copyWith(color: c.textBody)),
        const SizedBox(height: 16),
        _codeField(c, text),
        const SizedBox(height: 20),
        _primary(c, text, 'CONFIRM', 'CHECKING…', () => widget.app.verifySignupCode(_email.text, _code.text)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _link(c, text, 'Resend code', _resendSignup)),
          Expanded(child: _link(c, text, 'Back to sign in', _backToSignIn)),
        ]),
      ];

  List<Widget> _resetFields(ChainTheme c, TextTheme text) => [
        Text('Reset password', style: text.titleMedium),
        const SizedBox(height: 6),
        Text('We sent a code to ${_email.text.trim()}. Enter it below with your new password.',
            style: text.bodySmall!.copyWith(color: c.textBody)),
        const SizedBox(height: 16),
        _codeField(c, text),
        const SizedBox(height: 12),
        TextField(
          controller: _newPassword,
          decoration: _deco(c, text, 'NEW PASSWORD'),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          decoration: _deco(c, text, 'CONFIRM NEW PASSWORD'),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _setPassword(),
          style: text.bodyMedium!.copyWith(color: c.textStrong),
        ),
        const SizedBox(height: 20),
        _primary(c, text, 'SET PASSWORD', 'WORKING…', _setPassword),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _link(c, text, 'Resend code', () => _sendCode(again: true))),
          Expanded(child: _link(c, text, 'Back to sign in', _backToSignIn)),
        ]),
      ];
}
