#!/usr/bin/env python3
"""Adds Shah Brothers' platform settings to the folders made by `flutter create`.

- Android: internet + Bluetooth permissions, app label, launcher icons
- iOS: Bluetooth / local-network usage strings, display name, iOS 13 minimum, app icons
Idempotent: running it twice changes nothing the second time.
"""
import os
import plistlib
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets", "branding")


def android():
    manifest = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(manifest):
        print("  (no Android project, skipped)")
        return
    xml = open(manifest, encoding="utf-8").read()
    perms = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>',
        '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>',
        '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>',
        '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>',
    ]
    missing = [p for p in perms if re.search(r'android:name="([^"]+)"', p).group(1) not in xml]
    if missing:
        xml = xml.replace("<application", "\n    ".join(missing) + "\n    <application", 1)
    xml = re.sub(r'android:label="[^"]*"', 'android:label="Shah Brothers"', xml, count=1)
    open(manifest, "w", encoding="utf-8").write(xml)
    print(f"  Android manifest: {len(missing)} permission(s) added")

    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
        target = os.path.join(res, f"mipmap-{density}")
        if os.path.isdir(target):
            shutil.copyfile(os.path.join(BRAND, f"android-{density}.png"), os.path.join(target, "ic_launcher.png"))
    print("  Android launcher icons updated")

    # minSdk 21+ is needed by the Bluetooth printer plugin.
    for gradle in ["build.gradle.kts", "build.gradle"]:
        path = os.path.join(ROOT, "android", "app", gradle)
        if os.path.exists(path):
            g = open(path, encoding="utf-8").read()
            g2 = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 21)", g) \
                if gradle.endswith(".kts") else re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion Math.max(flutter.minSdkVersion, 21)", g)
            if g2 != g:
                open(path, "w", encoding="utf-8").write(g2)
                print(f"  {gradle}: minSdk set to at least 21")
            break


def ios():
    plist_path = os.path.join(ROOT, "ios", "Runner", "Info.plist")
    if not os.path.exists(plist_path):
        print("  (no iOS project, skipped)")
        return
    with open(plist_path, "rb") as f:
        plist = plistlib.load(f)
    plist["CFBundleDisplayName"] = "Shah Brothers"
    plist["CFBundleName"] = "Shah Brothers"
    plist.setdefault("NSBluetoothAlwaysUsageDescription", "Shah Brothers uses Bluetooth to print receipts on your thermal printer.")
    plist.setdefault("NSBluetoothPeripheralUsageDescription", "Shah Brothers uses Bluetooth to print receipts on your thermal printer.")
    plist.setdefault("NSLocalNetworkUsageDescription", "Shah Brothers connects to Wi-Fi receipt printers on your local network.")
    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f)
    print("  Info.plist: name and usage descriptions set")

    podfile = os.path.join(ROOT, "ios", "Podfile")
    if os.path.exists(podfile):
        p = open(podfile, encoding="utf-8").read()
        p2 = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '13.0'", p, count=1, flags=re.M)
        if p2 != p:
            open(podfile, "w", encoding="utf-8").write(p2)
            print("  Podfile: iOS 13.0 minimum")

    icons = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(icons):
        n = 0
        for name in os.listdir(os.path.join(BRAND, "ios")):
            if os.path.exists(os.path.join(icons, name)):
                shutil.copyfile(os.path.join(BRAND, "ios", name), os.path.join(icons, name))
                n += 1
        print(f"  iOS app icons updated ({n})")


if __name__ == "__main__":
    android()
    ios()
