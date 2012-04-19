# coding: UTF-8

require "sambal/version"
require 'open3'
require 'logger'
require 'json'
require 'pty'
require 'expect'
require 'time'
require 'tempfile'

module Sambal

  class InternalError < RuntimeError; end

  class Response

    attr_reader :message

    def initialize(message, success)
      msg = message.split("\n")
      msg.each do |line|
        if line =~ /^NT\_.*\s/
          @message = line
        end
      end
      @message ||= message
      @success = success
    end

    def success?
      @success
    end

    def failure?
      !success?
    end

  end

  class Client
    
    attr_reader :connected
    
    def initialize(options={})
      begin
        options = {domain: 'WORKGROUP', host: '127.0.0.1', share: '', user: 'guest', password: '--no-pass', port: 445}.merge(options)
        @o, @i, @pid = PTY.spawn("smbclient //#{options[:host]}/#{options[:share]} #{options[:password]} -W #{options[:domain]} -U #{options[:user]}, -p #{options[:port]}")
        #@o.set_encoding('UTF-8:UTF-8') ## don't know didn't work, we only have this problem when the files are named using non-english characters
        #@i.set_encoding('UTF-8:UTF-8')
        res = @o.expect(/^smb:.*\\>/, 10)[0]
        @connected = case res
        when /^put/
          res['putting'].nil? ? false : true
        else
          if res['NT_STATUS']
            false
          elsif res['timed out'] || res['Server stopped']
            false
          else
            true
          end
        end
        
        unless @connected
          close if @pid
          exit(1)
        end
      rescue
        raise RuntimeError.exception("Unknown Process Failed!! (#{$!.to_s})")
      end
    end
    
    def ls
      parse_files(ask("ls"))
    end
  
    def cd(dir)
      if response = ask("cd #{dir}")
        Response.new(response, true)
      else
        Response.new(response, false)
      end
    end
  
    def get(file, output)
      response = ask "get #{file} #{output}"
      if response =~ /^getting\sfile.*$/
        Response.new(response, true)
      else
        Response.new(response, false)
      end
    rescue InternalError => e
      Response.new(e.message, false)
    end
  
    def put(file, destination)
      response = ask "put #{file} #{destination}"
      if response =~ /^putting\sfile.*$/
        Response.new(response, true)
      else
        Response.new(response, false)
      end
    rescue InternalError => e
      Response.new(e.message, false)
    end
  
    def put_content(content, destination)
      t = Tempfile.new("upload-smb-content-#{destination}")
      File.open(t.path, 'w') do |f|
        f << content
      end
      response = ask "put #{t.path} #{destination}"
      if response =~ /^putting\sfile.*$/
        Response.new(response, true)
      else
        Response.new(response, false)
      end
    rescue InternalError => e
      Response.new(e.message, false)
    ensure
      t.close
    end
  
    def del(file)
      response = ask "del #{file}"
      next_line = response.split("\n")[1]
      if next_line =~ /^smb:.*\\>/
        Response.new(response, true)
      #elsif next_line =~ /^NT_STATUS_NO_SUCH_FILE.*$/
      #  Response.new(response, false)
      #elsif next_line =~ /^NT_STATUS_ACCESS_DENIED.*$/
      #  Response.new(response, false)
      else
        Response.new(response, false)
      end
    rescue InternalError => e
      Response.new(e.message, false)
    end
  
    def close
      @i.printf("quit\n")
      @connected = false
    end
    
    def ask(cmd)
      @i.printf("#{cmd}\n")
      response = @o.expect(/^smb:.*\\>/,10)[0] rescue nil
      if response.nil?
        $stderr.puts "Failed to do #{cmd}"
        raise Exception.new, "Failed to do #{cmd}"
      else
        response
      end
    end
    
    def parse_files(str)
      files = {}
      str.each_line do |line|
        if line =~ /\s+([\w\.\d\-\_\?\!\s]+)\s+([DAH]?)\s+(\d+)\s+(.+)$/
          lsplit = line.split(/\s+/)
          lsplit.shift ## remove first empty string
          name = lsplit.shift#$1
          if lsplit.first =~ /^[A-Za-z]+$/
            type = lsplit.shift
          else
            type = ""
          end
          size = lsplit.shift#$3
          date = lsplit.join(' ')#$4
          name.gsub!(/\s+$/,'')
          files[name] = if type =~/^D.*$/
            {type: :directory, size: size, modified: (Time.parse(date) rescue "!!#{date}")}
          else
            {type: :file, size: size , modified: (Time.parse(date) rescue "!!#{date}")}
          end
        end
      end
      files
    end
    
  end
end
