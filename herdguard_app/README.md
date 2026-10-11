# HerdGuard - Flutter app

Futuristic live livestock radar: tap animals, see health, get theft and
fever alerts. Android, iOS and web from one codebase.

## 1. Create the project (inside your CropMedic folder)
    flutter create herdguard
    cd herdguard

Copy from this folder into the new project, replacing what's there:
- pubspec.yaml      -> herdguard/pubspec.yaml
- lib/ (all files)  -> herdguard/lib/

    flutter pub get

## 2. Start the backend first
See the backend README (python -m uvicorn main:app --reload --host 0.0.0.0).

## 3. Run
    flutter run -d chrome

## Try this
- Tap an animal dot to see its temperature, activity and battery
- Tap the flask icon (top right): "Simulate theft", then watch one dot run
  out of the fence, the fence turn red and an alert pop up
- "Simulate fever" and watch the temperature climb
- Alerts tab: tap an alert to jump to the animal, tap ACK to acknowledge
- Pinch to zoom the radar

## Phone testing
In lib/api.dart set baseUrl to http://YOUR-PC-IP:8000 (same Wi-Fi), and add
android:usesCleartextTraffic="true" to the <application> tag in
android/app/src/main/AndroidManifest.xml, plus the INTERNET permission:
    <uses-permission android:name="android.permission.INTERNET"/>
