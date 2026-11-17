#
# scrl_video per iOS. La parte con AVFoundation (AVAssetReader / AVAssetWriter) arriva con la Fase 9:
# per ora il plugin risponde «non disponibile», così l'app si compila anche per iOS.
#
Pod::Spec.new do |s|
  s.name             = 'scrl_video'
  s.version          = '0.0.1'
  s.summary          = 'Video di ScrolleR Studio Mobile.'
  s.description      = 'Lettura di fotogrammi e audio, scrittura MP4 con i codificatori di sistema.'
  s.homepage         = 'https://github.com/Michelo1927/ScrolleR-Studio'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Michelo1927' => '80256452+Michelo1927@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'scrl_video/Sources/scrl_video/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
