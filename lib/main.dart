import 'package:flutter/material.dart';

import 'theme/nanosuit.dart';
import 'ui/theme_preview.dart';

/// Kanal och byggnummer injiceras av CI via --dart-define.
const String kChannel = String.fromEnvironment('CHANNEL', defaultValue: 'local');
const String kBuild = String.fromEnvironment('BUILD', defaultValue: '0');

void main() => runApp(const TheChainApp());

class TheChainApp extends StatelessWidget {
  const TheChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Chain',
      debugShowCheckedModeBanner: false,
      theme: nanosuitThemeData(),
      home: const ThemePreviewScreen(channelLabel: '$kChannel · build $kBuild'),
    );
  }
}
