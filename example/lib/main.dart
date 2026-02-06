import 'package:flutter/material.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';
import 'dart:async';
import 'dart:math' show sqrt, asin;

void main() {
  runApp(const MyApp());
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

class TrackingDemoPage extends StatefulWidget {
  const TrackingDemoPage({super.key});

  @override
  State<TrackingDemoPage> createState() => _TrackingDemoPageState();
}

class _TrackingDemoPageState extends State<TrackingDemoPage> {
  final _controller = VietmapTrackingController.instance;

  bool _isTracking = false;
  bool _hasPermissions = false;
  bool _isSpeedAlertEnabled = false;
  LocationData? _currentLocation;
  TrackingStatus? _trackingStatus;

  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<TrackingStatus>? _statusSubscription;

  final List<LocationData> _locationHistory = [];

  // Session tracking
  DateTime? _sessionStartTime;
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;

  // Custom config state
  bool _useCustomConfig = false;
  final _customIntervalController = TextEditingController(text: '5000');
  final _customDistanceController = TextEditingController(text: '10');
  bool _customBackgroundMode = false;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _customIntervalController.dispose();
    _customDistanceController.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Configure VietmapTrackingSDK with API key
      print('🔧 Configuring VietmapTrackingSDK...');
      await _controller.configure(
        '9f2c7a4d85e1b3c6d0749e8a2f51c0db76a4e390f1b2c847',
        // baseURL: 'https://api.vietmap.vn',
      );
      print('✅ VietmapTrackingSDK configured successfully');

      // Configure Alert API
      print('🚨 Configuring Alert API...');
      await _controller.configureAlertAPI(
        'YOUR_ALERT_API_KEY_HERE',
        'YOUR_ALERT_API_ID_HERE',
      );
      print('✅ Alert API configured successfully');

      await _checkPermissions();
      await _checkTrackingStatus();
      _setupListeners();
    } catch (error) {
      print('❌ Failed to initialize VietmapTrackingSDK: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Initialization Error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final result = await _controller.hasLocationPermissions();
      setState(() {
        _hasPermissions = result.granted;
      });
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  Future<void> _checkTrackingStatus() async {
    try {
      final status = await _controller.getTrackingStatus();
      setState(() {
        _trackingStatus = status;
        _isTracking = status.isTracking;
      });
    } catch (e) {
      print('Error checking tracking status: $e');
      setState(() {
        _isTracking = false;
      });
    }
  }

  void _setupListeners() {
    _locationSubscription = _controller.onLocationUpdate.listen((location) {
      print(
        '📍 Timer: ${DateTime.fromMillisecondsSinceEpoch(location.timestamp).toLocal()}',
      );
      print('📍 New location: $location');

      setState(() {
        // Calculate distance if we have previous location
        if (_currentLocation != null && _sessionStartTime != null) {
          final distance = _calculateDistance(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            location.latitude,
            location.longitude,
          );
          _totalDistance += distance;

          // Calculate average speed
          final duration = DateTime.now()
              .difference(_sessionStartTime!)
              .inSeconds;
          if (duration > 0) {
            _averageSpeed = _totalDistance / duration;
          }
        }

        _currentLocation = location;
        _locationHistory.add(location);
        if (_locationHistory.length > 50) {
          _locationHistory.removeAt(0);
        }
      });
    });

    _statusSubscription = _controller.onTrackingStatusChanged.listen((status) {
      print('📊 Status update: $status');
      setState(() {
        _trackingStatus = status;
        _isTracking = status.isTracking;
      });
    });
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }

  double sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;

  Future<void> _handleRequestPermissions() async {
    try {
      final result = await _controller.requestLocationPermissions();
      print('🔓 Permission result: $result');
      if (result.granted) {
        setState(() {
          _hasPermissions = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Location permissions granted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Location permissions denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to request permissions'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LocationTrackingConfig _getActiveConfig() {
    if (_useCustomConfig) {
      return LocationTrackingConfig(
        intervalMs: int.tryParse(_customIntervalController.text) ?? 5000,
        distanceFilter: double.tryParse(_customDistanceController.text) ?? 10,
        accuracy: LocationAccuracy.high,
        backgroundMode: _customBackgroundMode,
        notificationTitle: 'GPS Tracking',
        notificationMessage: 'Your location is being tracked',
      );
    }
    return LocationTrackingConfig(
      intervalMs: 5000,
      distanceFilter: 10,
      accuracy: LocationAccuracy.high,
      backgroundMode: false,
      notificationTitle: 'GPS Tracking',
      notificationMessage: 'Your location is being tracked',
    );
  }

  Future<void> _startTracking() async {
    if (!_hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Location permissions required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final activeConfig = _getActiveConfig();
      print('🚀 Starting enhanced tracking with config: $activeConfig');

      final result = await _controller.startTracking(activeConfig);
      print('✅ Enhanced tracking result: $result');

      if (result) {
        // Update tracking state immediately after successful start
        setState(() {
          _isTracking = true;
          _sessionStartTime = DateTime.now();
          _totalDistance = 0.0;
          _averageSpeed = 0.0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Enhanced GPS tracking started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('⚠️ Tracking may not have started successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Tracking started but result unclear'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Double-check the actual status after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          _checkTrackingStatus();
        });
      }
    } catch (e) {
      print('Error starting enhanced tracking: $e');
      setState(() {
        _isTracking = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start tracking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopTracking() async {
    try {
      final result = await _controller.stopTracking();
      print('✅ Enhanced tracking stopped: $result');

      if (result) {
        // Update tracking state immediately after successful stop
        setState(() {
          _isTracking = false;
          _trackingStatus = null;
          _sessionStartTime = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Enhanced GPS tracking stopped'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        print('⚠️ Tracking may not have stopped successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Tracking stopped but result unclear'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Double-check the actual status after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          _checkTrackingStatus();
        });
      }
    } catch (e) {
      print('Error stopping enhanced tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUpdateConfig() async {
    if (!_isTracking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Start tracking first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final activeConfig = _getActiveConfig();
      final success = await _controller.updateTrackingConfig(activeConfig);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuration updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update configuration'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshStatus() async {
    try {
      print('📊 Checking tracking status...');
      final status = await _controller.getTrackingStatus();
      print('📊 Current tracking status: $status');

      setState(() {
        _trackingStatus = status;
        _isTracking = status.isTracking;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Status refreshed'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error checking tracking status: $e');
      setState(() {
        _isTracking = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearHistory() {
    setState(() {
      _locationHistory.clear();
      _totalDistance = 0.0;
      _averageSpeed = 0.0;
      if (!_isTracking) {
        _sessionStartTime = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ History cleared'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  Future<void> _handleSpeedAlertToggle(bool enabled) async {
    // TODO: Implement turnOnAlert and turnOffAlert methods in VietmapTrackingController
    // For now, just show a message that this feature is not yet implemented
    try {
      if (enabled) {
        // Turn on speed alert - NOT YET IMPLEMENTED
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Speed Alert feature is not yet implemented in Flutter',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Keep the switch off since feature is not ready
        setState(() {
          _isSpeedAlertEnabled = false;
        });
      } else {
        // Turn off speed alert - NOT YET IMPLEMENTED
        setState(() {
          _isSpeedAlertEnabled = false;
        });
      }
    } catch (error) {
      print('Error toggling speed alert: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to toggle speed alert'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await _controller.getCurrentLocation();
      setState(() {
        _currentLocation = location;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Location fetched'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to get current location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLocationCard() {
    if (_currentLocation == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No location data yet'),
        ),
      );
    }

    final loc = _currentLocation!;
    final speedKmh = loc.speed * 3.6; // Convert m/s to km/h

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 Current Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Latitude: ${loc.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${loc.longitude.toStringAsFixed(6)}'),
            Text('Altitude: ${loc.altitude.toStringAsFixed(2)}m'),
            Text('Accuracy: ${loc.accuracy.toStringAsFixed(2)}m'),
            Text('Speed: ${speedKmh.toStringAsFixed(2)} km/h'),
            Text('Bearing: ${loc.bearing.toStringAsFixed(2)}°'),
            Text('Time: ${loc.dateTime}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tracking Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isTracking ? Icons.location_on : Icons.location_off,
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_isTracking ? 'Tracking Active' : 'Tracking Inactive'),
              ],
            ),
            if (_trackingStatus != null) ...[
              const SizedBox(height: 8),
              Text('Duration: ${_trackingStatus!.duration.inSeconds}s'),
              if (_trackingStatus!.lastUpdateTime != null)
                Text('Last Update: ${_trackingStatus!.lastUpdateTime}'),
            ],
            const SizedBox(height: 8),
            Text('Locations Recorded: ${_locationHistory.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatsCard() {
    if (_sessionStartTime == null && _totalDistance == 0) {
      return const SizedBox.shrink();
    }

    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    final distanceKm = _totalDistance / 1000;
    final avgSpeedKmh = _averageSpeed * 3.6;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Session Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Duration', _formatDuration(duration)),
                _buildStatItem(
                  'Distance',
                  '${distanceKm.toStringAsFixed(2)} km',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Avg Speed',
                  '${avgSpeedKmh.toStringAsFixed(2)} km/h',
                ),
                _buildStatItem('Points', '${_locationHistory.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛰️ GPS Tracking Demo'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTracking ? '🟢 Active' : '🔴 Inactive',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isTracking ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Permissions:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasPermissions ? '✅ Granted' : '❌ Denied',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _hasPermissions ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Permission Section
            if (!_hasPermissions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔒 Permissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _handleRequestPermissions,
                        child: const Text('Request Location Permissions'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_hasPermissions) const SizedBox(height: 16),

            // Speed Alert Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚨 Speed Alert',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Speed Alert:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: _isSpeedAlertEnabled,
                          onChanged: _handleSpeedAlertToggle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Speed violations are announced using native speech synthesis. No visual alerts are displayed.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Configuration Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚙️ Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Use Custom Config:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: _useCustomConfig,
                          onChanged: (value) {
                            setState(() {
                              _useCustomConfig = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_useCustomConfig) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('Interval (ms):'),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _customIntervalController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('Distance (m):'),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _customDistanceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Background Mode (Custom):'),
                                Switch(
                                  value: _customBackgroundMode,
                                  onChanged: (value) {
                                    setState(() {
                                      _customBackgroundMode = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Current: ${_useCustomConfig ? 'Custom' : 'Preset'} | '
                        'Interval: ${_getActiveConfig().intervalMs}ms | '
                        'Distance: ${_getActiveConfig().distanceFilter}m | '
                        'Background: ${_getActiveConfig().backgroundMode ? '✅' : '❌'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Session Statistics
            _buildSessionStatsCard(),
            if (_sessionStartTime != null) const SizedBox(height: 16),

            // Tracking Status
            _buildTrackingStatusCard(),
            const SizedBox(height: 16),

            // Location Data
            _buildLocationCard(),
            const SizedBox(height: 16),

            // Control Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '🎮 Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (!_hasPermissions || _isTracking)
                                ? null
                                : _startTracking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text('🚀 Start Tracking'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isTracking ? null : _stopTracking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text('🛑 Stop Tracking'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_hasPermissions
                                ? null
                                : _getCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text('📍 Get Location'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isTracking
                                ? null
                                : _handleUpdateConfig,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text('⚙️ Update Config'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _refreshStatus,
                            child: const Text('🔄 Refresh Status'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _clearHistory,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('🗑️ Clear History'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Location History
            if (_locationHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📝 Location History (${_locationHistory.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_locationHistory.reversed.take(5).map((loc) {
                        final speedKmh = loc.speed * 3.6;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)} | '
                              '${speedKmh.toStringAsFixed(1)} km/h | '
                              '${loc.dateTime.hour}:${loc.dateTime.minute.toString().padLeft(2, '0')}:${loc.dateTime.second.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      })),
                      if (_totalDistance > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Total Distance: ${(_totalDistance / 1000).toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
