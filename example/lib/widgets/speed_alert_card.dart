import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class SpeedAlertCard extends StatelessWidget {
  const SpeedAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚨 Speed Alert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Enable Speed Alert:',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Switch(
                  value: p.isSpeedAlertEnabled,
                  onChanged: (v) => p.toggleSpeedAlert(v)),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Speed violations are announced using native speech synthesis.',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ]),
        ),
      );
    });
  }
}
