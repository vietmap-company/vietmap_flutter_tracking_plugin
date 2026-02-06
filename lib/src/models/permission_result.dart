/// Permission check result
class PermissionResult {
  final bool granted;
  final PermissionStatus status;
  final bool fineLocation;
  final bool coarseLocation;
  final bool backgroundLocation;

  const PermissionResult({
    required this.granted,
    required this.status,
    required this.fineLocation,
    required this.coarseLocation,
    required this.backgroundLocation,
  });

  factory PermissionResult.fromJson(Map<String, dynamic> json) {
    return PermissionResult(
      granted: json['granted'] as bool,
      status: PermissionStatus.fromString(json['status'] as String),
      fineLocation: json['fineLocation'] as bool? ?? false,
      coarseLocation: json['coarseLocation'] as bool? ?? false,
      backgroundLocation: json['backgroundLocation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'granted': granted,
    'status': status.value,
    'fineLocation': fineLocation,
    'coarseLocation': coarseLocation,
    'backgroundLocation': backgroundLocation,
  };
}

enum PermissionStatus {
  granted('granted'),
  denied('denied'),
  notGranted('not_granted');

  final String value;

  const PermissionStatus(this.value);

  static PermissionStatus fromString(String value) {
    return PermissionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PermissionStatus.notGranted,
    );
  }
}
