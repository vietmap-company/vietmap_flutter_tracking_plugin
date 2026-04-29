import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking.dart';

import 'tracking_provider.dart';

// SLC support is temporarily disabled until the SDK exposes the updated iOS API.
// const slcChannel = MethodChannel('vietmap_tracking_plugin/slc');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('=======Example App Bootstrap=======');
  await dotenv.load(fileName: '.env');
  final provider = TrackingProvider();
  await provider.initNotifications();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MyApp(),
    ),
  );
  debugPrint('=======End Example App Bootstrap=======');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vietmap Tracking Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TrackingDemoPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page — stateful only for TextEditingControllers + email-edit toggle
// ─────────────────────────────────────────────────────────────────────────────

class TrackingDemoPage extends StatefulWidget {
  const TrackingDemoPage({super.key});

  @override
  State<TrackingDemoPage> createState() => _TrackingDemoPageState();
}

class _TrackingDemoPageState extends State<TrackingDemoPage> {
  final _emailController = TextEditingController();
  final _customIntervalController = TextEditingController(text: '5000');
  final _customDistanceController = TextEditingController(text: '10');
  final _maxRecordsController = TextEditingController(text: '5000');
  final _maxDbSizeMbController = TextEditingController(text: '50');
  final _batchSizeController = TextEditingController(text: '50');

  bool _emailEditing = false;

  @override
  void initState() {
    super.initState();
    debugPrint('=======Bind Tracking Demo Page=======');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<TrackingProvider>();
      await p.init();
      _emailController.text = p.userEmail;
      // SLC hooks are temporarily disabled.
      // await p.checkSLCWakeUp(slcChannel);
      // p.listenSLCEvents(slcChannel);
      debugPrint('=======End Bind Tracking Demo Page=======');
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _customIntervalController.dispose();
    _customDistanceController.dispose();
    _maxRecordsController.dispose();
    _maxDbSizeMbController.dispose();
    _batchSizeController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color bg = Colors.blue}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  Future<void> _handleRequestPermissions() async {
    try {
      final r = await context.read<TrackingProvider>().requestPermissions();
      _snack(
        r.granted ? '✅ Location permissions granted' : '❌ Permissions denied',
        bg: r.granted ? Colors.green : Colors.red,
      );
    } catch (e) {
      _snack('❌ Error: $e', bg: Colors.red);
    }
  }

  Future<void> _startTracking() async {
    final p = context.read<TrackingProvider>();
    if (p.isStartingTracking || p.isStoppingTracking) return;
    if (!p.hasPermissions) {
      _snack('⚠️ Location permissions required', bg: Colors.orange);
      return;
    }
    try {
      final ok = await p.startTracking();
      _snack(ok ? '✅ Tracking started' : '⚠️ Could not start tracking',
          bg: ok ? Colors.green : Colors.orange);
    } catch (e) {
      _snack('❌ Failed: $e', bg: Colors.red);
    }
  }

  Future<void> _stopTracking() async {
    final p = context.read<TrackingProvider>();
    if (p.isStartingTracking || p.isStoppingTracking) return;
    try {
      final ok = await p.stopTracking();
      _snack(ok ? '✅ Tracking stopped' : '⚠️ Stop result unclear', bg: Colors.orange);
    } catch (e) {
      _snack('❌ Error: $e', bg: Colors.red);
    }
  }

  Future<void> _handleUpdateConfig() async {
    final p = context.read<TrackingProvider>();
    if (!p.isTracking) {
      _snack('⚠️ Start tracking first', bg: Colors.orange);
      return;
    }
    try {
      final ok = await p.updateConfig();
      if (ok) _snack('✅ Configuration updated', bg: Colors.green);
    } catch (e) {
      _snack('❌ Failed to update config', bg: Colors.red);
    }
  }

  Future<void> _getCurrentLocation() async {
    final p = context.read<TrackingProvider>();
    if (!p.hasPermissions) {
      _snack('⚠️ Permissions not granted', bg: Colors.orange);
      return;
    }
    try {
      final loc = await p.getCurrentLocation();
      _snack('📍 ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
          bg: Colors.blue);
    } catch (e) {
      _snack('❌ $e', bg: Colors.red);
    }
  }

  Future<void> _refreshStatus() async {
    await context.read<TrackingProvider>().refreshStatus();
    _snack('🔄 Status refreshed', bg: Colors.blue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛰️ GPS Tracking Demo'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(),
            const SizedBox(height: 16),
            _SdkCoverageCard(),
            const SizedBox(height: 16),
            _UserIdentityCard(
              emailController: _emailController,
              isEditing: _emailEditing,
              onToggleEdit: () => setState(() => _emailEditing = !_emailEditing),
              onSave: () async {
                await context.read<TrackingProvider>().saveEmail(_emailController.text);
                setState(() => _emailEditing = false);
                _snack('✅ Email saved', bg: Colors.green);
              },
            ),
            const SizedBox(height: 16),
            _PermissionSection(onRequest: _handleRequestPermissions),
            const SizedBox(height: 16),
            _SpeedAlertCard(),
            const SizedBox(height: 16),
            _ConfigCard(
              intervalController: _customIntervalController,
              distanceController: _customDistanceController,
            ),
            const SizedBox(height: 16),
            _SessionStatsCard(),
            const SizedBox(height: 16),
            _TrackingStatusCard(),
            const SizedBox(height: 16),
            _LocationCard(),
            const SizedBox(height: 16),
            _FakeGpsCard(),
            const SizedBox(height: 16),
            _ControlsCard(
              onStart: _startTracking,
              onStop: _stopTracking,
              onGetLocation: _getCurrentLocation,
              onUpdateConfig: _handleUpdateConfig,
              onRefreshStatus: _refreshStatus,
              onClearHistory: () => context.read<TrackingProvider>().clearHistory(),
            ),
            _LocationHistoryCard(),
            // SLC UI is temporarily disabled until native support is updated.
            // if (Platform.isIOS) _SLCCard(),
            const SizedBox(height: 16),
            _SmartBatteryCard(),
            const SizedBox(height: 16),
            _CacheCard(
              maxRecordsController: _maxRecordsController,
              maxDbSizeMbController: _maxDbSizeMbController,
              batchSizeController: _batchSizeController,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets  — each uses Consumer<TrackingProvider> for granular rebuilds
// =============================================================================

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Text('Status:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(p.isTracking ? '🟢 Active' : '🔴 Inactive',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: p.isTracking ? Colors.green : Colors.red,
                  )),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Permissions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(p.hasPermissions ? '✅ Granted' : '❌ Denied',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: p.hasPermissions ? Colors.green : Colors.red,
                  )),
            ]),
          ]),
        ),
      );
    });
  }
}

class _SdkCoverageCard extends StatelessWidget {
  const _SdkCoverageCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧭 SDK Coverage Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Demo này mô tả trực tiếp các tính năng sẵn có của Vietmap Tracking SDK.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            _SdkCapabilityRow(
              icon: Icons.gps_fixed,
              title: 'Realtime Tracking',
              detail: 'Theo dõi GPS theo interval/distance và cập nhật trạng thái live.',
            ),
            _SdkCapabilityRow(
              icon: Icons.location_off,
              title: 'Fake GPS Policies',
              detail: 'skip, warn, stopTracking, logToServer từ native SDK.',
            ),
            _SdkCapabilityRow(
              icon: Icons.battery_saver,
              title: 'Smart Battery',
              detail: 'Tự chuyển profile theo pin/chuyển động để cân bằng độ chính xác và tiêu thụ pin.',
            ),
            _SdkCapabilityRow(
              icon: Icons.cloud_upload,
              title: 'Offline Cache + Sync',
              detail: 'Lưu SQLite khi offline và upload batch khi mạng hồi phục.',
            ),
            _SdkCapabilityRow(
              icon: Icons.notifications_active,
              title: 'Alerts + Local Notification',
              detail: 'Speed alert native + fake GPS notification khi policy warn.',
            ),
            // if (Platform.isIOS)
            //   _SdkCapabilityRow(
            //     icon: Icons.directions_walk,
            //     title: 'SLC Wake-up (iOS)',
            //     detail: 'Significant Location Change để wake app sau force-kill.',
            //   ),
          ],
        ),
      ),
    );
  }
}

class _SdkCapabilityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _SdkCapabilityRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.indigo.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 1),
                Text(detail, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Identity ─────────────────────────────────────────────────────────────

class _UserIdentityCard extends StatelessWidget {
  final TextEditingController emailController;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;

  const _UserIdentityCard({
    required this.emailController,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👤 User Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Email được dùng làm User ID để theo dõi tracking của từng người.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (isEditing) ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSave(),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleEdit,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
              ]),
            ] else ...[
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      p.userEmail.isNotEmpty ? p.userEmail : '(chưa nhập email)',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: p.userEmail.isNotEmpty ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('User ID: ${p.effectiveUserId}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    Text('Device ID: ${p.deviceId}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.edit), onPressed: onToggleEdit, tooltip: 'Chỉnh sửa email'),
              ]),
            ],
          ]),
        ),
      );
    });
  }
}

// ── Permission ────────────────────────────────────────────────────────────────

class _PermissionSection extends StatelessWidget {
  final VoidCallback onRequest;
  const _PermissionSection({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.hasPermissions) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🔒 Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRequest, child: const Text('Request Location Permissions')),
          ]),
        ),
      );
    });
  }
}

// ── Fake GPS Card ─────────────────────────────────────────────────────────────

class _FakeGpsCard extends StatelessWidget {
  static const _policies = [
    (value: 'skip',         label: 'Skip',  icon: Icons.block,         color: Colors.grey),
    (value: 'warn',         label: 'Warn',  icon: Icons.notifications, color: Colors.orange),
    (value: 'stopTracking', label: 'Stop',  icon: Icons.stop_circle,   color: Colors.red),
    (value: 'logToServer',  label: 'Log',   icon: Icons.cloud_upload,  color: Colors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final last = p.lastFakeGpsEvent;
      return Card(
        color: last != null ? Colors.red.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─ Header ──────────────────────────────────────────────────
            Row(children: [
              Icon(
                last != null ? Icons.location_off : Icons.gps_fixed,
                color: last != null ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('🕵️ Fake GPS Detection',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (p.fakeGpsHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: p.clearFakeGpsHistory,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ]),

            // ─ Platform note ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                Platform.isIOS
                    ? 'ℹ️ iOS 15+ only — CLLocationSourceInformation'
                    : 'ℹ️ Android — isMock() (API 31+) / isFromMockProvider()',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚠️  Fake GPS detected!',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(
                    'lat=${last.lat.toStringAsFixed(6)}  lng=${last.lng.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  if (last.reason != null)
                    Text('reason: ${last.reason}',
                        style: const TextStyle(fontSize: 11, color: Colors.red)),
                  Text(
                    'at ${DateTime.fromMillisecondsSinceEpoch((last.timestamp * 1000).toInt()).toLocal().toString().substring(0, 19)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],

            // ─ Policy selector ──────────────────────────────────────────
            const Text('Policy:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final pol in _policies)
                  ChoiceChip(
                    avatar: Icon(pol.icon, size: 14,
                        color: p.fakeGpsPolicy == pol.value ? Colors.white : pol.color),
                    label: Text(pol.label, style: TextStyle(
                      fontSize: 12,
                      color: p.fakeGpsPolicy == pol.value ? Colors.white : Colors.black87,
                    )),
                    selected: p.fakeGpsPolicy == pol.value,
                    selectedColor: pol.color,
                    onSelected: (_) => _selectPolicy(context, p, pol.value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Allow Mock Location:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: p.allowMockLocation,
                  onChanged: (v) => p.setAllowMockLocation(v),
                  activeColor: Colors.purple,
                ),
              ),
            ]),
            const Text(
              'If enabled, simulated locations will be processed as real points and bypass policies.',
              style: TextStyle(fontSize: 11, color: Colors.purple),
            ),
            const SizedBox(height: 6),
            Text(
              _policyDescription(p.fakeGpsPolicy),
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),

            // ─ Detection history ────────────────────────────────────────
            if (p.fakeGpsHistory.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('History (latest 20):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  itemCount: p.fakeGpsHistory.length,
                  itemBuilder: (_, i) {
                    final e = p.fakeGpsHistory[i];
                    final time = DateTime.fromMillisecondsSinceEpoch(
                        (e.timestamp * 1000).toInt()).toLocal();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '[${time.toString().substring(11, 19)}] '
                        '${e.lat.toStringAsFixed(5)}, ${e.lng.toStringAsFixed(5)}'
                        '${e.reason != null ? " (${e.reason})" : ""}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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

  static String _policyDescription(String policy) => switch (policy) {
    'skip'         => 'Silent: ignored by SDK. onFakeGpsDetected stream still fires for app logic.',
    'warn'         => 'Warn: native shows local notification (debounced 30s). Needs notification permission.',
    'stopTracking' => 'Stop: SDK auto-stops tracking at native layer; UI syncs immediately from fake GPS callback.',
    'logToServer'  => 'Log: saved to DB with is_fake=1, uploaded with X-Fake-GPS: true header.',
    _              => '',
  };

  /// Handle policy chip tap.
  /// For "warn": directly trigger OS notification permission popup if not yet granted.
  /// No custom dialog — let the OS handle the UX.
  static Future<void> _selectPolicy(
    BuildContext context,
    TrackingProvider p,
    String policy,
  ) async {
    if (policy != FakeGpsPolicy.warn) {
      await p.setFakeGpsPolicy(policy);
      return;
    }

    // Already granted — just apply
    final alreadyGranted = await p.hasNotificationPermission();
    if (alreadyGranted) {
      await p.setFakeGpsPolicy(policy);
      return;
    }

    // On Android, check for permanentlyDenied so we go straight to Settings
    // without burning the one-time OS popup call.
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

    // Trigger OS permission popup (FLN on iOS, permission_handler on Android)
    final granted = await p.requestNotificationPermission();
    if (!context.mounted) return;

    if (granted) {
      await p.setFakeGpsPolicy(policy);
    } else {
      // Permission denied — offer shortcut to Settings
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

// ── Speed Alert ───────────────────────────────────────────────────────────────

class _SpeedAlertCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🚨 Speed Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Enable Speed Alert:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Switch(value: p.isSpeedAlertEnabled, onChanged: (v) => p.toggleSpeedAlert(v)),
            ]),
            const SizedBox(height: 8),
            const Text('Speed violations are announced using native speech synthesis.',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ]),
        ),
      );
    });
  }
}

// ── Config ────────────────────────────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  final TextEditingController intervalController;
  final TextEditingController distanceController;
  const _ConfigCard({required this.intervalController, required this.distanceController});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚙️ Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Use Custom Config:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Switch(value: p.useCustomConfig, onChanged: p.setUseCustomConfig),
            ]),
            if (p.useCustomConfig) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  // Khi Distance đang ON → ẩn hàng Timer, và ngược lại
                  if (!p.trackingWithDistance) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Tracking with Timer:'),
                      Switch(
                        value: p.trackingWithTimer,
                        onChanged: (v) => p.toggleTrackingWithTimer(v),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  if (!p.trackingWithTimer) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Tracking with Distance:'),
                      Switch(
                        value: p.trackingWithDistance,
                        onChanged: (v) => p.toggleTrackingWithDistance(v),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],

                  if (p.trackingWithTimer) ...[
                    _ConfigRow('Interval (ms):', intervalController, (v) => p.setCustomIntervalMs(int.tryParse(v) ?? 5000)),
                    const SizedBox(height: 10),
                  ] else if (p.trackingWithDistance) ...[
                    _ConfigRow('Distance (m):', distanceController, (v) => p.setCustomDistanceFilter(double.tryParse(v) ?? 10.0)),
                    const SizedBox(height: 10),
                  ],
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Background Mode:'),
                    Switch(value: p.customBackgroundMode, onChanged: p.setCustomBackgroundMode),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(
                () {
                  if (!p.useCustomConfig) return 'Config: Preset | 5000ms | 10m | bg: ✅ | user: ${p.effectiveUserId}';
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
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    ]);
  }
}

// ── Session Stats ─────────────────────────────────────────────────────────────

class _SessionStatsCard extends StatelessWidget {
  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.sessionStartTime == null && p.totalDistance == 0) return const SizedBox.shrink();
      final dur = p.sessionStartTime != null ? DateTime.now().difference(p.sessionStartTime!) : Duration.zero;
      return Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📊 Session Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatItem('Duration', _fmt(dur)),
              _StatItem('Distance', '${(p.totalDistance / 1000).toStringAsFixed(2)} km'),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatItem('Avg Speed', '${(p.averageSpeed * 3.6).toStringAsFixed(2)} km/h'),
              _StatItem('Points', '${p.locationHistory.length}'),
            ]),
          ]),
        ),
      );
    });
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]);
}

// ── Tracking Status ───────────────────────────────────────────────────────────

class _TrackingStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tracking Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(p.isTracking ? Icons.location_on : Icons.location_off,
                  color: p.isTracking ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(p.isTracking ? 'Tracking Active' : 'Tracking Inactive'),
            ]),
            if (p.trackingStatus != null) ...[
              const SizedBox(height: 8),
              Text('Duration: ${p.trackingStatus!.duration.inSeconds}s'),
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

// ── Location Card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final loc = p.currentLocation;
      if (loc == null) {
        return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No location data yet')));
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📍 Current Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

// ── Controls ──────────────────────────────────────────────────────────────────

class _ControlsCard extends StatelessWidget {
  final VoidCallback onStart, onStop, onGetLocation, onUpdateConfig, onRefreshStatus, onClearHistory;
  const _ControlsCard({
    required this.onStart, required this.onStop,
    required this.onGetLocation, required this.onUpdateConfig,
    required this.onRefreshStatus, required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final isBusy = p.isStartingTracking || p.isStoppingTracking;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('🎮 Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (isBusy) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  p.isStartingTracking
                      ? '⏳ SDK is starting tracking...'
                      : '⏳ SDK is stopping tracking...',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (!p.hasPermissions || p.isTracking || p.isStartingTracking || p.isStoppingTracking)
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
                  onPressed: (!p.isTracking || p.isStartingTracking || p.isStoppingTracking)
                      ? null
                      : onStop,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey),
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
                  style: ElevatedButton.styleFrom(disabledBackgroundColor: Colors.grey),
                  child: const Text('📍 Get Location'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: !p.isTracking ? null : onUpdateConfig,
                  style: ElevatedButton.styleFrom(disabledBackgroundColor: Colors.grey),
                  child: const Text('⚙️ Update Config'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: onRefreshStatus, child: const Text('🔄 Refresh Status'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onClearHistory,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
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

// ── Location History ──────────────────────────────────────────────────────────

class _LocationHistoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      if (p.locationHistory.isEmpty) return const SizedBox.shrink();
      return Column(children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📝 Location History (${p.locationHistory.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...p.locationHistory.reversed.take(5).map((loc) {
                final kmh = loc.speed * 3.6;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
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
                Text('Total Distance: ${(p.totalDistance / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      ]);
    });
  }
}

/*
// ── SLC (iOS only) ────────────────────────────────────────────────────────────

class _SLCCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Column(children: [
        const SizedBox(height: 16),
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('📡 SLC Monitoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.slcEnabled ? Colors.orange : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(p.slcEnabled ? '🔴 Enabled' : '⚪ Disabled',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
              if (p.isSLCAwakeFromKill) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100, border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✅ App was awakened by iOS (Significant Location Change after force-kill)',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => p.slcEnabled ? p.stopSLC(slcChannel) : p.startSLC(slcChannel),
                    icon: Icon(p.slcEnabled ? Icons.pause : Icons.play_arrow),
                    label: Text(p.slcEnabled ? 'Stop SLC' : 'Start SLC'),
                    style: ElevatedButton.styleFrom(backgroundColor: p.slcEnabled ? Colors.red : Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => p.refreshSLCLogs(slcChannel),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Logs'),
                  ),
                ),
              ]),
              if (p.slcLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text('SLC Logs (${p.slcLogs.length})'),
                  children: [
                    Container(
                      height: 200, color: Colors.grey.shade100,
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: p.slcLogs.map((log) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(log, style: const TextStyle(fontSize: 11, fontFamily: 'Courier'), maxLines: 2, overflow: TextOverflow.ellipsis),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ]);
    });
  }
}
*/

// ── Smart Battery ─────────────────────────────────────────────────────────────

class _SmartBatteryCard extends StatelessWidget {
  Color _profileColor(SmartBatteryProfile p) => switch (p) {
    SmartBatteryProfile.navigation   => Colors.blue.shade600,
    SmartBatteryProfile.general      => Colors.green.shade600,
    SmartBatteryProfile.batterySaver => Colors.orange.shade700,
  };

  String _profileLabel(SmartBatteryProfile p) => switch (p) {
    SmartBatteryProfile.navigation   => '🚗 Navigation (3s / 5m)',
    SmartBatteryProfile.general      => '⚡ General (10s / 15m)',
    SmartBatteryProfile.batterySaver => '🔋 Battery Saver (30s / 50m)',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.battery_saver, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(child: Text('🔋 Smart Battery (Auto)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isTracking ? Colors.green : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(p.isTracking ? 'Active' : 'Inactive',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              p.isTracking ? 'Đang giám sát pin & chuyển động tự động' : 'Sẽ tự động bật khi Start Tracking',
              style: TextStyle(fontSize: 12, color: p.isTracking ? Colors.black54 : Colors.grey.shade600),
            ),
            if (p.isTracking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _profileColor(p.smartBatteryProfile), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.auto_mode, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Profile hiện tại: ${_profileLabel(p.smartBatteryProfile)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 10),
            ],
            const Text('Profile ưu tiên khi xe chạy + pin bình thường:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: p.smartBatteryPreferredPreset,
              onChanged: (v) => p.setPreferredBatteryPreset(v!),
              child: Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Navigation', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('3s / 5m', style: TextStyle(fontSize: 11)),
                    value: 'navigation',
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('General', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('10s / 15m', style: TextStyle(fontSize: 11)),
                    value: 'general',
                    dense: true, contentPadding: EdgeInsets.zero,
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



// ── Cache Card ────────────────────────────────────────────────────────────────

class _CacheCard extends StatelessWidget {
  final TextEditingController maxRecordsController;
  final TextEditingController maxDbSizeMbController;
  final TextEditingController batchSizeController;

  const _CacheCard({
    required this.maxRecordsController,
    required this.maxDbSizeMbController,
    required this.batchSizeController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final dbLabel = p.dbSizeBytes < 1024 * 1024
          ? '${(p.dbSizeBytes / 1024).toStringAsFixed(1)} KB'
          : '${(p.dbSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

      return Card(
        color: Colors.teal.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('💾 Cache & Offline Storage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => p.refreshCacheStats(), tooltip: 'Refresh stats'),
            ]),
            const SizedBox(height: 8),
            // Live-updating — rebuilt automatically on every location write (max 1x/2s)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [
                  Text('${p.cachedLocationsCount}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Pending records', style: TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                Column(children: [
                  Text(dbLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('DB size', style: TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await p.manualUploadCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✅ Cache uploaded' : '⚠️ Upload failed'),
                        backgroundColor: ok ? Colors.green : Colors.orange,
                      ));
                    }
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Cache'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await p.clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✅ Cache cleared' : '⚠️ Failed'),
                        backgroundColor: ok ? Colors.green : Colors.orange,
                      ));
                    }
                  },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear Cache'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Configure DB Limits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              initiallyExpanded: p.cacheConfigExpanded,
              onExpansionChanged: p.setCacheConfigExpanded,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Call before startTracking(). Pass 0 to keep SDK defaults.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                _CacheLimitRow('Max records', maxRecordsController, 'records', (v) => p.setMaxRecords(int.tryParse(v) ?? 5000)),
                const SizedBox(height: 8),
                _CacheLimitRow('Max DB size', maxDbSizeMbController, 'MB', (v) => p.setMaxDbSizeMb(int.tryParse(v) ?? 50)),
                const SizedBox(height: 8),
                _CacheLimitRow('Batch size', batchSizeController, 'records/batch', (v) => p.setBatchSize(int.tryParse(v) ?? 50)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final ok = await p.applyConfigureCacheLimits();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✅ Cache limits applied' : '⚠️ Failed'),
                        backgroundColor: ok ? Colors.green : Colors.orange,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(40)),
                  child: const Text('Apply Limits'),
                ),
              ],
            ),
          ]),
        ),
      );
    });
  }
}

class _CacheLimitRow extends StatelessWidget {
  final String label, unit;
  final TextEditingController ctrl;
  final void Function(String) onChange;
  const _CacheLimitRow(this.label, this.ctrl, this.unit, this.onChange);

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: onChange,
            decoration: InputDecoration(
              suffixText: unit, border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ]);
}

// =============================================================================
// VietmapTrackingPlugin Demo
// Demonstrates the simplified API:  configureTracking / configureAlertAPI /
// configureZoneNetworkV2 + onSpeedSignChanged / onTtsText streams.
// =============================================================================

class TrackingPluginDemoPage extends StatefulWidget {
  const TrackingPluginDemoPage({super.key});

  @override
  State<TrackingPluginDemoPage> createState() => _TrackingPluginDemoPageState();
}

class _TrackingPluginDemoPageState extends State<TrackingPluginDemoPage> {
  final _plugin = VietmapTrackingPlugin.instance;

  bool   _isConfigured  = false;
  bool   _isTracking    = false;
  bool   _isAlertActive = false;
  String _status        = 'Idle';
  String _ttsText       = '—';
  int?   _speedLimit;
  Uint8List? _signImage;

  // Stream subscriptions
  late final _locationSub  = _plugin.onLocationUpdate.listen(_onLocation);
  late final _statusSub    = _plugin.onTrackingStatus.listen(_onStatus);
  late final _speedSignSub = _plugin.onSpeedSignChanged.listen(_onSpeedSign);
  late final _ttsSub       = _plugin.onTtsText.listen(_onTts);

  @override
  void dispose() {
    _locationSub.cancel();
    _statusSub.cancel();
    _speedSignSub.cancel();
    _ttsSub.cancel();
    super.dispose();
  }

  void _onLocation(LocationUpdateEvent loc) {
    setState(() => _status =
        'lat=${loc.latitude.toStringAsFixed(5)} '
        'lng=${loc.longitude.toStringAsFixed(5)} '
        '${(loc.speed * 3.6).toStringAsFixed(1)} km/h');
  }

  void _onStatus(TrackingStatusEvent ev) {
    setState(() => _isTracking = ev.isTracking);
  }

  void _onSpeedSign(SpeedSignEvent ev) {
    setState(() {
      _speedLimit = ev.speedLimit;
      _signImage  = ev.imageBytes;
    });
  }

  void _onTts(String text) {
    setState(() => _ttsText = text);
  }

  Future<void> _configure() async {
    try {
      const trackingBaseUrl = 'https://staging.fleetwork.vn/api/v1';
      // 1. Configure tracking SDK
      await _plugin.configureTracking(
        apiKey: dotenv.env['key-stg'] ?? '',
        baseUrl: trackingBaseUrl,
        authMode: useQueryParamAuth ? AuthMode.queryParam : AuthMode.header,
        autoUpload: true,
      );

      // 2. Configure speed-alert API (url defaults to Vietmap's endpoint)
      await _plugin.configureAlertAPI(
        apiKey: dotenv.env['ALERT_API_KEY'] ?? '',
        apiID: dotenv.env['ALERT_API_ID'] ?? '',
      );

      // 3. Optionally switch to zone-network-v2 endpoint
      // await _plugin.configureZoneNetworkV2('https://zone-v2.vietmap.vn');

      setState(() {
        _isConfigured = true;
        _status = 'Configured ✅';
      });
    } on PlatformException catch (e) {
      setState(() => _status = 'Configure error: ${e.message}');
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _plugin.stopTracking();
    } else {
      await _plugin.startTracking(
        backgroundMode: true,
        intervalMs:     5000,
        userId:         'demo_user',
      );
    }
    final active = await _plugin.isTrackingActive();
    setState(() => _isTracking = active);
  }

  Future<void> _toggleAlert() async {
    if (_isAlertActive) {
      await _plugin.stopAlert();
    } else {
      await _plugin.startAlert();
    }
    final active = await _plugin.isAlertActive();
    setState(() => _isAlertActive = active);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VietmapTrackingPlugin Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status, style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 12),

            // Configure
            ElevatedButton(
              onPressed: _isConfigured ? null : _configure,
              child: const Text('1. Configure SDK'),
            ),
            const SizedBox(height: 8),

            // Tracking
            ElevatedButton(
              onPressed: _isConfigured ? _toggleTracking : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(_isTracking ? 'Stop Tracking' : '2. Start Tracking'),
            ),
            const SizedBox(height: 8),

            // Alert
            ElevatedButton(
              onPressed: _isConfigured ? _toggleAlert : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAlertActive ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(_isAlertActive ? 'Stop Alert' : '3. Start Alert'),
            ),
            const SizedBox(height: 20),

            // Speed-sign display
            const Text('Speed Sign:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_signImage != null)
                  Image.memory(_signImage!, width: 80, height: 80)
                else
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.speed, size: 40, color: Colors.grey),
                  ),
                const SizedBox(width: 12),
                Text(
                  _speedLimit != null ? '$_speedLimit km/h' : '—',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TTS
            const Text('TTS Alert:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_ttsText, style: const TextStyle(fontSize: 16, color: Colors.deepOrange)),
          ],
        ),
      ),
    );
  }
}
