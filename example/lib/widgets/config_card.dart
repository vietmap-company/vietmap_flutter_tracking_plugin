import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class ConfigCard extends StatelessWidget {
  final TextEditingController intervalController;
  final TextEditingController distanceController;

  const ConfigCard({
    super.key,
    required this.intervalController,
    required this.distanceController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚙️ Configuration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Use Custom Config:',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Switch(
                  value: p.useCustomConfig,
                  onChanged: p.setUseCustomConfig),
            ]),
            if (p.useCustomConfig) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  if (!p.trackingWithDistance) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tracking with Timer:'),
                          Switch(
                            value: p.trackingWithTimer,
                            onChanged: (v) =>
                                p.toggleTrackingWithTimer(v),
                          ),
                        ]),
                    const SizedBox(height: 10),
                  ],
                  if (!p.trackingWithTimer) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tracking with Distance:'),
                          Switch(
                            value: p.trackingWithDistance,
                            onChanged: (v) =>
                                p.toggleTrackingWithDistance(v),
                          ),
                        ]),
                    const SizedBox(height: 10),
                  ],
                  if (p.trackingWithTimer) ...[
                    _ConfigRow(
                        'Interval (ms):',
                        intervalController,
                        (v) => p.setCustomIntervalMs(
                            int.tryParse(v) ?? 8000)),
                    const SizedBox(height: 10),
                  ] else if (p.trackingWithDistance) ...[
                    _ConfigRow(
                        'Distance (m):',
                        distanceController,
                        (v) => p.setCustomDistanceFilter(
                            double.tryParse(v) ?? 10.0)),
                    const SizedBox(height: 10),
                  ],
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Background Mode:'),
                        Switch(
                            value: p.customBackgroundMode,
                            onChanged: p.setCustomBackgroundMode),
                      ]),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                () {
                  if (!p.useCustomConfig)
                    return 'Config: Fitness preset | 10000ms (10s) timer | bg: ✅ | user: ${p.effectiveUserId}';
                  final mode = p.trackingWithTimer
                      ? '⏱ Timer only'
                      : p.trackingWithDistance
                          ? '📏 Distance only'
                          : 'Timer+Distance';
                  return 'Config: $mode | '
                      '${p.activeConfig.intervalMs}ms | '
                      '${p.activeConfig.distanceFilter}m | '
                      'bg: ${p.activeConfig.backgroundMode ? "✅" : "❌"} | '
                      'user: ${p.effectiveUserId}';
                }(),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final void Function(String) onChange;
  const _ConfigRow(this.label, this.ctrl, this.onChange);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 110, child: Text(label)),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: onChange,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    ]);
  }
}
