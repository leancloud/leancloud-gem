$: << File.expand_path('../lib', __FILE__)

require 'leancloud'

Gem::Specification.new do |s|
  s.name          = 'leancloud'
  s.version       = LeanCloud::VERSION
  s.date          = '2015-04-14'
  s.summary       = 'LeanCloud'
  s.description   = 'LeanCloud command line tool.'
  s.authors       = ['Tianyong Tang']
  s.email         = 'ttang@leancloud.rocks'
  s.files         = Dir['lib/**/*.rb']
  s.executables   = ['leancloud']
  s.require_paths = ['lib']
  s.homepage      = 'https://leancloud.cn/'
  s.license       = 'MIT'

  s.add_runtime_dependency 'xcodeproj', '~> 0.23.1'
  s.add_runtime_dependency 'colorize', '~> 0.7.5'
  s.add_runtime_dependency 'clactive', '~> 0.1.0'
  s.add_runtime_dependency 'mustache', '~> 1.0'
end
