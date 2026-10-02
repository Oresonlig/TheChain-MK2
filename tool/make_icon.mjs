// Gör MK2:s appikon ur MK1:s ikon, omfärgad till Nanosuit: den röda länken och
// glöden blir Nanosuit-cyan (#00D4FF), grått och svart får en kall marinblå ton.
// Pixelvis — formen, skuggorna och den rundade alfakanten är orörda.
// Lokalt verktyg (sharp från C:\Resistance\node_modules).
// Kör: node tool/make_icon.mjs [--preview fil.png]  → assets/icon/icon.png (1024 px)
import sharp from 'sharp';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(dirname(fileURLToPath(import.meta.url)));
const SRC = join(REPO, '..', 'icons', 'icon-512.png'); // MK1:s färdiga, rundade ikon
const OUT = join(REPO, 'assets', 'icon');
mkdirSync(OUT, { recursive: true });

const CYAN = [0, 212, 255];
const { data, info } = await sharp(SRC)
  .resize(1024, 1024, { kernel: 'lanczos3' })
  .ensureAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true });

const out = Buffer.alloc(data.length);
for (let i = 0; i < data.length; i += 4) {
  const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
  const base = (g + b) / 2; // ljusheten utan det röda överskottet
  const red = Math.max(0, r - base) / 255; // hur "röd" pixeln är (länk + glöd)
  // Kall marinblå ton på det gråa/svarta
  let nr = base * 0.78, ng = base * 0.92, nb = base * 1.12 + 3;
  // Rött → cyan. Kurvan (^0.75) lyfter den svaga glöden runt länken mer än
  // själva länken — Niklas: "ta den med lite mer glöd".
  const glow = Math.pow(red, 0.75) * 1.45;
  nr += CYAN[0] * glow;
  ng += CYAN[1] * glow;
  nb += CYAN[2] * glow;
  out[i] = Math.min(255, Math.round(nr));
  out[i + 1] = Math.min(255, Math.round(ng));
  out[i + 2] = Math.min(255, Math.round(nb));
  out[i + 3] = a; // formen orörd
}
await sharp(out, { raw: { width: info.width, height: info.height, channels: 4 } }).png().toFile(join(OUT, 'icon.png'));
console.log('assets/icon/icon.png');

// Androids adaptiva ikon: flutter_launcher_icons lägger själv 16 % marginal på
// förgrunden, så den fullstora icon.png används som förgrund. Bakgrunden =
// plattans färg, så att launcherns mask möter en sömlös platta.
const edge = (70 * 1024 + 512) * 4; // överkanten, innanför rundningen = ren platta
const hex = '#' + [out[edge], out[edge + 1], out[edge + 2]].map((v) => v.toString(16).padStart(2, '0')).join('').toUpperCase();
console.log(`plattans färg ${hex} (adaptive_icon_background i pubspec.yaml)`);

const pi = process.argv.indexOf('--preview');
if (pi > 0) {
  const P = 220, gap = 40;
  const mk1 = await sharp(SRC).resize(P, P).png().toBuffer();
  const mk2 = await sharp(join(OUT, 'icon.png')).resize(P, P).png().toBuffer();
  await sharp({ create: { width: 2 * P + 3 * gap, height: P + 2 * gap, channels: 4, background: { r: 38, g: 40, b: 46, alpha: 1 } } })
    .composite([
      { input: mk1, left: gap, top: gap },
      { input: mk2, left: 2 * gap + P, top: gap },
    ])
    .png()
    .toFile(process.argv[pi + 1]);
  console.log('förhandsbild: ' + process.argv[pi + 1]);
}
