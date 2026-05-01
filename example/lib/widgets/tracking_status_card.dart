import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tracking Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                  p.isTracking
                      ? Icons.location_on
                      : Icons.location_off,
                  color:
                      p.isTracking ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(p.isTracking
                  ? 'Tracking Active'
                  : 'Tracking Inactive'),
            ]),
            if (p.trackingStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                  'Duration: ${p.trackingStatus!.duration.inSeconds}s'),
              if (p.trackingStatus!.lastUpdateTime != null)
                Text('Last Update: ${p.trackingStatus!.lastUpdateTime}'),
            ],
            const SizedBox(height: 8),
            Text('Locations Recorded: ${p.locationHistory.length}'),
          ]),
        ),
      );
    });
  }
}
