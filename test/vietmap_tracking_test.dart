import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final plugin = VietmapTrackingPlugin.instance;
  late Future<Object?>? Function(MethodCall call) mockHandler;

  setUp(() {
    mockHandler = (MethodCall call) async => null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vietmap_tracking_plugin'),
      (MethodCall call) => mockHandler(call),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vietmap_tracking_plugin'),
      null,
    );
  });

  group('configureTracking', () {
    test('sends header auth mode by default', () async {
      String? capturedMethod;
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final result = await plugin.configureTracking(
        apiKey: 'test-key',
      );

      expect(result, true);
      expect(capturedMethod, 'configureTracking');
      expect(capturedArgs!['apiKey'], 'test-key');
      expect(capturedArgs!['baseUrl'], 'https://tracking.vietmap.vn');
      expect(capturedArgs!['authMode'], 'header');
      expect(capturedArgs!['gpsTrackingEndpoint'], '/gps-tracking');
      expect(capturedArgs!['gpsBulkEndpoint'], '/gps-tracking/bulk');
      expect(capturedArgs!['autoUpload'], true);
    });

    test('sends queryParam auth mode when requested', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final result = await plugin.configureTracking(
        apiKey: 'test-key',
        baseUrl: 'https://tracking.example.com',
        authMode: AuthMode.queryParam,
        gpsTrackingEndpoint: '/custom/gps',
        gpsBulkEndpoint: '/custom/gps/bulk',
        autoUpload: false,
      );

      expect(result, true);
      expect(capturedArgs!['authMode'], 'queryParam');
      expect(capturedArgs!['baseUrl'], 'https://tracking.example.com');
      expect(capturedArgs!['gpsTrackingEndpoint'], '/custom/gps');
      expect(capturedArgs!['gpsBulkEndpoint'], '/custom/gps/bulk');
      expect(capturedArgs!['autoUpload'], false);
    });
  });

  group('configureAlertAPI', () {
    test('passes default alert url when omitted', () async {
      String? capturedMethod;
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final result = await plugin.configureAlertAPI(
        apiKey: 'alert-key',
        apiID: 'alert-id',
      );

      expect(result, true);
      expect(capturedMethod, 'configureAlertAPI');
      expect(capturedArgs!['apiKey'], 'alert-key');
      expect(capturedArgs!['apiID'], 'alert-id');
      expect(capturedArgs!['url'], 'https://drive-api.vietmap.vn/fleetwork/api/Alert/v2/mpp');
    });
  });

  group('zone network v2', () {
    test('configureZoneNetworkV2 invokes native method', () async {
      String? capturedMethod;
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final result = await plugin.configureZoneNetworkV2('https://zone.example.com');

      expect(result, true);
      expect(capturedMethod, 'configureZoneNetworkV2');
      expect(capturedArgs!['baseUrl'], 'https://zone.example.com');
    });

    test('resetZoneNetworkV2 invokes native method', () async {
      String? capturedMethod;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        return true;
      };

      final result = await plugin.resetZoneNetworkV2();

      expect(result, true);
      expect(capturedMethod, 'resetZoneNetworkV2');
    });
  });
}
