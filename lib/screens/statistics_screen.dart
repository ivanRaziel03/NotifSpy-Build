import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationListenerService();
    final all = service.getAllNotifications();
    final cs = Theme.of(context).colorScheme;

    // Per-app counts
    final appCounts = <String, int>{};
    final appNames = <String, String>{};
    final hourCounts = List.filled(24, 0);
    final dayCounts = <String, int>{};
    int deletedTotal = 0;
    int ghostTotal = 0;
    int mediaTotal = 0;

    for (final n in all) {
      appCounts[n.packageName] = (appCounts[n.packageName] ?? 0) + 1;
      appNames[n.packageName] = n.appName;
      hourCounts[n.timestamp.hour]++;
      final dayKey = DateFormat('MM/dd').format(n.timestamp);
      dayCounts[dayKey] = (dayCounts[dayKey] ?? 0) + 1;
      if (n.isRemoved) deletedTotal++;
      if (n.isGhostDelete) ghostTotal++;
      if (n.mediaType != null) mediaTotal++;
    }

    final sortedApps = appCounts.keys.toList()
      ..sort((a, b) => appCounts[b]!.compareTo(appCounts[a]!));

    // Last 7 days activity
    final now = DateTime.now();
    final last7 = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('MM/dd').format(d);
      last7[key] = dayCounts[key] ?? 0;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: all.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No data yet', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(
                  children: [
                    _summaryCard('Total', '${all.length}', Icons.notifications, AppTheme.spyPurple, cs),
                    const SizedBox(width: 10),
                    _summaryCard('Deleted', '$deletedTotal', Icons.delete_sweep, AppTheme.deletedRed, cs),
                    const SizedBox(width: 10),
                    _summaryCard('Ghost', '$ghostTotal', Icons.visibility_off, Colors.orange, cs),
                    const SizedBox(width: 10),
                    _summaryCard('Media', '$mediaTotal', Icons.perm_media, AppTheme.accentCyan, cs),
                  ],
                ),
                const SizedBox(height: 24),

                // 7-day activity chart
                _sectionTitle('Last 7 Days Activity', cs),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (last7.values.fold<int>(0, (a, b) => a > b ? a : b) * 1.2).ceilToDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()}',
                              TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = last7.keys.toList();
                              if (value.toInt() >= keys.length) return const SizedBox.shrink();
                              final label = keys[value.toInt()].substring(3); // just day
                              return Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: last7.entries.toList().asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value.toDouble(),
                              color: AppTheme.spyPurple,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Peak hours
                _sectionTitle('Peak Hours', cs),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 4,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}h', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(24, (i) => FlSpot(i.toDouble(), hourCounts[i].toDouble())),
                          isCurved: true,
                          color: AppTheme.accentCyan,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Top apps pie chart
                _sectionTitle('Top Apps', cs),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: sortedApps.take(6).toList().asMap().entries.map((entry) {
                              final pkg = entry.value;
                              final count = appCounts[pkg]!;
                              final pct = (count / all.length * 100);
                              return PieChartSectionData(
                                value: count.toDouble(),
                                title: '${pct.toStringAsFixed(0)}%',
                                color: _pieColor(entry.key),
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedApps.take(6).toList().asMap().entries.map((entry) {
                          final name = appNames[entry.value] ?? entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: _pieColor(entry.key), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 6),
                                Text(name.length > 14 ? '${name.substring(0, 12)}..' : name, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // All apps breakdown
                _sectionTitle('All Apps', cs),
                const SizedBox(height: 8),
                ...sortedApps.map((pkg) {
                  final name = appNames[pkg] ?? pkg;
                  final count = appCounts[pkg]!;
                  final pct = count / all.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 100, child: Text(name.length > 12 ? '${name.substring(0, 10)}..' : name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: AppTheme.spyPurple,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 36, child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.end)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface));
  }

  Color _pieColor(int index) {
    const colors = [AppTheme.spyPurple, AppTheme.whatsAppGreen, AppTheme.telegramBlue, Colors.orange, AppTheme.deletedRed, AppTheme.accentCyan];
    return colors[index % colors.length];
  }
}
