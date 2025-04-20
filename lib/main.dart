import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pay_notify/screens/splash_screen.dart';
import 'package:pay_notify/services/notification_service.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:pay_notify/services/notification_listener_service.dart';
import 'package:pay_notify/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService.instance.initialize(
    supabaseUrl: 'YOUR_SUPABASE_URL',
    supabaseAnonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  // Initialize local database
  await DatabaseService.instance.init();
  
  // Initialize notification services
  await NotificationService.instance.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NotificationListenerService(),
        ),
        ChangeNotifierProvider(
          create: (_) => SupabaseService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'PayNotify',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}