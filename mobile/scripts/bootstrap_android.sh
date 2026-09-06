#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required." >&2
  exit 1
fi

if [ ! -d android ]; then
  TMP_DIR="$(mktemp -d)"
  flutter create --platforms=android --org com.syncroom --project-name syncroom "$TMP_DIR/syncroom"
  cp -R "$TMP_DIR/syncroom/android" ./android
  cp "$TMP_DIR/syncroom/.metadata" ./.metadata
  rm -rf "$TMP_DIR"
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
cat > "$MANIFEST" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:label="SyncRoom"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:mimeType="video/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="video/*" />
            </intent-filter>
        </activity>

        <service
            android:name="de.julianassmann.flutter_background.IsolateHolderService"
            android:exported="false"
            android:foregroundServiceType="mediaProjection|microphone|dataSync"
            tools:replace="android:foregroundServiceType" />

        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
XML

KOTLIN_DIR="android/app/src/main/kotlin/com/syncroom/syncroom"
mkdir -p "$KOTLIN_DIR"
cat > "$KOTLIN_DIR/MainActivity.kt" <<'KOTLIN'
package com.syncroom.syncroom

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mediaChannelName = "syncroom/open_media"
    private var mediaChannel: MethodChannel? = null
    private var pendingVideoUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingVideoUri = extractVideoUri(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
        mediaChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialVideo" -> {
                    result.success(pendingVideoUri)
                    pendingVideoUri = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = extractVideoUri(intent)
        if (uri != null) {
            pendingVideoUri = uri
            mediaChannel?.invokeMethod("videoOpened", uri)
        }
    }

    private fun extractVideoUri(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("video/") == true) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_STREAM)
                    }
                } else null
            }
            else -> null
        }
        if (uri != null && uri.scheme == "content") {
            try {
                val flags = intent.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                contentResolver.takePersistableUriPermission(uri, flags and Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {
            }
        }
        return uri?.toString()
    }
}
KOTLIN

BUILD_FILE="android/app/build.gradle.kts"
if [ -f "$BUILD_FILE" ]; then
  python3 - "$BUILD_FILE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
p.write_text(s)
PY
fi

flutter pub get
dart run flutter_launcher_icons

# Keep analyzer enabled, but do not fail the APK build on informational lints
# such as deprecations / prefer_const. Real analyzer errors still fail.
flutter analyze --no-fatal-infos
