// Statisk koll: toppnivå-funktioner, klasser, enums, typedefs och konstanter i
// lib/ som inte nämns någon annanstans i lib/ (tester räknas separat — används
// något BARA av tester är det död kod i appen). Grovt (namnbaserat), men hittar
// på sekunder det som annars kräver att man läser allt.
//   node tool/find_unused.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const walk = (d) =>
  readdirSync(d).flatMap((f) => {
    const p = join(d, f);
    return statSync(p).isDirectory() ? walk(p) : p.endsWith('.dart') ? [p] : [];
  });
const lib = walk(join(root, 'lib')).map((p) => ({ p, src: readFileSync(p, 'utf8') }));
const test = walk(join(root, 'test')).map((p) => readFileSync(p, 'utf8')).join('\n');

const decl =
  /^(?:abstract\s+|sealed\s+|final\s+|base\s+)*(?:class|enum|mixin|typedef|extension type)\s+(\w+)|^(?:const|final)\s+(?:[\w<>?,\s]+\s+)?(\w+)\s*=|^(?:[\w<>?,()\s]+\s+)?(\w+)\s*(?:<[^>]*>)?\([^)]*\)?\s*(?:async\*?|sync\*)?\s*(?:=>|\{)/gm;
const skip = new Set(['main', 'build', 'createState', 'toString', 'runApp']);
const out = [];
for (const { p, src } of lib) {
  for (const m of src.matchAll(decl)) {
    const name = m[1] ?? m[2] ?? m[3];
    if (!name || skip.has(name) || name.startsWith('_')) continue;
    // Ramverket anropar @override-metoder; "x(" efter "=" eller "return" är ett anrop, inte en deklaration.
    const before = src.slice(Math.max(0, m.index - 80), m.index);
    if (/@override\s*$/.test(before) || /(=|return|=>|\(|,)\s*$/.test(before)) continue;
    const re = new RegExp(`\\b${name}\\b`, 'g');
    const inLib = lib.reduce((n, f) => n + (f.src.match(re)?.length ?? 0), 0);
    if (inLib <= 1) out.push(`${relative(root, p)}: ${name}${re.test(test) ? '  (bara tester)' : ''}`);
  }
}
console.log(out.length ? out.join('\n') : 'Inget oanvänt hittat.');
