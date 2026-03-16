import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifspy/services/hive_service.dart';
import 'package:notifspy/services/theme_service.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/home_screen.dart';
import 'package:notifspy/screens/permission_screen.dart';
import 'package:notifspy/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await HiveService.init();
  } catch (e) {
    debugPrint('[NotifSpy] Hive init error: $e');
  }

  final themeService = ThemeService();
  try {
    await themeService.init();
  } catch (e) {
    debugPrint('[NotifSpy] Theme init error: $e');
  }

  final listenerService = NotificationListenerService();
  try {
    await listenerService.init();
  } catch (e) {
    debugPrint('[NotifSpy] Listener init error: $e');
  }

  bool hasPermission = false;
  try {
    hasPermission = await listenerService.isPermissionGranted();
  } catch (e) {
    debugPrint('[NotifSpy] Permission check error: $e');
  }

  runApp(NotifSpyApp(themeService: themeService, hasPermission: hasPermission));
}

class NotifSpyApp extends StatelessWidget {
  final ThemeService themeService;
  final bool hasPermission;

  const NotifSpyApp({super.key, required this.themeService, required this.hasPermission});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeService,
      child: Consumer<ThemeService>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'NotifSpy',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            home: hasPermission ? const HomeScreen() : const PermissionScreen(),
          );
        },
      ),
    );
  }
}
