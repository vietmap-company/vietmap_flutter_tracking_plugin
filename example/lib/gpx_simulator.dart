import 'dart:async';
import 'package:xml/xml.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

class GPXWaypoint {
  final double lat;
  final double lon;
  final DateTime time;
  final double? alt;

  GPXWaypoint({
    required this.lat,
    required this.lon,
    required this.time,
    this.alt,
  });
}

class GPXSimulator {
  final List<GPXWaypoint> waypoints;
  final void Function(LocationData)? onLocation;

  Timer? _timer;
  int _index = 0;
  bool _running = false;

  GPXSimulator({
    required this.waypoints,
    this.onLocation,
  });

  bool get isRunning => _running;
  int get current => _index;
  int get total => waypoints.length;

  static List<GPXWaypoint> parseGPX(String gpxContent) {
    final doc = XmlDocument.parse(gpxContent);
    final waypoints = <GPXWaypoint>[];

    for (final wpt in doc.findAllElements('wpt')) {
      final lat = double.tryParse(wpt.getAttribute('lat') ?? '');
      final lon = double.tryParse(wpt.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      DateTime time = DateTime.now();
      final timeEl = wpt.findElements('time').firstOrNull;
      if (timeEl != null) {
        try {
          time = DateTime.parse(timeEl.text);
        } catch (_) {}
      }

      double? alt;
      final altEl = wpt.findElements('ele').firstOrNull;
      if (altEl != null) {
        alt = double.tryParse(altEl.text);
      }

      waypoints.add(GPXWaypoint(lat: lat, lon: lon, time: time, alt: alt));
    }

    return waypoints;
  }

  void start({double speed = 5.0}) {
    if (_running || waypoints.isEmpty) return;
    _running = true;
    _index = 0;
    _sendNext(speed);
  }

  void stop() {
    _timer?.cancel();
    _running = false;
    _index = 0;
  }

  void _sendNext(double speed) {
    if (_index >= waypoints.length) {
      _running = false;
      return;
    }

    final wp = waypoints[_index];
    onLocation?.call(LocationData(
      latitude: wp.lat,
      longitude: wp.lon,
      altitude: wp.alt ?? 0.0,
      accuracy: 5.0,
      speed: 2.78, // ~10 km/h
      heading: 0.0,
      timestamp: wp.time.millisecondsSinceEpoch,
    ));

    _index++;

    if (_index < waypoints.length) {
      final delay = ((waypoints[_index].time.difference(wp.time).inMilliseconds) / speed).toInt();
      if (delay > 0) {
        _timer = Timer(Duration(milliseconds: delay), () => _sendNext(speed));
      } else {
        _sendNext(speed);
      }
    }
  }

  String getStats() {
    if (waypoints.isEmpty) return 'No data';
    return 'Waypoints: ${waypoints.length} | '
        'Duration: ${waypoints.last.time.difference(waypoints.first.time).inSeconds}s';
  }
}
