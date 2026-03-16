import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/widgets/notification_tile.dart';
import 'package:notifspy/widgets/empty_state.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _service = NotificationListenerService();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _service.onCleared.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _service.getFavorites();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const EmptyState(
              icon: Icons.star_border,
              title: 'No favorites yet',
              subtitle: 'Long-press a notification to bookmark it',
            )
          : ListView.builder(
              itemCount: favorites.length,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, index) {
                final notif = favorites[index];
                return NotificationTile(
                  notification: notif,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: notif)),
                  ),
                  onDismiss: () async {
                    await _service.toggleFavorite(notif.id);
                    setState(() {});
                  },
                );
              },
            ),
    );
  }
}
