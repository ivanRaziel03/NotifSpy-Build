import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifspy/services/theme_service.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = NotificationListenerService();
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await _service.isPermissionGranted();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _permissionGranted
                    ? [AppTheme.spyPurple.withValues(alpha: 0.15), AppTheme.accentCyan.withValues(alpha: 0.08)]
                    : [cs.error.withValues(alpha: 0.15), cs.error.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_permissionGranted ? AppTheme.spyPurple : cs.error).withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    _permissionGranted ? Icons.shield : Icons.shield_outlined,
                    color: _permissionGranted ? AppTheme.spyPurple : cs.error,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _permissionGranted ? 'Listener Active' : 'Listener Disabled',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _permissionGranted
                            ? 'Notifications are being captured'
                            : 'Grant access to start capturing',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!_permissionGranted)
                  FilledButton(
                    onPressed: () async {
                      await _service.openPermissionSettings();
                    },
                    child: const Text('Enable'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance
          Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark Mode'),
              subtitle: Text(themeService.isDarkMode ? 'On' : 'Off'),
              value: themeService.isDarkMode,
              onChanged: (_) => themeService.toggleTheme(),
            ),
          ),
          const SizedBox(height: 24),

          // Data
          Text('Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Captured notifications'),
                  trailing: Text('${_service.totalCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_sweep, color: AppTheme.deletedRed),
                  title: const Text('Deleted / Dismissed'),
                  trailing: Text('${_service.deletedCount}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deletedRed)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: cs.error),
                  title: const Text('Clear all data'),
                  subtitle: const Text('Remove all captured notifications'),
                  onTap: () => _confirmClear(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About
          Text('About', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('NotifSpy'),
                  subtitle: Text('v1.0.0'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  subtitle: Text('All data stays on device. No server, no cloud.', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('This will permanently delete all captured notifications. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await _service.clearAll();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
