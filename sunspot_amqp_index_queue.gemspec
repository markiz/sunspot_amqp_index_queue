# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sunspot/amqp_index_queue/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mark Abramov"]
  gem.email         = ["markizko@gmail.com"]
  gem.description   = "Asynchronously handle your sunspot model indexing"
  gem.summary       = "Asynchronously handle your sunspot model indexing"
  gem.homepage      = "https://github.com/markiz/sunspot_amqp_index_queue"

  gem.add_dependency "sunspot"
  gem.add_dependency "bunny"
  gem.add_dependency "activesupport", ">= 3.0.0"
  gem.add_development_dependency "sunspot_solr"
  gem.add_development_dependency "rspec"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "sunspot_amqp_index_queue"
  gem.require_paths = ["lib"]
  gem.version       = Sunspot::AmqpIndexQueue::VERSION
end
