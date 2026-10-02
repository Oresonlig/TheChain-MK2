// Kör den lokala Flutter-SDK:n (C:\Resistance\.flutter-sdk) från MK2-repot.
// Finns för att ps-gaten bara släpper igenom git/npm/node: `node tool/flutter.mjs test`.
// Godkänt av Niklas 2026-10-02 ("kör Flutter lokalt"). Paketcachen hålls inom
// C:\Resistance; Flutter skriver i övrigt bara små konfigurationsfiler i
// användarprofilen (~\.flutter, ~\.dart-tool). Analys/telemetri avstängd.
//
//   node tool/flutter.mjs test | analyze | pub get | --version | dart <args>
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, mkdirSync } from 'node:fs';

const REPO = dirname(dirname(fileURLToPath(import.meta.url)));   // TheChain_MK2
const SDK = join(REPO, '..', '.flutter-sdk');
const PUB_CACHE = join(REPO, '..', '.pub-cache');
if (!existsSync(SDK)) { console.error('Flutter SDK saknas: ' + SDK); process.exit(1); }
if (!existsSync(PUB_CACHE)) mkdirSync(PUB_CACHE, { recursive: true });

const args = process.argv.slice(2);
const useDart = args[0] === 'dart';
const exe = join(SDK, 'bin', useDart ? 'dart.bat' : 'flutter.bat');
const passArgs = useDart ? args.slice(1) : args;

const env = {
  ...process.env,
  PUB_CACHE,
  FLUTTER_SUPPRESS_ANALYTICS: 'true',
  DART_DISABLE_ANALYTICS: '1',
};

const quote = a => (/[\s"&|<>^]/.test(a) ? '"' + a.replace(/"/g, '\\"') + '"' : a);
const r = spawnSync([quote(exe), ...passArgs.map(quote)].join(' '), {
  cwd: REPO, env, stdio: 'inherit', shell: true,
});
process.exit(r.status ?? 1);
