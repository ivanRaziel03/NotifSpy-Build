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
  await HiveService.init();

  final themeService = ThemeService();
  await themeService.init();

  final listenerService = NotificationListenerService();
  await listenerService.init();

  final hasPermission = await listenerService.isPermissionGranted();

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
