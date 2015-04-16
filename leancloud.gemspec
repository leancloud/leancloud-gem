Gem::Specification.new do |s|
  s.name        = 'leancloud'
  s.version     = '0.0.1'
  s.date        = '2015-04-14'
  s.summary     = 'LeanCloud'
  s.description = 'LeanCloud command line tool.'
  s.authors     = ['Tianyong Tang']
  s.email       = 'ttang@leancloud.rocks'
  s.files       = ['lib/leancloud.rb']
  s.executables = ['leancloud']
  s.homepage    = 'https://leancloud.cn/'
  s.license     = 'MIT'

  s.add_runtime_dependency 'xcodeproj', '~> 0.23.1'
  s.add_runtime_dependency 'colorize', '~> 0.7.5'
  s.add_runtime_dependency 'clactive', '~> 0.1.0'
end
