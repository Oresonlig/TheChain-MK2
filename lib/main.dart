import 'package:flutter/material.dart';

/// F0 — tom app som bevisar att kedjan push → CI → APK fungerar.
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
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B1A1A),
          brightness: Brightness.dark,
        ),
      ),
      home: const PlaceholderScreen(),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('THE CHAIN', style: text.headlineLarge),
            const SizedBox(height: 8),
            Text('MK2 · F0', style: text.titleMedium),
            const SizedBox(height: 24),
            Text('channel $kChannel · build $kBuild', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
