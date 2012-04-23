# coding: UTF-8

ENV['PATH']=ENV['PATH']+':/usr/local/bin/:/usr/local/sbin'

require 'bundler/setup'

lib_path = File.expand_path('../lib', File.dirname(__FILE__))
$:.unshift(lib_path) if File.directory?(lib_path) && !$:.include?(lib_path)

require 'sambal'
require 'sambal/test_server'

RSpec::Matchers.define :be_successful do
  match do |actual|
    actual.success?.should be_true
  end
end

module TestServer
  def test_server
    $test_server
  end
end

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec
  
  ## perhaps this should be removed as well
  ## and done in Rakefile?
  config.color_enabled = true
  ## dont do this, do it in Rakefile instead
  #config.formatter = 'd'

  config.before(:suite) do
    $test_server = Sambal::TestServer.new
    $test_server.start
  end

  config.after(:suite) do
    $test_server.stop! ## removes any created directories
  end

  config.include TestServer

end
