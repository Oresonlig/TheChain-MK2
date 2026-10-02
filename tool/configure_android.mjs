// Körs i CI efter `flutter create --platforms android .` (android/ genereras,
// spåras inte i git under F0). Sätter kanalens applicationId + appnamn och
// kopplar release-signering till miljövariablerna om nyckeln finns.
//
//   node tool/configure_android.mjs dev     → com.oresonlig.thechain.dev, "The Chain DEV"
//   node tool/configure_android.mjs stable  → com.oresonlig.thechain,     "The Chain"
//
// stable = SAMMA paket som MK1-appen → med samma nyckel kommer MK2 som en
// uppdatering av MK1 (se LESSONS_MK1_ANDROID.md §1).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const CHANNELS = {
  dev:    { appId: 'com.oresonlig.thechain.dev', label: 'The Chain DEV' },
  stable: { appId: 'com.oresonlig.thechain',     label: 'The Chain' },
};
const channel = process.argv[2];
const cfg = CHANNELS[channel];
if (!cfg) { console.error('Usage: configure_android.mjs dev|stable'); process.exit(1); }

const kts = 'android/app/build.gradle.kts';
const groovy = 'android/app/build.gradle';
const gradlePath = existsSync(kts) ? kts : groovy;
const isKts = gradlePath === kts;
let gradle = readFileSync(gradlePath, 'utf8');

// applicationId
const idRe = isKts ? /applicationId\s*=\s*"[^"]+"/ : /applicationId\s+["'][^"']+["']/;
if (!idRe.test(gradle)) { console.error('applicationId not found in ' + gradlePath); process.exit(1); }
gradle = gradle.replace(idRe, isKts ? `applicationId = "${cfg.appId}"` : `applicationId "${cfg.appId}"`);

// Signering: bara om CI har avkodat nyckeln (ANDROID_KEYSTORE_PATH satt).
const signed = !!process.env.ANDROID_KEYSTORE_PATH;
if (signed) {
  const block = isKts
    ? `    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

`
    : `    signingConfigs {
        release {
            storeFile file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias System.getenv("ANDROID_KEY_ALIAS")
            keyPassword System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

`;
  if (!/^\s*buildTypes\s*\{/m.test(gradle)) { console.error('buildTypes block not found'); process.exit(1); }
  gradle = gradle.replace(/^(\s*)buildTypes\s*\{/m, block + '$1buildTypes {');
  const dbgRe = isKts ? /signingConfigs\.getByName\("debug"\)/ : /signingConfigs\.debug/;
  if (!dbgRe.test(gradle)) { console.error('release signingConfig line not found'); process.exit(1); }
  gradle = gradle.replace(dbgRe, isKts ? 'signingConfigs.getByName("release")' : 'signingConfigs.release');
}
writeFileSync(gradlePath, gradle);

// Appnamn
const manifestPath = 'android/app/src/main/AndroidManifest.xml';
let manifest = readFileSync(manifestPath, 'utf8');
if (!/android:label="[^"]*"/.test(manifest)) { console.error('android:label not found'); process.exit(1); }
manifest = manifest.replace(/android:label="[^"]*"/, `android:label="${cfg.label}"`);
writeFileSync(manifestPath, manifest);

console.log(`Configured ${channel}: ${cfg.appId} "${cfg.label}" · ${signed ? 'release-signed' : 'DEBUG-signed (no keystore secret)'}`);
