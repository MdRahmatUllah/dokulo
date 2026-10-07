# CocoaPods twin of ios/vision_ocr/Package.swift (Flutter uses whichever the app's iOS build uses).
Pod::Spec.new do |s|
  s.name             = 'vision_ocr'
  s.version          = '0.1.0'
  s.summary          = 'Apple Vision text recognition for Dokulo (DK-0397).'
  s.homepage         = 'https://github.com/MdRahmatUllah/dokulo'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Dokulo' => 'dokulo@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'vision_ocr/Sources/vision_ocr/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks       = 'Vision'
  s.platform         = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
