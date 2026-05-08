import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tracking_provider.dart';
import 'widgets/cache_card.dart';
import 'widgets/config_card.dart';
import 'widgets/controls_card.dart';
import 'widgets/fake_gps_card.dart';
import 'widgets/header_card.dart';
import 'widgets/location_card.dart';
import 'widgets/location_history_card.dart';
import 'widgets/permission_section.dart';
import 'widgets/session_stats_card.dart';
import 'widgets/smart_battery_card.dart';
import 'widgets/speed_alert_card.dart';
import 'widgets/tracking_status_card.dart';
import 'widgets/user_identity_card.dart';

// SLC support is temporarily disabled until the SDK exposes the updated iOS API.
// const slcChannel = MethodChannel('vietmap_tracking_plugin/slc');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('=======Example App Bootstrap=======');
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
      // Initialize SDK automatically — replace 'your-api-key' with your key.
      // Contact Vietmap to get an API key.
      await p.configureSdk(
        //'943e44ad84e91c34f780f28f7c084c53cd4ddff1361b01a7', // Required: replace with your actual API key
        '897f2377cc9b557c5356dea337a158b69505ff0a051dc2e7',
        baseURL: 'https://staging.fleetwork.vn/api/v1', // Optional: only if using a custom server
      );
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
    if (!p.isSdkConfigured) {
      _snack('⚠️ Initialize SDK first', bg: Colors.orange);
      return;
    }
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
            const HeaderCard(),
            const SizedBox(height: 16),
            PermissionSection(onRequest: _handleRequestPermissions),
            const SizedBox(height: 16),
                        ControlsCard(
              onStart: _startTracking,
              onStop: _stopTracking,
              onGetLocation: _getCurrentLocation,
              onUpdateConfig: _handleUpdateConfig,
              onRefreshStatus: _refreshStatus,
              onClearHistory: () => context.read<TrackingProvider>().clearHistory(),
            ),
            const LocationHistoryCard(),
            // SLC UI is temporarily disabled until native support is updated.
            // if (Platform.isIOS) _SLCCard(),
            const SizedBox(height: 16),
            UserIdentityCard(
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

            const SpeedAlertCard(),
            const SizedBox(height: 16),
            ConfigCard(
              intervalController: _customIntervalController,
              distanceController: _customDistanceController,
            ),
            const SizedBox(height: 16),
            const SessionStatsCard(),
            const SizedBox(height: 16),
            const TrackingStatusCard(),
            const SizedBox(height: 16),
            const LocationCard(),
            const SizedBox(height: 16),
            const FakeGpsCard(),
            const SizedBox(height: 16),
            const SmartBatteryCard(),
            const SizedBox(height: 16),
            CacheCard(
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

