# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

# Local path pod — always compile SDK from source (not the vendored XCFramework).
ENV['CLIQIT_SDK_SOURCE'] = '1'

target 'MRTDeepLink' do
  use_frameworks!

  pod 'CliqIt', :path => './CliqIt'

  target 'MRTDeepLinkTests' do
    inherit! :search_paths
  end

  target 'MRTDeepLinkUITests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end

  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate_target.user_project.save
  end
end
