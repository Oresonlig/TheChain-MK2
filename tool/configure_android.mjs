// Körs i CI efter `flutter create --platforms android .` (android/ genereras,
// spåras inte i git under F0). Sätter kanalens applicationId + appnamn och
// kopplar release-signering till miljövariablerna om nyckeln finns.
//
//   node tool/configure_android.mjs dev     → com.oresonlig.thechain.dev, "The Chain DEV"
//   node tool/configure_android.mjs stable  → com.oresonlig.thechain,     "The Chain"
//
// stable = SAMMA paket som MK1-appen → med samma nyckel kommer MK2 som en
// uppdatering av MK1 (se LESSONS_MK1_ANDROID.md §1).
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Arbeta ALLTID i MK2-repots rot, oavsett var skriptet startas. 2026-10-02 kördes
// det av misstag från C:\Resistance och ändrade MK1:s android/ (återställt, aldrig
// pushat). Vakten: kräv ett Flutter-projekt (pubspec.yaml med the_chain).
const REPO = dirname(dirname(fileURLToPath(import.meta.url)));
process.chdir(REPO);
if (!existsSync('pubspec.yaml') || !readFileSync('pubspec.yaml', 'utf8').includes('name: the_chain')) {
  console.error('Vägrar: ' + REPO + ' är inte MK2-projektet');
  process.exit(1);
}

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
// Java-desugaring (krävs av ota_update ≥ 7, självuppdateringen).
if (isKts && !gradle.includes('isCoreLibraryDesugaringEnabled')) {
  if (!/compileOptions\s*\{/.test(gradle)) { console.error('compileOptions block not found'); process.exit(1); }
  gradle = gradle.replace(/compileOptions\s*\{/, 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
  gradle += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
}
writeFileSync(gradlePath, gradle);

// Appnamn
const manifestPath = 'android/app/src/main/AndroidManifest.xml';
let manifest = readFileSync(manifestPath, 'utf8');
if (!/android:label="[^"]*"/.test(manifest)) { console.error('android:label not found'); process.exit(1); }
manifest = manifest.replace(/android:label="[^"]*"/, `android:label="${cfg.label}"`);
// EN instans av appen (som MK1:s Capacitor-manifest). Flutters mall ger
// singleTop + taskAffinity="" → "Öppna" i installationsdialogen efter en
// självuppdatering startade appen i ett NYTT kort, och det gamla startade om
// när man bytte till det (Niklas 2026-10-04, bekräftat med skärmdump).
if (!/android:launchMode="[^"]*"/.test(manifest)) { console.error('android:launchMode not found'); process.exit(1); }
manifest = manifest.replace(/android:launchMode="[^"]*"/, 'android:launchMode="singleTask"');
manifest = manifest.replace(/\s*android:taskAffinity=""/, '');
// Appen (MainActivity) visas ALDRIG över låsskärmen — showWhenLocked gav hela
// appen utan upplåsning (säkerhetshål, Niklas 2026-10-05). Bara larmvyn
// (RestAlarmActivity, nedan) får det.
// Flutters mall ger bara debug-byggen INTERNET — release behöver den för Supabase.
if (!manifest.includes('android.permission.INTERNET')) {
  manifest = manifest.replace(/<application/, '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
}
// Självuppdateringen (ota_update): filprovider så att Androids installations-
// dialog kan läsa den nedladdade APK:n. Installationen bekräftas alltid av
// användaren (ACTION_VIEW) — aldrig tyst (MK1-lärdom: Samsung Auto Blocker).
if (!manifest.includes('OtaUpdateFileProvider')) {
  manifest = manifest.replace(/<\/application>/, `    <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="\${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/filepaths" />
        </provider>
    </application>`);
}
// Vilotimerns larmmotor (tool/android/kotlin, "som klockans larm"): exakt larm
// utan fråga (USE_EXACT_ALARM — ingen butik granskar), notiser, helskärm
// (skärmen tänds), vibration och förgrundstjänst som spelar pipet med
// tillfällig ljudfokus (musiken pausas och fortsätter sedan).
for (const perm of [
  'USE_EXACT_ALARM',
  'USE_FULL_SCREEN_INTENT',
  'POST_NOTIFICATIONS',
  'VIBRATE',
  'FOREGROUND_SERVICE',
  'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
  'WAKE_LOCK',
  // "Visa ovanpå andra appar": larmvyn öppnas även när telefonen används.
  // Användaren slår på den själv. Inför Google Play: se VISION.md (exakta larm,
  // helskärm och den här behöver ses över tillsammans).
  'SYSTEM_ALERT_WINDOW',
]) {
  if (!manifest.includes(`android.permission.${perm}"`)) {
    manifest = manifest.replace(/<application/, `<uses-permission android:name="android.permission.${perm}"/>\n    <application`);
  }
}
if (!manifest.includes('RestAlarmService')) {
  manifest = manifest.replace(/<\/application>/, `    <receiver android:name=".RestAlarmReceiver" android:exported="false" />
        <service
            android:name=".RestAlarmService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />
        <activity
            android:name=".RestAlarmActivity"
            android:exported="false"
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            android:excludeFromRecents="true"
            android:launchMode="singleInstance"
            android:taskAffinity="\${applicationId}.restalarm"
            android:theme="@android:style/Theme.DeviceDefault.NoActionBar" />
    </application>`);
}
writeFileSync(manifestPath, manifest);

// Larmmotorns Kotlin-filer; MainActivity ersätts (samma FlutterActivity + kanalen).
const ktDir = 'android/app/src/main/kotlin/com/oresonlig/the_chain';
mkdirSync(ktDir, { recursive: true });
for (const f of ['MainActivity.kt', 'RestAlarm.kt', 'RestAlarmReceiver.kt', 'RestAlarmService.kt', 'RestAlarmActivity.kt']) {
  copyFileSync(`tool/android/kotlin/${f}`, `${ktDir}/${f}`);
}
mkdirSync('android/app/src/main/res/xml', { recursive: true });
writeFileSync('android/app/src/main/res/xml/filepaths.xml', `<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
`);

// Vilotimerns pipljud (tool/make_beep.mjs). RestAlarmService refererar R.raw.rest_beep,
// så resurskrympningen behåller den.
mkdirSync('android/app/src/main/res/raw', { recursive: true });
copyFileSync('tool/res/raw/rest_beep.wav', 'android/app/src/main/res/raw/rest_beep.wav');

console.log(`Configured ${channel}: ${cfg.appId} "${cfg.label}" · ${signed ? 'release-signed' : 'DEBUG-signed (no keystore secret)'}`);
