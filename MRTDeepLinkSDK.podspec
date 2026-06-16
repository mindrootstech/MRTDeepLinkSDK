Pod::Spec.new do |s|
  s.name             = 'MRTDeepLinkSDK'
  s.version          = '0.3.5'
  s.summary          = 'Lightweight deep linking & event analytics SDK for iOS.'
  s.description      = <<-DESC
    MRTDeepLinkSDK helps iOS apps receive, parse, and route deep links from
    Universal Links (https) and custom URL schemes. Includes event tracking
    and SwiftUI helpers.
  DESC
  s.homepage         = 'https://github.com/mindrootstech/MRTDeepLinkSDK'
  s.license          = { :type => 'MIT' }
  s.author           = { 'MindRoots' => 'info@mindroots.com' }
  s.source           = { :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.subspec 'Core' do |core|
    core.source_files = 'MRTDeepLinkSDK/Classes/**/*.swift'
  end

  s.subspec 'SwiftUI' do |ss|
    ss.source_files = 'MRTDeepLinkSDK/SwiftUI/**/*.swift'
    ss.dependency 'MRTDeepLinkSDK/Core'
  end

  s.default_subspecs = 'Core', 'SwiftUI'
end
