import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

import '../tracking_provider.dart';

class SmartBatteryCard extends StatelessWidget {
  const SmartBatteryCard({super.key});

  Color _profileColor(SmartBatteryProfile p) => switch (p) {
        SmartBatteryProfile.navigation => Colors.blue.shade600,
        SmartBatteryProfile.general => Colors.green.shade600,
        SmartBatteryProfile.batterySaver => Colors.orange.shade700,
      };

  String _profileLabel(SmartBatteryProfile p) => switch (p) {
        SmartBatteryProfile.navigation => '🚗 Navigation (3s / 5m)',
        SmartBatteryProfile.general => '⚡ General (10s / 15m)',
        SmartBatteryProfile.batterySaver => '🔋 Battery Saver (30s / 50m)',
      };

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.battery_saver, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('🔋 Smart Battery (Auto)',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.isTracking
                          ? Colors.green
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        p.isTracking ? 'Active' : 'Inactive',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  p.isTracking
                      ? 'Đang giám sát pin & chuyển động tự động'
                      : 'Sẽ tự động bật khi Start Tracking',
                  style: TextStyle(
                      fontSize: 12,
                      color: p.isTracking
                          ? Colors.black54
                          : Colors.grey.shade600),
                ),
                if (p.isTracking) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color:
                            _profileColor(p.smartBatteryProfile),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.auto_mode,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                          'Profile hiện tại: ${_profileLabel(p.smartBatteryProfile)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                    'Profile ưu tiên khi xe chạy + pin bình thường:',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: p.smartBatteryPreferredPreset,
                  onChanged: (v) =>
                      p.setPreferredBatteryPreset(v!),
                  child: Row(children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Navigation',
                            style: TextStyle(fontSize: 13)),
                        subtitle: const Text('3s / 5m',
                            style: TextStyle(fontSize: 11)),
                        value: 'navigation',
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('General',
                            style: TextStyle(fontSize: 13)),
                        subtitle: const Text('10s / 15m',
                            style: TextStyle(fontSize: 11)),
                        value: 'general',
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ]),
                ),
              ]),
        ),
      );
    });
  }
}
