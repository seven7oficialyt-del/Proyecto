import glob
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
t = manifest.read_text()

if "xmlns:tools" not in t:
    t = t.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"',
        1,
    )

perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
"""
t = t.replace("<application", perms + "    <application", 1)
t = re.sub(r'android:label="[^"]*"', 'android:label="Sonora"', t)

services = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
    """
t = t.replace("</application>", services + "</application>", 1)
manifest.write_text(t)

for f in glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
    pkg = re.search(r"package\s+([\w.]+)", open(f).read()).group(1)
    with open(f, "w") as fh:
        fh.write(
            f"package {pkg}\n\n"
            "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
            "class MainActivity : AudioServiceActivity()\n"
        )
print("Android listo")
