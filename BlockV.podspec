#
# Be sure to run `pod lib lint BlockV.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name             = 'BLOCKv'
  s.version          = '0.9.0'
  s.summary          = 'The BLOCKv SDK allows for easy integration into the BLOCKv Platform.'
  s.homepage         = 'https://blockv.io'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'BlockV AG', :file => 'LICENSE' }
  s.author           = { 'BlockV' => 'developer.blockv.io' }
  s.source           = { :git => 'https://github.com/BLOCKvIO/ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/blockv_io'

  s.ios.deployment_target = '10.0'
  s.source_files = 'BlockV/Classes/**/*'
  
  # s.resource_bundles = {
  #   'BlockV' => ['BlockV/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
 
  s.dependency 'Alamofire', '~> 4.7'
  
end
