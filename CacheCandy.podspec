
Pod::Spec.new do |s|
  s.name             = 'CacheCandy'
  s.version          = '0.1.0'
  s.summary          = 'Swift Cache with memory LRU.'
  s.description      = <<-DESC
    Swift 3.0
    Easy to custom
                       DESC

  s.homepage         = 'https://github.com/7ulipa/CacheCandy'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'darwin.jxzang@gmail.com' => 'darwin.jxzang@gmail.com' }
  s.source           = { :git => 'https://github.com/7ulipa/CacheCandy.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'CacheCandy/Classes/**/*'

end
