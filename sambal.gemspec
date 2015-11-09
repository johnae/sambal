# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sambal/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["John Axel Eriksson"]
  gem.email         = ["john@insane.se"]
  gem.description   = %q{Ruby Samba Client using the cmdline smbclient}
  gem.summary       = %q{Ruby Samba Client}
  gem.homepage      = "https://github.com/johnae/sambal"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "sambal"
  gem.require_paths = ["lib"]
  gem.version       = Sambal::VERSION

  gem.add_development_dependency 'rspec', '~> 3.0'
end
