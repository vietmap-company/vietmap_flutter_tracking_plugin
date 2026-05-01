import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class PermissionSection extends StatelessWidget {
  final VoidCallback onRequest;
  const PermissionSection({super.key, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.hasPermissions) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🔒 Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRequest,
                child: const Text('Request Location Permissions')),
          ]),
        ),
      );
    });
  }
}
