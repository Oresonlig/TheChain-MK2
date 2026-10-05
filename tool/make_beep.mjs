// Genererar vilotimerns pipljud: tre korta pip (≈1,2 s), 16-bit mono WAV.
// Kör: node tool/make_beep.mjs → tool/res/raw/rest_beep.wav (kopieras till
// android/…/res/raw av configure_android.mjs).
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), 'res', 'raw', 'rest_beep.wav');
const rate = 44100;
const beep = 0.16, gap = 0.12, freq = 1760; // högt, kort, skär igenom gymmusik
const total = 3 * beep + 2 * gap + 0.05;
const n = Math.round(total * rate);
const pcm = Buffer.alloc(n * 2);
for (let i = 0; i < n; i++) {
  const t = i / rate;
  const k = Math.floor(t / (beep + gap));
  const local = t - k * (beep + gap);
  let v = 0;
  if (k < 3 && local < beep) {
    const fade = Math.min(1, local / 0.005, (beep - local) / 0.005); // inga klick
    v = Math.sin(2 * Math.PI * freq * t) * 0.9 * fade;
  }
  pcm.writeInt16LE(Math.round(v * 32767), i * 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0);
h.writeUInt32LE(36 + pcm.length, 4);
h.write('WAVE', 8);
h.write('fmt ', 12);
h.writeUInt32LE(16, 16);
h.writeUInt16LE(1, 20);
h.writeUInt16LE(1, 22);
h.writeUInt32LE(rate, 24);
h.writeUInt32LE(rate * 2, 28);
h.writeUInt16LE(2, 32);
h.writeUInt16LE(16, 34);
h.write('data', 36);
h.writeUInt32LE(pcm.length, 40);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, Buffer.concat([h, pcm]));
console.log(`${out} (${((44 + pcm.length) / 1024).toFixed(1)} KB, ${total.toFixed(2)} s)`);
