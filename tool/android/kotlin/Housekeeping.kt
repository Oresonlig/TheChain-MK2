// Städning vid start (Niklas 2026-10-05: "MK1 raderas komplett, inget skräp").
//
// MK2 installeras OVANPÅ MK1-appen (samma paket) — Android byter appen men
// behåller datamappen. MK1 var hemsidan i ett WebView-skal: allt nedan är
// WebView-/Capacitor-data som MK2 aldrig använder (MK2:s data ligger i
// app_flutter/ och shared_prefs/FlutterSharedPreferences.xml, larmets i
// shared_prefs/rest_alarm.xml — rörs inte). Körs EN gång (markör).
//
// Varje start: MK2:s egen självuppdatering (ota_update) lämnar den nedladdade
// APK:n kvar — den har gjort sitt när appen väl startat.
package com.oresonlig.the_chain

import android.content.Context
import java.io.File

object Housekeeping {
    private const val PREFS = "mk2_housekeeping"
    private const val MK1_DONE = "mk1_cleaned_v1"

    fun run(ctx: Context) {
        try {
            removeOldUpdateFiles(ctx)
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(MK1_DONE, false)) {
                removeMk1Leftovers(ctx)
                prefs.edit().putBoolean(MK1_DONE, true).apply()
            }
        } catch (_: Exception) {
            // Städning får aldrig fälla appen; nästa start försöker igen (markören sattes inte).
        }
    }

    /** MK1:s WebView/Capacitor-rester. Bara namngivna mappar och filer — aldrig MK2:s. */
    private fun removeMk1Leftovers(ctx: Context) {
        val data = File(ctx.applicationInfo.dataDir)
        val cache = ctx.cacheDir
        // WebView: lagrad hemsidedata (localStorage, IndexedDB, cookies, service worker) + cache.
        for (name in listOf("app_webview", "app_textures", "app_hws_webview")) File(data, name).deleteRecursively()
        for (name in listOf("WebView", "org.chromium.android_webview", "Default", "Crashpad")) File(cache, name).deleteRecursively()
        // MK1-appens uppdaterare laddade ner hit (AppUpdaterPlugin.java: cache/updates/thechain.apk).
        File(cache, "updates").deleteRecursively()
        // WebViews och Capacitors inställningsfiler — MK2:s egna har andra namn.
        File(data, "shared_prefs").listFiles()?.forEach { f ->
            val n = f.name
            if (n.startsWith("WebView") || n.startsWith("Capacitor") || n.startsWith("org.chromium")) f.delete()
        }
        // Äldre WebView-databaser (WebSQL m.m.). MK2 använder inga databaser.
        File(data, "databases").listFiles()?.forEach { f -> if (f.name.lowercase().startsWith("webview")) f.delete() }
        File(data, "databases").let { if (it.isDirectory && it.list()?.isEmpty() == true) it.delete() }
    }

    /** ota_update laddar ner till files/ota_update/ — kvar efter installationen. */
    private fun removeOldUpdateFiles(ctx: Context) {
        File(ctx.filesDir, "ota_update").listFiles()?.forEach { f -> if (f.name.endsWith(".apk")) f.delete() }
    }
}
