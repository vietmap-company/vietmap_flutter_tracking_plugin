import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class LocationHistoryCard extends StatelessWidget {
  const LocationHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.locationHistory.isEmpty) return const SizedBox.shrink();
      return Column(children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '📝 Location History (${p.locationHistory.length})',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...p.locationHistory.reversed.take(5).map((loc) {
                final kmh = loc.speed * 3.6;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)} | '
                      '${kmh.toStringAsFixed(1)} km/h | '
                      '${loc.dateTime.hour}:${loc.dateTime.minute.toString().padLeft(2, '0')}:${loc.dateTime.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }),
              if (p.totalDistance > 0) ...[
                const SizedBox(height: 8),
                Text(
                    'Total Distance: ${(p.totalDistance / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                    textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      ]);
    });
  }
}
