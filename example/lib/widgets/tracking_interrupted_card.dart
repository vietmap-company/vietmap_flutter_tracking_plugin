import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

/// Shows the latest tracking-interrupted event from the native SDK (background
/// GPS stall / location unavailable / provider off / permission lost) and its
/// recovery, plus a short history. Also exposes the notification enable toggle.
class TrackingInterruptedCard extends StatelessWidget {
  const TrackingInterruptedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final last = p.lastInterruptedEvent;
      final interrupted = last != null && !last.recovered;
      return Card(
        color: interrupted ? Colors.orange.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  interrupted ? Icons.gps_off : Icons.gps_fixed,
                  color: interrupted ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('⚠️ Tracking Interrupted',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              if (last == null)
                const Text('Chưa có sự kiện. Đang tracking bình thường.',
                    style: TextStyle(color: Colors.grey))
              else
                Text(
                  last.recovered
                      ? '✅ Recovered (${last.reason})'
                      : '⚠️ ${last.reason} · bg=${last.isInBackground} · '
                          '${last.secondsSinceLastFix}s since last fix\n'
                          '→ Hãy Stop rồi Start lại tracking.',
                  style: TextStyle(
                    color: last.recovered ? Colors.green : Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Local notification'),
                const Spacer(),
                Switch(
                  value: p.interruptedNotificationEnabled,
                  onChanged: (v) => p.setInterruptedNotificationEnabled(v),
                ),
              ]),
              if (p.interruptedHistory.isNotEmpty) ...[
                const Divider(),
                const Text('Lịch sử gần đây:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...p.interruptedHistory.take(5).map(
                      (e) => Text(
                        '• ${e.recovered ? "recovered" : e.reason}'
                        ' (bg=${e.isInBackground}, ${e.secondsSinceLastFix}s)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
