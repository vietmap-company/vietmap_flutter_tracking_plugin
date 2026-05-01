import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class LocationCard extends StatelessWidget {
  const LocationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final loc = p.currentLocation;
      if (loc == null) {
        return const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No location data yet')));
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📍 Current Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Latitude: ${loc.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${loc.longitude.toStringAsFixed(6)}'),
            Text('Altitude: ${loc.altitude.toStringAsFixed(2)}m'),
            Text('Accuracy: ${loc.accuracy.toStringAsFixed(2)}m'),
            Text('Speed: ${(loc.speed * 3.6).toStringAsFixed(2)} km/h'),
            Text('Bearing: ${loc.heading.toStringAsFixed(2)}°'),
            Text('Time: ${loc.dateTime}'),
          ]),
        ),
      );
    });
  }
}
