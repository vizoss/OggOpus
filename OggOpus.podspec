Pod::Spec.new do |s|
  s.name = 'OggOpus'
  s.version = '1.0.0'
  s.summary = 'Ogg Opus codec, microphone recorder, and player for iOS.'
  s.description = 'A standard Ogg Opus audio SDK. Records 16 kHz mono PCM as Ogg Opus and plays standard Ogg Opus files.'
  s.homepage = 'https://github.com/vizoss/OggOpus'
  s.license = { type: 'MIT', file: 'LICENSE' }
  s.author = 'THK'
  s.source = { git: 'https://github.com/vizoss/OggOpus.git', tag: s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.9']
  s.source_files = 'ios/Sources/OggOpus/**/*.swift'
  s.vendored_frameworks = 'ios/Vendor/YbridOgg.xcframework', 'ios/Vendor/YbridOpus.xcframework'
  s.frameworks = 'AVFoundation', 'AudioToolbox'
end
