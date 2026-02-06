/// Route link information
class RouteLink {
  final int id;
  final int direction;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final double distance;
  final List<List<num>> speedLimits;

  const RouteLink({
    required this.id,
    required this.direction,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.distance,
    required this.speedLimits,
  });

  factory RouteLink.fromJson(Map<String, dynamic> json) {
    return RouteLink(
      id: json['id'] as int,
      direction: json['direction'] as int,
      startLat: (json['startLat'] as num).toDouble(),
      startLon: (json['startLon'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLon: (json['endLon'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      speedLimits: (json['speedLimits'] as List)
          .map((e) => (e as List).map((n) => n as num).toList())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction,
    'startLat': startLat,
    'startLon': startLon,
    'endLat': endLat,
    'endLon': endLon,
    'distance': distance,
    'speedLimits': speedLimits,
  };
}

/// Route alert information
class RouteAlert {
  final int type;
  final int? subtype;
  final double? speedLimit;

  const RouteAlert({required this.type, this.subtype, this.speedLimit});

  factory RouteAlert.fromJson(Map<String, dynamic> json) {
    return RouteAlert(
      type: json['type'] as int,
      subtype: json['subtype'] as int?,
      speedLimit: json['speedLimit'] != null
          ? (json['speedLimit'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'subtype': subtype,
    'speedLimit': speedLimit,
  };
}
