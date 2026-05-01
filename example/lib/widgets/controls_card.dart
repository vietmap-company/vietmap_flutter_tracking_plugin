import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class ControlsCard extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onGetLocation;
  final VoidCallback onUpdateConfig;
  final VoidCallback onRefreshStatus;
  final VoidCallback onClearHistory;

  const ControlsCard({
    super.key,
    required this.onStart,
    required this.onStop,
    required this.onGetLocation,
    required this.onUpdateConfig,
    required this.onRefreshStatus,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final isBusy = p.isStartingTracking || p.isStoppingTracking;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🎮 Controls',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (isBusy) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      p.isStartingTracking
                          ? '⏳ SDK is starting tracking...'
                          : '⏳ SDK is stopping tracking...',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (!p.hasPermissions ||
                              p.isTracking ||
                              p.isStartingTracking ||
                              p.isStoppingTracking)
                          ? null
                          : onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: p.isStartingTracking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('🚀 Start Tracking'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (!p.isTracking ||
                              p.isStartingTracking ||
                              p.isStoppingTracking)
                          ? null
                          : onStop,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey),
                      child: p.isStoppingTracking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('🛑 Stop Tracking'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !p.hasPermissions ? null : onGetLocation,
                      style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey),
                      child: const Text('📍 Get Location'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !p.isTracking ? null : onUpdateConfig,
                      style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey),
                      child: const Text('⚙️ Update Config'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: ElevatedButton(
                          onPressed: onRefreshStatus,
                          child: const Text('🔄 Refresh Status'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onClearHistory,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white),
                      child: const Text('🗑️ Clear History'),
                    ),
                  ),
                ]),
              ]),
        ),
      );
    });
  }
}
