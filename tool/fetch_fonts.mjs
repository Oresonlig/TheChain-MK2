// Hämtar appens typsnitt (OFL) från Googles officiella fontrepo till assets/fonts/.
// Körs en gång när ett typsnitt läggs till: `node tool/fetch_fonts.mjs`.
// Skriver bara inom TheChain_MK2/assets/fonts/.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(dirname(fileURLToPath(import.meta.url)));
const OUT = join(REPO, 'assets', 'fonts');
mkdirSync(OUT, { recursive: true });

const BASE = 'https://raw.githubusercontent.com/google/fonts/main/ofl/saira/';
const FILES = {
  'Saira[wdth,wght].ttf': 'Saira-Variable.ttf',
  'Saira-Italic[wdth,wght].ttf': 'Saira-Italic-Variable.ttf',
  'OFL.txt': 'Saira-OFL.txt',
};

for (const [src, dst] of Object.entries(FILES)) {
  const url = BASE + encodeURIComponent(src);
  const res = await fetch(url);
  if (!res.ok) { console.error(`FEL ${res.status}: ${url}`); process.exit(1); }
  const buf = Buffer.from(await res.arrayBuffer());
  writeFileSync(join(OUT, dst), buf);
  console.log(`${dst}  ${(buf.length / 1024).toFixed(0)} KB`);
}
