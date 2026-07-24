import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

import '../tracking_provider.dart';

class FakeGpsCard extends StatelessWidget {
  static const _policies = [
    (
      value: 'skip',
      label: 'Skip',
      icon: Icons.block,
      color: Colors.grey
    ),
    (
      value: 'warn',
      label: 'Warn',
      icon: Icons.notifications,
      color: Colors.orange
    ),
    (
      value: 'stopTracking',
      label: 'Stop',
      icon: Icons.stop_circle,
      color: Colors.red
    ),
    (
      value: 'logToServer',
      label: 'Log',
      icon: Icons.cloud_upload,
      color: Colors.blue
    ),
  ];

  const FakeGpsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final last = p.lastFakeGpsEvent;
      return Card(
        color: last != null ? Colors.red.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─ Header ──────────────────────────────────────────────────
            Row(children: [
              Icon(
                last != null ? Icons.location_off : Icons.gps_fixed,
                color: last != null ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('🕵️ Fake GPS Detection',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (p.fakeGpsHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: p.clearFakeGpsHistory,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label:
                      const Text('Clear', style: TextStyle(fontSize: 12)),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ]),

            // ─ Platform note ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                Platform.isIOS
                    ? 'ℹ️ iOS 15+ only — CLLocationSourceInformation'
                    : 'ℹ️ Android — isMock() (API 31+) / isFromMockProvider()',
                style:
                    const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),

            // ─ Live alert banner ────────────────────────────────────────
            if (last != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️  Fake GPS detected!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                      const SizedBox(height: 4),
                      Text(
                        'lat=${last.lat.toStringAsFixed(6)}  lng=${last.lng.toStringAsFixed(6)}',
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                      ),
                      if (last.reason != null)
                        Text('reason: ${last.reason}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red)),
                      Text(
                        'at ${DateTime.fromMillisecondsSinceEpoch((last.timestamp * 1000).toInt()).toLocal().toString().substring(0, 19)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ]),
              ),
              const SizedBox(height: 8),
            ],

            // ─ Policy selector ──────────────────────────────────────────
            const Text('Policy:',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final pol in _policies)
                  ChoiceChip(
                    avatar: Icon(pol.icon,
                        size: 14,
                        color: p.fakeGpsPolicy == pol.value
                            ? Colors.white
                            : pol.color),
                    label: Text(pol.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.fakeGpsPolicy == pol.value
                              ? Colors.white
                              : Colors.black87,
                        )),
                    selected: p.fakeGpsPolicy == pol.value,
                    selectedColor: pol.color,
                    onSelected: p.useCustomConfig
                        ? (_) => _selectPolicy(context, p, pol.value)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!p.useCustomConfig)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  '⚠️ Bật "Use Custom Config" để cấu hình policy và detection.',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Allow Mock Location:',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const Text(
                        'OFF → detection active, policy applied',
                        style: TextStyle(fontSize: 10, color: Colors.purple),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: p.allowMockLocation,
                      onChanged: p.useCustomConfig
                          ? (v) => p.setAllowMockLocation(v)
                          : null,
                      activeColor: Colors.purple,
                    ),
                  ),
                ]),
            if (p.fakeGpsHistory.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('History (latest 20):',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 8),
                  itemCount: p.fakeGpsHistory.length,
                  itemBuilder: (_, i) {
                    final e = p.fakeGpsHistory[i];
                    final time =
                        DateTime.fromMillisecondsSinceEpoch(
                                (e.timestamp * 1000).toInt())
                            .toLocal();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '[${time.toString().substring(11, 19)}] '
                        '${e.lat.toStringAsFixed(5)}, ${e.lng.toStringAsFixed(5)}'
                        '${e.reason != null ? " (${e.reason})" : ""}',
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ]),
        ),
      );
    });
  }


  /// Handle policy chip tap.
  /// For "warn": directly trigger OS notification permission popup if not yet granted.
  static Future<void> _selectPolicy(
    BuildContext context,
    TrackingProvider p,
    String policy,
  ) async {
    if (policy != FakeGpsPolicy.warn) {
      await p.setFakeGpsPolicy(policy);
      // skip = pass-through (no detection); any other policy = detection ON
      p.setAllowMockLocation(policy == FakeGpsPolicy.skip);
      return;
    }

    // Already granted — just apply
    final alreadyGranted = await p.hasNotificationPermission();
    if (alreadyGranted) {
      await p.setFakeGpsPolicy(policy);
      p.setAllowMockLocation(false); // detection ON
      return;
    }

    // On Android, check for permanentlyDenied so we go straight to Settings
    if (!Platform.isIOS) {
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification permission permanently denied'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }
    }

    // Trigger OS permission popup
    final granted = await p.requestNotificationPermission();
    if (!context.mounted) return;

    if (granted) {
      await p.setFakeGpsPolicy(policy);
      p.setAllowMockLocation(false); // detection ON
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification permission denied'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }
}
