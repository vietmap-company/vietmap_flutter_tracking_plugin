#
# vietmap_tracking.podspec
# Flutter plugin bridging VietmapTrackingSDK (tracking) and
# VietmapAlertBridge (speed-alert / zone-network-v2) for iOS 12+.
#
Pod::Spec.new do |s|
  s.name             = 'vietmap_tracking_plugin'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for Vietmap GPS tracking and speed-alert SDK.'
  s.description      = <<-DESC
    Wraps VietmapTrackingSDK and VietmapAlertBridge:
    - GPS tracking with background mode
    - Speed-sign / TTS alert streaming
    - Zone-network-v2 configuration
  DESC
  s.homepage         = 'https://github.com/vietmap-company/vietmap_tracking_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vietmap' => 'developer@vietmap.vn' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  # Flutter framework — required for MethodChannel / EventChannel
  s.dependency 'Flutter'

  # Native SDK — uncomment the pinned version when the SDK is published with
  # a stable tag; leave unpinned for development builds that use a local path.
  # s.dependency 'VietmapTrackingSDK', '~> 1.1.6'
  s.dependency 'VietmapTrackingSDK', '1.3.9'

  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                       => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
