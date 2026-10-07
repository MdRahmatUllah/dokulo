# CocoaPods twin of ios/web_to_pdf/Package.swift (Flutter uses whichever the app's iOS build uses).
Pod::Spec.new do |s|
  s.name             = 'web_to_pdf'
  s.version          = '0.1.0'
  s.summary          = 'Web page or HTML to a paginated PDF for Dokulo (DK-0399).'
  s.homepage         = 'https://github.com/MdRahmatUllah/dokulo'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Dokulo' => 'dokulo@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'web_to_pdf/Sources/web_to_pdf/**/*.swift'
  s.resource_bundles = { 'web_to_pdf_privacy' => ['web_to_pdf/Sources/web_to_pdf/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.frameworks       = 'WebKit'
  s.platform         = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
