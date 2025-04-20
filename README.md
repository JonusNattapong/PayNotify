# PayNotify

แอพพลิเคชันสำหรับติดตามการรับเงินผ่านการแจ้งเตือนจากแอพธนาคาร โดยไม่ต้องพึ่งพา Line Notify

## คุณสมบัติ

- 🏦 รองรับธนาคารหลักในประเทศไทย:
  - SCB (ไทยพาณิชย์)
  - KBANK (กสิกรไทย)
  - KTB (กรุงไทย)
  - BBL (กรุงเทพ)
  - TTB (ทหารไทยธนชาต)
  - BAY (กรุงศรี)
  - GSB (ออมสิน)
  - BAAC (ธ.ก.ส.)

- 📱 รองรับทั้ง Android และ iOS:
  - Android: ใช้ Notification Listener Service
  - iOS: ใช้ Notification Service Extension

- 🔔 การแจ้งเตือนอัจฉริยะ:
  - แสดงรายละเอียดการโอนเงินแบบ Rich Notification
  - เสียงแจ้งเตือนที่ปรับแต่งได้
  - สั่นเมื่อได้รับเงิน

- 💡 ฟีเจอร์เพิ่มเติม:
  - ทำงานแบบ Offline ได้
  - เริ่มทำงานอัตโนมัติเมื่อเปิดเครื่อง
  - บันทึกประวัติการรับเงิน
  - ส่งออกรายงานได้

## การติดตั้ง

### Android

1. อนุญาตสิทธิ์การเข้าถึงการแจ้งเตือน
   - ไปที่ การตั้งค่า > การแจ้งเตือน > การเข้าถึงการแจ้งเตือน
   - เปิดสิทธิ์ให้ PayNotify

2. อนุญาตให้ทำงานในพื้นหลัง
   - ไปที่ การตั้งค่า > แอพ > PayNotify > แบตเตอรี่
   - เลือก "ไม่จำกัด" หรือ "อนุญาตพื้นหลัง"

### iOS

1. อนุญาตการแจ้งเตือน
   - เมื่อเปิดแอพครั้งแรกจะมีการขอสิทธิ์
   - หรือไปที่ การตั้งค่า > การแจ้งเตือน > PayNotify

2. ตั้งค่าการแจ้งเตือน
   - เปิด "อนุญาตการแจ้งเตือน"
   - เปิด "เสียง"
   - เปิด "แบนเนอร์"

## การพัฒนา

### ข้อกำหนด

- Flutter SDK 3.x
- Android Studio / XCode
- Android API level 26+ หรือ iOS 13.0+

### การตั้งค่าโปรเจค

1. Clone repository:

```bash
git clone https://github.com/your-username/pay-notify.git
```

2. ติดตั้ง dependencies:

```bash
flutter pub get
```

3. รัน build_runner:

```bash
flutter pub run build_runner build
```

### การ Build

- Android:

```bash
flutter build apk --release
```

- iOS:

```bash
flutter build ios --release
```

## สถาปัตยกรรมแอพพลิเคชัน

### Flutter Core

- **NotificationService**: จัดการการแจ้งเตือนในแอพ
- **DatabaseService**: จัดการฐานข้อมูล SQLite
- **TransactionModel**: โมเดลข้อมูลธุรกรรม
- **FirebaseService**: เชื่อมต่อกับ Firebase (optional)

### Android Components

- **BankNotificationProcessor**: ประมวลผลการแจ้งเตือนด้วย Pattern Matching
- **BankNotificationListenerService**: บริการจับการแจ้งเตือนแบบ Background
- **NotificationListenerPlugin**: สะพานเชื่อมระหว่าง Native และ Flutter
- **BootReceiver**: ระบบเริ่มต้นอัตโนมัติหลังเปิดเครื่อง

### iOS Components

- **NotificationService**: ประมวลผลการแจ้งเตือนใน Extension
- **NotificationContent**: แสดงผล Rich Notification UI
- **BankPatternAnalyzer**: วิเคราะห์รูปแบบข้อความแจ้งเตือน

## การแก้ไขปัญหา

### Android

1. ไม่ได้รับการแจ้งเตือน
   - ตรวจสอบการอนุญาตการเข้าถึงการแจ้งเตือน
   - เปิดสิทธิ์การทำงานพื้นหลัง
   - ตรวจสอบการตั้งค่าการประหยัดแบตเตอรี่
   - ลองรีสตาร์ทแอพและอุปกรณ์

2. แอพหยุดทำงานในพื้นหลัง
   - ปิดการจำกัดการใช้แบตเตอรี่
   - เพิ่มแอพในรายการยกเว้นการประหยัดพลังงาน
   - ตรวจสอบว่าไม่ถูกจำกัดการทำงานพื้นหลัง

### iOS

1. ไม่ได้รับการแจ้งเตือน
   - ตรวจสอบการอนุญาตการแจ้งเตือนในระบบ
   - รีเซ็ตการตั้งค่าการแจ้งเตือนของแอพ
   - ลองติดตั้งแอพใหม่
   - ตรวจสอบการเชื่อมต่อเครือข่าย

2. การแจ้งเตือนล่าช้า
   - ปิดโหมดประหยัดพลังงาน
   - ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
   - ตรวจสอบพื้นที่เก็บข้อมูล

## การอัพเดต Pattern การแจ้งเตือน

เมื่อธนาคารมีการเปลี่ยนแปลงรูปแบบข้อความ:

1. แก้ไขไฟล์ที่เกี่ยวข้อง:
   - Android: `BankNotificationProcessor.java`
   - iOS: `NotificationService.swift`

2. อัพเดต Pattern ใน code:
   - เพิ่มรูปแบบใหม่ใน BANK_PATTERNS
   - ทดสอบกับข้อความตัวอย่าง
   - อัพเดตเวอร์ชันแอพ

## การมีส่วนร่วมพัฒนา

1. Fork repository นี้
2. สร้าง branch ใหม่ (`git checkout -b feature/amazing-feature`)
3. Commit การเปลี่ยนแปลง (`git commit -m 'Add amazing feature'`)
4. Push ไปยัง branch (`git push origin feature/amazing-feature`)
5. เปิด Pull Request

## Roadmap

- [ ] เพิ่มการรองรับธนาคารต่างประเทศ
- [ ] ระบบแจ้งเตือน LINE/Telegram (optional)
- [ ] Dashboard สำหรับวิเคราะห์ข้อมูล
- [ ] ระบบ OCR สำหรับ Screenshot
- [ ] Machine Learning สำหรับปรับปรุง Pattern

## License

MIT License - see [LICENSE](LICENSE)
