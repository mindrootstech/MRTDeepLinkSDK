Pod::Spec.new do |s|
  s.name             = 'CliqIt'
  s.version          = '2.0.2'
  s.summary          = 'Deferred deep linking SDK for iOS.'
  s.description      = <<-DESC
    CliqIt attributes pre-install SmartLink clicks on first app open
    via POST /api/v1/sdk/app/match, plus Universal Link / custom-scheme routing.
  DESC
  s.homepage         = 'https://github.com/mindrootstech/CliqIt'
  s.license          = { :type => 'Copyright', :file => 'LICENSE' }
  s.author           = { 'MindRoots' => 'info@mindroots.com' }
  s.source           = { :git => 'https://github.com/mindrootstech/CliqIt.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  # Local SDK development: CLIQIT_SDK_SOURCE=1 pod install (default in this repo's Podfile)
  use_source = ENV['CLIQIT_SDK_SOURCE'] == '1'
  xcframework_path = 'Frameworks/CliqIt.xcframework'
  has_binary = File.directory?(File.join(__dir__, xcframework_path))

  if !use_source && has_binary
    s.vendored_frameworks = xcframework_path
  else
    s.subspec 'Core' do |core|
      core.source_files = 'CliqIt/Classes/**/*.swift'
    end

    s.subspec 'SwiftUI' do |ss|
      ss.source_files = 'CliqIt/SwiftUI/**/*.swift'
      ss.dependency 'CliqIt/Core'
    end

    s.default_subspecs = 'Core', 'SwiftUI'
  end
end
