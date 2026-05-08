#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vietmap_tracking_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vietmap_tracking_plugin'
  s.version          = '1.0.6'
  s.summary          = 'Flutter plugin for Vietmap GPS tracking.'
  s.description      = <<-DESC
A Flutter plugin for GPS tracking and location data transmission to Vietmap's tracking API with background service support.
                       DESC
  s.homepage         = 'https://github.com/vietmap-company/vietmap_tracking_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vietmap Company' => 'nhatpv@vietmap.vn' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'VietmapTrackingSDK', '1.4.1'
  # s.dependency 'VietmapTrackingSDK'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'vietmap_tracking_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
