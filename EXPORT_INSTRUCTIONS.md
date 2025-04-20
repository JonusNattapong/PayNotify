# คำแนะนำการ Export App PayNotify

## สำหรับ Android

1. เตรียมไฟล์ Keystore:

```bash
keytool -genkey -v -keystore paynotify-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. ตั้งค่าใน `android/app/build.gradle`:

```gradle
android {
    signingConfigs {
        release {
            storeFile file("paynotify-upload-key.jks")
            storePassword "your_password"
            keyAlias "upload"
            keyPassword "your_password"
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

3. สร้าง APK:

```bash
flutter build apk --release
```

4. สร้าง App Bundle (สำหรับ Google Play):

```bash
flutter build appbundle --release
```

ไฟล์จะอยู่ที่:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

## สำหรับ iOS

1. เตรียมบัญชี Developer:

- ต้องมีบัญชี Apple Developer ($99/ปี)
- ตั้งค่า App ID, Certificates และ Profiles ใน developer.apple.com

2. ตั้งค่าใน Xcode:

- เปิด `ios/Runner.xcworkspace`
- เลือก Target Runner > Signing & Capabilities
- เลือก Team และ Bundle Identifier

3. สร้าง Archive:

- ใน Xcode เลือก Product > Archive
- เมื่อเสร็จแล้วจะเปิดหน้า Organizer
- กด Distribute App

4. เลือกวิธีการแจกจ่าย:

- App Store Connect (สำหรับส่ง App Store)
- Development/Ad Hoc (สำหรับทดสอบ)

## วิธีแจกจ่ายแบบอื่น

1. Android:

- ส่งไฟล์ APK ให้ติดตั้งเอง
- อัปโหลดไปยัง Google Play Console

2. iOS:

- ใช้ TestFlight สำหรับทดสอบ
- ส่งไปยัง App Store สำหรับเผยแพร่ทั่วไป

## ข้อควรระวัง

- Android ต้องมีไฟล์ Keystore เก็บไว้อย่างปลอดภัย
- iOS ต้องมีบัญชี Developer ที่ถูกต้อง
- ตรวจสอบให้แน่ใจว่าได้ตั้งค่า Bundle Identifier ไม่ซ้ำใคร
