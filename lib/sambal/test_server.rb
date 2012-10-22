# coding: UTF-8

require "erb"
require "fileutils"

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

module Sambal
  class TestServer

    attr_reader :port
    attr_reader :share_path
    attr_reader :root_path
    attr_reader :config_path
    attr_reader :share_name
    attr_reader :run_as
    attr_reader :host

    def initialize(root_path="/tmp/sambal_test_server_#{Time.now.to_i}", share_name='sambal_test', run_as=ENV['USER'])
      @erb_path = "#{File.expand_path(File.dirname(__FILE__))}/smb.conf.erb"
      @host = "127.0.0.1" ## will always just be localhost
      @root_path = root_path
      @share_path = "#{root_path}/share"
      @share_name = share_name
      @config_path = "#{root_path}/smb.conf"
      @lock_path = "#{root_path}"
      @pid_dir = "#{root_path}"
      @port = Random.new(Time.now.to_i).rand(2345..5678).to_i
      @run_as = run_as
      FileUtils.mkdir_p @share_path
      write_config
    end

    def find_pids
      pids = `ps ax | grep smbd | grep #{@port} | grep -v grep | awk '{print \$1}'`.chomp
      pids.split("\n").map {|p| (p.nil? || p=='') ? nil : p.to_i }
    end

    def write_config
      File.open(@config_path, 'w') do |f|
        f << Document.new(IO.binread(@erb_path)).interpolate(samba_share: @share_path, local_user: @run_as, share_name: @share_name)
      end
    end

    def start
      if RUBY_PLATFORM=="java"
        @smb_server_pid = Thread.new do
          `smbd -S -F -s #{@config_path} -p #{@port} --lockdir=#{@lock_path} --piddir=#{@pid_dir}`
        end
      else
        @smb_server_pid = fork do
          `smbd -S -F -s #{@config_path} -p #{@port} --lockdir=#{@lock_path} --piddir=#{@pid_dir}`
        end
      end
      sleep 2 ## takes a short time to start up
    end

    def stop
      ## stopping is done in an ugly way by grepping
      pids = find_pids
      pids.each { |ppid| `kill -9 #{ppid} 2> /dev/null` }
    end

    def stop!
      stop
      FileUtils.rm_rf @root_path
    end

  end
end