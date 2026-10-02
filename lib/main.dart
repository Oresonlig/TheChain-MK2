import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'app/supabase_backend.dart';
import 'theme/nanosuit.dart';
import 'ui/dev_home_screen.dart';
import 'ui/login_screen.dart';

/// Kanal och byggnummer injiceras av CI via --dart-define.
const String kChannel = String.fromEnvironment('CHANNEL', defaultValue: 'local');
const String kBuild = String.fromEnvironment('BUILD', defaultValue: '0');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await SupabaseBackend.init();
  final app = AppController(backend);
  runApp(TheChainApp(app: app, emailOf: () => backend.userEmail ?? ''));
  await app.start();
}

class TheChainApp extends StatelessWidget {
  const TheChainApp({super.key, required this.app, required this.emailOf});

  final AppController app;
  final String Function() emailOf;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Chain',
      debugShowCheckedModeBanner: false,
      theme: nanosuitThemeData(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => switch (app.phase) {
          Phase.signedOut => LoginScreen(app: app),
          Phase.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
          Phase.ready => DevHomeScreen(app: app, email: emailOf(), buildLabel: '$kChannel · build $kBuild'),
        },
      ),
    );
  }
}
