# coding: UTF-8

ENV['PATH']=ENV['PATH']+':/usr/local/bin/:/usr/local/sbin'

require 'bundler/setup'

lib_path = File.expand_path('../lib', File.dirname(__FILE__))
$:.unshift(lib_path) if File.directory?(lib_path) && !$:.include?(lib_path)

require 'sambal'

FileUtils.rm_rf "/tmp/sambal_spec/samba"
FileUtils.mkdir_p "/tmp/sambal_spec/samba/"

spec_path = File.expand_path('./', File.dirname(__FILE__))

SAMBA_SHARE = "#{spec_path}/sambashare"
SAMBA_CONF = "#{spec_path}/smb.conf"

FileUtils.rm_rf SAMBA_SHARE
FileUtils.mkdir_p SAMBA_SHARE
#
require "erb"
#
class Hash
  def to_binding(object = Object.new)
    object.instance_eval("def binding_for(#{keys.join(",")}) binding end")
    object.binding_for(*values)
  end
end

class Document
  def initialize(template)
    @template = ERB.new(template)
  end
  
  def interpolate(replacements = {})
    @template.result(replacements.to_binding)
  end
end
#

File.open(SAMBA_CONF, 'w') do |f|
  f << Document.new(IO.binread("#{spec_path}/smb.conf.erb")).interpolate(samba_share: SAMBA_SHARE, local_user: ENV['USER'])
end

RSpec::Matchers.define :be_successful do
  match do |actual|
    actual.success?.should be_true
  end
end

#
#

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
end
