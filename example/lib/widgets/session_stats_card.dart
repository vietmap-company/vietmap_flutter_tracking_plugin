import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class SessionStatsCard extends StatelessWidget {
  const SessionStatsCard({super.key});

  String _fmt(Duration d) {
    final h = d.inHours,
        m = d.inMinutes.remainder(60),
        s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.sessionStartTime == null && p.totalDistance == 0) {
        return const SizedBox.shrink();
      }
      final dur = p.sessionStartTime != null
          ? DateTime.now().difference(p.sessionStartTime!)
          : Duration.zero;
      return Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📊 Session Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatItem('Duration', _fmt(dur)),
              _StatItem('Distance',
                  '${(p.totalDistance / 1000).toStringAsFixed(2)} km'),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatItem('Avg Speed',
                  '${(p.averageSpeed * 3.6).toStringAsFixed(2)} km/h'),
              _StatItem('Points', '${p.locationHistory.length}'),
            ]),
          ]),
        ),
      );
    });
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ]);
}
