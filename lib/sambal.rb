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
        @o, @i, @pid = PTY.spawn("smbclient //#{options[:host]}/#{options[:share]} #{options[:password]} -W #{options[:domain]} -U #{options[:user]} -p #{options[:port]}")
        #@o.set_encoding('UTF-8:UTF-8') ## don't know didn't work, we only have this problem when the files are named using non-english characters
        #@i.set_encoding('UTF-8:UTF-8')
        res = @o.expect(/^smb:.*\\>/, 10)[0] rescue nil
        @connected = case res
        when nil
          $stderr.puts "Failed to connect"
          false
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
      rescue Exception => e
        raise RuntimeError.exception("Unknown Process Failed!! (#{$!.to_s}): #{e.message.inspect}\n"+e.backtrace.join("\n"))
      end
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def logger=(l)
      @logger = l
    end

    def file_context(path)
      if (path_parts = path.split('/')).length>1
        file = path_parts.pop
        subdirs = path_parts.length
        dir = path_parts.join('/')
        cd dir
      else
        file = path
      end
      begin
        yield(file)
      ensure
        unless subdirs.nil?
          subdirs.times { cd '..' }
        end
      end
    end

    def ls(qualifier = '*')
      parse_files(ask_wrapped('ls', qualifier))
    end

    def cd(dir)
      response = ask("cd \"#{dir}\"")
      if response.split("\r\n").join('') =~ /NT_STATUS_OBJECT_NAME_NOT_FOUND/
        Response.new(response, false)
      else
        Response.new(response, true)
      end
    end

    def get(file, output)
      begin
        file_context(file) do |file|
          response = ask_wrapped 'get', [file, output]
          if response =~ /^getting\sfile.*$/
            Response.new(response, true)
          else
            Response.new(response, false)
          end
        end
      rescue InternalError => e
        Response.new(e.message, false)
      end
    end

    def put(file, destination)
      response = ask_wrapped 'put', [file, destination]
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
      response = ask_wrapped 'put', [t.path, destination]
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

    def rmdir(dir)
      response = cd dir
      return response if response.failure?
      begin
        ls.each do |name, meta|
          if meta[:type]==:file
            response = del name
          elsif meta[:type]==:directory && !(name =~ /^\.+$/)
            response = rmdir(name)
          end
          raise InternalError.new response.message if response && response.failure?
        end
        cd '..'
        response = ask_wrapped 'rmdir', dir
        next_line = response.split("\n")[1]
        if next_line =~ /^smb:.*\\>/
          Response.new(response, true)
        else
          Response.new(response, false)
        end
      rescue InternalError => e
        Response.new(e.message, false)
      end
    end

    def del(file)
      begin
        file_context(file) do |file|
          response = ask_wrapped 'del', file
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
        end
      rescue InternalError => e
        Response.new(e.message, false)
      end
      #end
      #if (path_parts = file.split('/')).length>1
      #  file = path_parts.pop
      #  subdirs = path_parts.length
      #  dir = path_parts.join('/')
      #  cd dir
      #end
    #  response = ask "del #{file}"
    #  next_line = response.split("\n")[1]
    #  if next_line =~ /^smb:.*\\>/
    #    Response.new(response, true)
    #  #elsif next_line =~ /^NT_STATUS_NO_SUCH_FILE.*$/
    #  #  Response.new(response, false)
    #  #elsif next_line =~ /^NT_STATUS_ACCESS_DENIED.*$/
    #  #  Response.new(response, false)
    #  else
    #    Response.new(response, false)
    #  end
    #rescue InternalError => e
    #  Response.new(e.message, false)
    #ensure
    #  unless subdirs.nil?
    #    subdirs.times { cd '..' }
    #  end
    end

    def close
      @i.close
      @o.close
      Process.wait(@pid)
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

    def ask_wrapped(cmd,filenames)
      ask wrap_filenames(cmd,filenames)
    end

    def wrap_filenames(cmd,filenames)
      filenames = [filenames] unless filenames.kind_of?(Array)
      filenames.map!{ |filename| '"' + filename + '"' }
      [cmd,filenames].flatten.join(' ')
    end

    def parse_files(str)
      files = {}
      str.each_line do |line|
        if line =~ /\s+([\w\.\d\-\_\?\!\s]+)\s+([DAH]?)\s+(\d+)\s+(.+)$/
          lsplit = line.split(/\s{2,}/)
          #$stderr.puts "lsplit: #{lsplit}"
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
