import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vietmap_tracking_plugin/src/services/vietmap_preference.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

@pragma('vm:entry-point')
class TrackingLocation {
  static int timeSendServer =
      30; // Default value, will be updated from preferences
  static GpsLocation gpsLocation = GpsLocation();
  static GpsLocation gpsLocationPrevious = GpsLocation();
  static List<GpsLocation> listTrackingWhenFailed = [];
  static bool handleCheckInOut = false;
  static Timer? timerGetLocation;

  static void _logSection(String section, {bool end = false}) {
    debugPrint('=======${end ? 'End ' : ''}$section=======');
  }

  static bool isLocationStill({
    required GpsLocation previousLocation,
    required GpsLocation currentLocation,
  }) {
    final distance = Geolocator.distanceBetween(
      previousLocation.latitude ?? 0.0,
      previousLocation.longitude ?? 0.0,
      currentLocation.latitude ?? 0.0,
      currentLocation.longitude ?? 0.0,
    );
    return distance <= 5;
  }

  /// Collect data(location) and send to server
  static sendDataToServer(GpsLocation data) async {
    debugPrint("SEND DATA TO SERVER");

    try {
      var baseUrl = await VietMapPreference().getEndPoint();
      var apiKey = await VietMapPreference().getApiKey();

      if (baseUrl != null &&
          apiKey != null &&
          data.latitude != null &&
          data.longitude != null) {
        // GET display address
        data.displayAddress = await getDisplayAddress(
          data.latitude ?? 0.0,
          data.longitude ?? 0.0,
        );

        // Prepare the payload
        final payload = {
          'latitude': data.latitude,
          'longitude': data.longitude,
          'speed': data.speed ?? 0.0,
          'heading': data.heading ?? 0.0,
          'accuracy': data.accuracy ?? 0.0,
          'altitude': data.altitude ?? 0.0,
          'timestamp':
              data.timestamp?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'display_address': data.displayAddress,
        };

        // Add metadata if available
        if (data.metadata != null) {
          payload.addAll(data.metadata!);
        }

        // Send HTTP request
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Request timeout',
                  const Duration(seconds: 15),
                );
              },
            );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint("Location sent successfully: ${response.statusCode}");

          // Update previous location on success
          gpsLocationPrevious = data.copyWith();

          // Clear any failed locations if this succeeds
          if (listTrackingWhenFailed.isNotEmpty) {
            await _sendFailedLocations();
          }
        } else {
          debugPrint(
            "Failed to send location: ${response.statusCode} - ${response.body}",
          );
          _handleFailedLocation(data);
        }
      } else {
        debugPrint(
          "Missing configuration: baseUrl=$baseUrl, apiKey=${apiKey != null ? 'set' : 'null'}",
        );
        _handleFailedLocation(data);
      }
    } catch (e) {
      debugPrint("Error sending location: $e");
      _handleFailedLocation(data);
    }
  }

  /// Handle failed location by adding to cache
  static _handleFailedLocation(GpsLocation location) async {
    listTrackingWhenFailed.add(location);
    await VietMapPreference().setListGPS(listTrackingWhenFailed);
    debugPrint(
      "Added failed location to cache. Total: ${listTrackingWhenFailed.length}",
    );
  }

  /// Retry sending failed locations
  static _sendFailedLocations() async {
    if (listTrackingWhenFailed.isEmpty) return;

    debugPrint("Retrying ${listTrackingWhenFailed.length} failed locations");

    final locationsToRetry = List<GpsLocation>.from(listTrackingWhenFailed);
    listTrackingWhenFailed.clear();

    try {
      var baseUrl = await VietMapPreference().getEndPoint();
      var apiKey = await VietMapPreference().getApiKey();

      if (baseUrl != null && apiKey != null) {
        // Send as batch
        final batchPayload = {
          'locations': locationsToRetry
              .map(
                (location) => {
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                  'speed': location.speed ?? 0.0,
                  'heading': location.heading ?? 0.0,
                  'accuracy': location.accuracy ?? 0.0,
                  'altitude': location.altitude ?? 0.0,
                  'timestamp':
                      location.timestamp?.toIso8601String() ??
                      DateTime.now().toIso8601String(),
                  'display_address': location.displayAddress,
                  if (location.metadata != null) ...location.metadata!,
                },
              )
              .toList(),
        };

        final response = await http
            .post(
              Uri.parse('$baseUrl/batch'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
                'Accept': 'application/json',
              },
              body: jsonEncode(batchPayload),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint(
            "Successfully sent ${locationsToRetry.length} cached locations",
          );
          await VietMapPreference().setListGPS(
            listTrackingWhenFailed,
          ); // Clear cache
        } else {
          debugPrint(
            "Failed to send cached locations: ${response.statusCode}",
          );
          listTrackingWhenFailed.addAll(locationsToRetry); // Add back to cache
          await VietMapPreference().setListGPS(listTrackingWhenFailed);
        }
      }
    } catch (e) {
      debugPrint("❌ Error sending cached locations: $e");
      listTrackingWhenFailed.addAll(locationsToRetry); // Add back to cache
      await VietMapPreference().setListGPS(listTrackingWhenFailed);
    }
  }

  static Future<String?> getDisplayAddress(
    double latitude,
    double longitude,
  ) async {
    String? result;
    return result;
  }

  /// Handle follow user
  static handleFollowUser() async {
    debugPrint(
      '-------- FLUTTER BACKGROUND START SERVICE: ${DateTime.now()} -----------',
    );

    /// check follow user
    LocationPermission locationPermission = await Geolocator.checkPermission();
    bool enableLocation = await Geolocator.isLocationServiceEnabled();
    if (locationPermission != LocationPermission.denied &&
        locationPermission != LocationPermission.deniedForever &&
        enableLocation) {
      /// init tracking user
      debugPrint("get Location");
      try {
        Position position = await Geolocator.getCurrentPosition();
        await handleWithLocation(position: position);
      } catch (e) {
        debugPrint('FLUTTER BACKGROUND Get location error: $e');
      }
    }
    debugPrint('-------- FLUTTER BACKGROUND END SERVICE -----------');
  }

  static Future handleWithLocation({required Position position}) async {
    /// get list gps when send to server failed
    listTrackingWhenFailed = await VietMapPreference().getListGPSCache() ?? [];
    DateTime now = DateTime.now();
    // final CompassEvent? tmp = await FlutterCompass.events?.first;
    debugPrint(position.latitude.toString());
    debugPrint(position.longitude.toString());
    debugPrint(
      'list tracking offline/failed: ${listTrackingWhenFailed.length.toString()}',
    );
    debugPrint('timer: $timeSendServer');

    double speed = calculateSpeed(position);
    gpsLocation = GpsLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading < 0 ? 0 : position.heading,
      speed: position.speed < 0.0
          ? 0.0
          : (speed > 150.0 ? randomSpeedMax() : speed),
      timestamp: now,
    );

    // Collect GPS when send gps to server failed
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.last == ConnectivityResult.none) {
      debugPrint("COLLECT DATA WHEN OFFLINE");
      if (listTrackingWhenFailed.isEmpty) {
        listTrackingWhenFailed.add(gpsLocation);
        VietMapPreference().setListGPS(listTrackingWhenFailed);
      } else {
        if (!isLocationStill(
          previousLocation: listTrackingWhenFailed.last,
          currentLocation: gpsLocation,
        )) {
          listTrackingWhenFailed.add(gpsLocation);
          VietMapPreference().setListGPS(listTrackingWhenFailed);
        }
      }
    } else {
      // SEND REAL TIME TO SERVER
      if (gpsLocationPrevious.latitude == null ||
          gpsLocationPrevious.longitude == null) {
        sendDataToServer(gpsLocation);
      } else {
        if (!isLocationStill(
          previousLocation: gpsLocationPrevious,
          currentLocation: gpsLocation,
        )) {
          sendDataToServer(gpsLocation);
        }
      }
    }
  }

  static double randomSpeedMax() {
    final random = Random();
    return 60 + random.nextDouble() * 90;
  }

  static double calculateSpeed(Position currentPosition) {
    if (gpsLocationPrevious.latitude != null &&
        gpsLocationPrevious.longitude != null &&
        gpsLocationPrevious.timestamp != null) {
      double distance = Geolocator.distanceBetween(
        gpsLocationPrevious.latitude!,
        gpsLocationPrevious.longitude!,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      Duration timeDiff = DateTime.now().difference(
        gpsLocationPrevious.timestamp ?? DateTime.now(),
      );
      double timeInSeconds = timeDiff.inSeconds.toDouble();

      double speed = distance / timeInSeconds; // m/s
      double speedKmh = speed * 3.6; // km/h

      return speedKmh;
    }
    return currentPosition.speed * 3.6;
  }

  static startTracking() async {
    _logSection('Start Tracking Location');
    try {
      // Get tracking interval from preferences (default 30 seconds)
      timeSendServer = await VietMapPreference().getTrackingInterval();
      debugPrint("📍 Starting tracking with interval: ${timeSendServer}s");

      /// Get location with configurable interval
      final duration = Duration(seconds: timeSendServer);
      timerGetLocation ??= Timer.periodic(duration, (timer) {
        handleFollowUser();
      });
      handleFollowUser();
    } finally {
      _logSection('Start Tracking Location', end: true);
    }
  }

  static stopTracking() {
    _logSection('Stop Tracking Location');
    try {
      timerGetLocation?.cancel();
      timerGetLocation = null;
    } finally {
      _logSection('Stop Tracking Location', end: true);
    }
  }

  /// Update tracking interval and restart tracking if currently running
  static updateTrackingInterval(int seconds) async {
    _logSection('Update Tracking Interval');
    try {
      timeSendServer = seconds;
      await VietMapPreference().setTrackingInterval(seconds);

      // If tracking is currently running, restart with new interval
      if (timerGetLocation != null) {
        debugPrint("🔄 Updating tracking interval to ${seconds}s and restarting");
        stopTracking();
        await startTracking();
      } else {
        debugPrint(
          "⏱️ Tracking interval updated to ${seconds}s (will apply on next start)",
        );
      }
    } finally {
      _logSection('Update Tracking Interval', end: true);
    }
  }
}
