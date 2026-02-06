import 'dart:math';
import '../models/location_data.dart';

/// Utility functions for location calculations
class LocationUtils {
  /// Calculate distance between two coordinates using Haversine formula
  ///
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate distance between two LocationData objects
  static double distanceBetween(LocationData loc1, LocationData loc2) {
    return calculateDistance(
      loc1.latitude,
      loc1.longitude,
      loc2.latitude,
      loc2.longitude,
    );
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Convert speed from m/s to km/h
  static double metersPerSecondToKmh(double metersPerSecond) {
    return metersPerSecond * 3.6;
  }

  /// Convert speed from km/h to m/s
  static double kmhToMetersPerSecond(double kmh) {
    return kmh / 3.6;
  }

  /// Format coordinates to readable string
  static String formatCoordinates(double latitude, double longitude) {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(6)}° $latDir, ${longitude.abs().toStringAsFixed(6)}° $lonDir';
  }

  /// Check if location is within a specified radius of target
  static bool isWithinRadius(
    LocationData location,
    double targetLat,
    double targetLon,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      location.latitude,
      location.longitude,
      targetLat,
      targetLon,
    );
    return distance <= radiusMeters;
  }
}
