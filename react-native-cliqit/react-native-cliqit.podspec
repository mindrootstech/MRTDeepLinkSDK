require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name             = 'react-native-cliqit'
  s.version          = package['version']
  s.summary          = package['description']
  s.homepage         = 'https://github.com/mindrootstech/CliqIt'
  s.license          = { :type => 'UNLICENSED' }
  s.authors          = { 'MindRoots' => 'info@mindroots.com' }
  s.source           = { :git => 'https://github.com/mindrootstech/CliqIt.git', :tag => "rn-#{s.version}" }

  s.platforms        = { :ios => '15.0' }
  s.swift_version    = '5.0'

  s.source_files = 'ios/*.{h,m,mm,swift}'
  s.vendored_frameworks = 'ios/Frameworks/CliqIt.xcframework'

  s.dependency 'React-Core'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }
end
