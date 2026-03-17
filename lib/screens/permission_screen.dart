import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/home_screen.dart';
import 'package:notifspy/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  final _listener = NotificationListenerService();
  bool _checking = false;
  bool _hasNotifPermission = false;
  bool _isBatteryOptimized = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final notifGranted = await _listener.isPermissionGranted();
    final batteryOpt = await _listener.isBatteryOptimized();
    if (!mounted) return;
    setState(() {
      _hasNotifPermission = notifGranted;
      _isBatteryOptimized = batteryOpt;
    });
    if (notifGranted && !batteryOpt) {
      _navigateToHome();
    }
  }

  Future<void> _navigateToHome() async {
    if (_checking) return;
    _checking = true;
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
    _checking = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildStepCard(
                context,
                step: 1,
                title: 'Notification Access',
                subtitle: 'Required to capture notifications',
                icon: Icons.notifications_active,
                done: _hasNotifPermission,
                onAction: _listener.openPermissionSettings,
              ),
              const SizedBox(height: 16),
              _buildStepCard(
                context,
                step: 2,
                title: 'Disable Battery Optimization',
                subtitle: 'Prevents Android from killing the listener',
                icon: Icons.battery_alert,
                done: !_isBatteryOptimized,
                onAction: _listener.requestBatteryOptimization,
                enabled: _hasNotifPermission,
              ),
              const SizedBox(height: 32),
              _buildPrivacyNote(cs),
              const SizedBox(height: 24),
              if (_hasNotifPermission && _isBatteryOptimized)
                TextButton(
                  onPressed: _navigateToHome,
                  child: const Text('Skip for now'),
                ),
              if (_hasNotifPermission && !_isBatteryOptimized)
                FilledButton.icon(
                  onPressed: _navigateToHome,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.spyPurple, AppTheme.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.notifications_active,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Setup Required',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete these steps so NotifSpy can reliably capture notifications.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool done,
    required VoidCallback onAction,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final effectiveOpacity = enabled ? 1.0 : 0.4;
    return Opacity(
      opacity: effectiveOpacity,
      child: Card(
        elevation: done ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: done
              ? BorderSide(color: Colors.green.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: enabled && !done ? onAction : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: done
                      ? Colors.green.withValues(alpha: 0.15)
                      : cs.primaryContainer,
                  child: Icon(
                    done ? Icons.check_circle : icon,
                    color: done ? Colors.green : cs.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done ? 'Done' : subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: done
                              ? Colors.green
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!done && enabled)
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: cs.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your data stays on your device. Nothing is sent to any server.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
