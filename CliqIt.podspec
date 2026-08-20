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

  # Public binary distribution — flat Frameworks/ layout.
  s.vendored_frameworks = 'Frameworks/CliqIt.xcframework'
end
