Pod::Spec.new do |s|
  s.name             = 'MRTDeepLinkSDK'
  s.version          = '0.6.1'
  s.summary          = 'Deferred deep linking SDK for iOS.'
  s.description      = <<-DESC
    MRTDeepLinkSDK attributes pre-install SmartLink clicks on first app open
    via POST /api/deferred/app/match, plus Universal Link / custom-scheme routing.
  DESC
  s.homepage         = 'https://github.com/mindrootstech/MRTDeepLinkSDK'
  s.license          = { :type => 'Copyright', :file => 'MRTDeepLinkSDK/LICENSE' }
  s.author           = { 'MindRoots' => 'info@mindroots.com' }
  s.source           = { :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  # Root podspec for git installs — ships binary XCFramework only.
  s.vendored_frameworks = 'MRTDeepLinkSDK/Frameworks/MRTDeepLinkSDK.xcframework'
end
