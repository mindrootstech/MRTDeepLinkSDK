Pod::Spec.new do |s|
  s.name             = 'MRTDeepLinkSDK'
  s.version          = '0.6.0'
  s.summary          = 'Deferred deep linking SDK for iOS.'
  s.description      = <<-DESC
    MRTDeepLinkSDK attributes pre-install SmartLink clicks on first app open
    via POST /api/deferred/app/match, plus Universal Link / custom-scheme routing.
  DESC
  s.homepage         = 'https://github.com/mindrootstech/MRTDeepLinkSDK'
  s.license          = { :type => 'Copyright', :file => 'LICENSE' }
  s.author           = { 'MindRoots' => 'info@mindroots.com' }
  s.source           = { :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  # Local SDK development: MRT_SDK_SOURCE=1 pod install (default in this repo's Podfile)
  use_source = ENV['MRT_SDK_SOURCE'] == '1'
  xcframework_path = 'Frameworks/MRTDeepLinkSDK.xcframework'
  has_binary = File.directory?(File.join(__dir__, xcframework_path))

  if !use_source && has_binary
    s.vendored_frameworks = xcframework_path
  else
    s.subspec 'Core' do |core|
      core.source_files = 'MRTDeepLinkSDK/Classes/**/*.swift'
    end

    s.subspec 'SwiftUI' do |ss|
      ss.source_files = 'MRTDeepLinkSDK/SwiftUI/**/*.swift'
      ss.dependency 'MRTDeepLinkSDK/Core'
    end

    s.default_subspecs = 'Core', 'SwiftUI'
  end
end
