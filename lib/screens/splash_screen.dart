import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:pay_notify/screens/home_screen.dart';
import 'package:pay_notify/services/notification_listener_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Delay for showing splash screen (3 seconds)
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // Get the notification listener service
    final notificationService = Provider.of<NotificationListenerService>(context, listen: false);
    
    // Check permissions and navigate to home
    if (await _checkNotificationPermissions(notificationService)) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }

  Future<bool> _checkNotificationPermissions(NotificationListenerService service) async {
    if (!service.isServiceRunning) {
      // Request permission to access notifications
      await service.requestNotificationPermission();
      
      // Show notification access request dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('เปิดการเข้าถึงการแจ้งเตือน'),
            content: const Text(
              'แอพพลิเคชัน PayNotify ต้องการเข้าถึงการแจ้งเตือนเพื่อตรวจจับการแจ้งเตือนการโอนเงินจากแอปธนาคาร กรุณาเปิดการเข้าถึงการแจ้งเตือนในการตั้งค่า'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  service.openNotificationSettings();
                },
                child: const Text('ตั้งค่า'),
              ),
            ],
          ),
        );
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 100,
            ),
            const SizedBox(height: 24),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 32.0,
                fontFamily: 'Kanit',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              child: AnimatedTextKit(
                animatedTexts: [
                  FadeAnimatedText(
                    'PayNotify',
                    duration: const Duration(seconds: 2),
                  ),
                ],
                totalRepeatCount: 1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'แจ้งเตือนเงินเข้าแบบเรียลไทม์',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}