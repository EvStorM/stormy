Pod::Spec.new do |s|
  s.name             = 'stormy_gromore'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bridge for the China GroMore mediation SDK.'
  s.description      = <<-DESC
Flutter-owned configuration and ad placement parameters for GroMore on iOS.
                       DESC
  s.homepage         = 'https://github.com/EvStorM/stormy/tree/main/packages/stormy_gromore'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'stormy_gromore contributors' => 'opensource@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m}'
  s.platform         = :ios, '13.0'
  s.static_framework = true

  s.dependency 'Flutter'
  s.dependency 'Ads-CN-Beta/CSJMediation-Only', '7.8.0.3'

  s.frameworks = 'Network'
  s.weak_frameworks = 'AppTrackingTransparency'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
