import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:pay_notify/services/notification_service.dart';
import 'package:pay_notify/services/notification_listener_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lineTokenController = TextEditingController();
  String _appVersion = '';
  bool _isLoading = false;
  
  // Sound settings
  bool _soundEnabled = true;
  double _soundVolume = 0.5;
  String _selectedSound = 'cash_register.mp3';
  
  final List<Map<String, dynamic>> _availableSounds = [
    {'name': 'Cash Register', 'file': 'cash_register.mp3'},
    {'name': 'Coin', 'file': 'coin.mp3'},
    {'name': 'Money Transfer', 'file': 'money_transfer.mp3'},
    {'name': 'Success', 'file': 'success.mp3'},
    {'name': 'Payment Received', 'file': 'payment_received.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getAppVersion();
  }

  @override
  void dispose() {
    _lineTokenController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    final notificationService = NotificationService.instance;
    
    setState(() {
      _soundEnabled = notificationService.soundEnabled;
      _soundVolume = notificationService.soundVolume;
      
      final soundPath = notificationService.selectedSoundPath;
      final soundFile = soundPath.split('/').last;
      _selectedSound = soundFile;
    });
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }
  
  void _playSelectedSound() {
    NotificationService.instance.playNotificationSound();
  }
  
  Future<void> _saveSoundSettings() async {
    final notificationService = NotificationService.instance;
    
    await notificationService.saveSoundPreferences(
      enabled: _soundEnabled,
      soundPath: 'assets/sounds/$_selectedSound',
      volume: _soundVolume,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการตั้งค่าเสียงแล้ว'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationListenerService>(context);
    final supabaseService = Provider.of<SupabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'การแจ้งเตือน',
            children: [
              ListTile(
                title: const Text('การเข้าถึงการแจ้งเตือน'),
                subtitle: Text(
                  notificationService.isServiceRunning
                      ? 'เปิดใช้งานอยู่'
                      : 'ปิดอยู่ - เปิดเพื่อรับการแจ้งเตือนจากแอปธนาคาร',
                ),
                leading: const Icon(Icons.notifications),
                trailing: Switch(
                  value: notificationService.isServiceRunning,
                  onChanged: (_) {
                    if (notificationService.isServiceRunning) {
                      notificationService.stopService();
                    } else {
                      notificationService.openNotificationSettings();
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          _buildSection(
            title: 'เสียงแจ้งเตือน',
            children: [
              ListTile(
                title: const Text('เสียงแจ้งเตือน'),
                subtitle: const Text('เปิด/ปิดการใช้งานเสียงแจ้งเตือน'),
                leading: const Icon(Icons.volume_up),
                trailing: Switch(
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                  },
                ),
              ),
              if (_soundEnabled) ...[
                const Divider(),
                ListTile(
                  title: const Text('ระดับความดัง'),
                  subtitle: Slider(
                    value: _soundVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(_soundVolume * 100).round()}%',
                    onChanged: (value) {
                      setState(() {
                        _soundVolume = value;
                      });
                    },
                  ),
                  leading: const Icon(Icons.volume_down),
                ),
                const Divider(),
                ListTile(
                  title: const Text('เลือกเสียงแจ้งเตือน'),
                  subtitle: DropdownButton<String>(
                    value: _selectedSound,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSound = newValue;
                        });
                      }
                    },
                    items: _availableSounds.map<DropdownMenuItem<String>>((sound) {
                      return DropdownMenuItem<String>(
                        value: sound['file'],
                        child: Text(sound['name']),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _playSelectedSound,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ทดลองเสียงแจ้งเตือน'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _saveSoundSettings,
                    child: const Text('บันทึกการตั้งค่าเสียง'),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          _buildSection(
            title: 'การเชื่อมต่อ',
            children: [
              ListTile(
                title: const Text('Supabase Status'),
                subtitle: Text(
                  supabaseService.isInitialized
                      ? 'เชื่อมต่อแล้ว'
                      : 'ไม่ได้เชื่อมต่อ',
                ),
                leading: Icon(
                  supabaseService.isInitialized
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                ),
              ),
              if (supabaseService.currentUser != null) ...[
                const Divider(),
                ListTile(
                  title: const Text('User ID'),
                  subtitle: Text(
                    supabaseService.currentUser!.id.substring(0, 10) + '...',
                  ),
                  leading: const Icon(Icons.badge),
                ),
              ],
              const Divider(),
              ListTile(
                title: const Text('LINE Notify'),
                subtitle: const Text('ส่งการแจ้งเตือนไปยัง LINE เมื่อมีเงินเข้า'),
                leading: const Icon(Icons.message),
                onTap: () => _configureLineNotify(context),
              ),
              const Divider(),
              ListTile(
                title: const Text('รีเซ็ตการเชื่อมต่อ Supabase'),
                subtitle: const Text('ล้างข้อมูลการเชื่อมต่อทั้งหมด'),
                leading: const Icon(Icons.refresh),
                onTap: () => _resetSupabaseConnection(context),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          _buildSection(
            title: 'เกี่ยวกับ',
            children: [
              ListTile(
                title: const Text('เวอร์ชัน'),
                subtitle: Text(_appVersion),
                leading: const Icon(Icons.info),
              ),
              const Divider(),
              ListTile(
                title: const Text('แนะนำ PayNotify'),
                subtitle: const Text('แชร์แอปพลิเคชันให้กับเพื่อน'),
                leading: const Icon(Icons.share),
                onTap: _shareApp,
              ),
              const Divider(),
              ListTile(
                title: const Text('ติดต่อซัพพอร์ต'),
                subtitle: const Text('ส่งอีเมลเพื่อขอความช่วยเหลือ'),
                leading: const Icon(Icons.mail),
                onTap: _contactSupport,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                await supabaseService.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ออกจากระบบสำเร็จ'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('ออกจากระบบ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _configureLineNotify(BuildContext context) async {
    // Show dialog to input LINE Notify token
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งค่า LINE Notify'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ป้อน LINE Notify Token เพื่อรับการแจ้งเตือนเมื่อมีเงินเข้าบัญชี',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lineTokenController,
              decoration: const InputDecoration(
                labelText: 'LINE Notify Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _launchLineNotifyWebsite(),
              child: const Text('สร้าง LINE Notify Token'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _saveLineNotifyToken(context),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLineNotifyToken(BuildContext context) async {
    if (_lineTokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาป้อน LINE Notify Token')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      await supabaseService.configureLineNotify(_lineTokenController.text);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ตั้งค่า LINE Notify สำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchLineNotifyWebsite() async {
    const url = 'https://notify-bot.line.me/en/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _resetSupabaseConnection(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการรีเซ็ต'),
        content: const Text(
          'คุณต้องการรีเซ็ตการเชื่อมต่อ Supabase ใช่หรือไม่? การกระทำนี้จะไม่ลบข้อมูล แต่จะล้างการตั้งค่าการเชื่อมต่อปัจจุบัน',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('รีเซ็ต'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabaseService = Provider.of<SupabaseService>(context, listen: false);
        await supabaseService.signOut();
        await Future.delayed(const Duration(seconds: 1));
        await supabaseService.signInAnonymously();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('รีเซ็ตการเชื่อมต่อสำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
          );
        }
      }
    }
  }

  void _shareApp() {
    final String shareText = '''
PayNotify - แอปแจ้งเตือนเงินเข้าแบบเรียลไทม์

ติดตามการโอนเงินจากทุกธนาคารในแอปเดียว สำหรับร้านค้าออนไลน์และฟรีแลนซ์

ดาวน์โหลดได้ที่: [ลิงค์แอปของคุณ]
''';

    // In a real app, you'd use the Share plugin to share the text
    // For now, just copy to clipboard
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('คัดลอกข้อความสำหรับแชร์แล้ว'),
      ),
    );
  }

  void _contactSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@paynotify.app',
      queryParameters: {
        'subject': 'PayNotify Support Request',
        'body': 'App Version: $_appVersion\n\nPlease describe your issue:\n',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถเปิดแอปอีเมลได้'),
          ),
        );
      }
    }
  }
}