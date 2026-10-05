import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'app/native_rest_alarm.dart';
import 'app/rest_timer.dart';
import 'theme/chain_theme.dart';
import 'app/supabase_backend.dart';
import 'app/updater.dart';
import 'theme/nanosuit.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

/// Kanal och byggnummer injiceras av CI via --dart-define.
const String kChannel = String.fromEnvironment('CHANNEL', defaultValue: 'local');
const String kBuild = String.fromEnvironment('BUILD', defaultValue: '0');

/// "MK2 DEV · build 21" — syns i inloggningen och i Settings.
String get kVersionLabel => 'MK2 ${kChannel.toUpperCase()} · build $kBuild';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await SupabaseBackend.init();
  final app = AppController(
    backend,
    updater: kChannel == 'dev' ? Updater(channel: kChannel, currentBuild: int.tryParse(kBuild) ?? 0) : null,
    restTimer: RestTimer(alarm: NativeRestAlarm(look: nanosuitThemeData().extension<ChainTheme>()!)),
    appBuild: kBuild == '0' ? '' : '${kChannel.toUpperCase()} · build $kBuild',
  );
  runApp(TheChainApp(app: app, emailOf: () => backend.userEmail ?? ''));
  await app.start();
}

class TheChainApp extends StatefulWidget {
  const TheChainApp({super.key, required this.app, required this.emailOf});

  final AppController app;
  final String Function() emailOf;

  @override
  State<TheChainApp> createState() => _TheChainAppState();
}

class _TheChainAppState extends State<TheChainApp> {
  final _navigator = GlobalKey<NavigatorState>();
  Phase? _lastPhase;

  AppController get app => widget.app;
  String Function() get emailOf => widget.emailOf;

  /// Versionskollen går bara medan appen syns.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    app.addListener(_onPhase);
    app.startUpdatePolling();
    app.restTimer.appResumed(); // larm som ringer / vila som pågår när appen startar
    _lifecycle = AppLifecycleListener(
      onShow: () {
        app.startUpdatePolling();
        app.restTimer.appResumed();
      },
      onHide: app.stopUpdatePolling,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    app.stopUpdatePolling();
    app.removeListener(_onPhase);
    super.dispose();
  }

  /// Utloggad (själv eller sessionen gick ut): stäng allt som ligger ovanpå
  /// hemvyn. Annars blir t.ex. Data check eller passvyn kvar överst utan konto
  /// och visar en snurra för evigt, med inloggningen dold under (2026-10-04).
  void _onPhase() {
    final p = app.phase;
    if (p == Phase.signedOut && _lastPhase != Phase.signedOut) {
      _navigator.currentState?.popUntil((r) => r.isFirst);
    }
    _lastPhase = p;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'The Chain',
      debugShowCheckedModeBanner: false,
      theme: nanosuitThemeData(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => switch (app.phase) {
          Phase.signedOut => LoginScreen(app: app, versionLabel: kVersionLabel),
          Phase.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
          Phase.ready => HomeShell(app: app, email: emailOf(), versionLabel: kVersionLabel),
        },
      ),
    );
  }
}
