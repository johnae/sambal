# encoding: UTF-8

require 'logger'
require 'pty'
require 'expect'

module Sambal
  class Client

    attr_reader :connected

    def parsed_options(user_options)
      default_options = {
        domain: 'WORKGROUP',
        host: '127.0.0.1',
        share: '',
        user: 'guest',
        password: false,
        port: 445,
        timeout: 10,
        columns: 80
      }

      options = default_options.merge(user_options)
      options[:ip_address] ||= options[:host] if options[:host] == default_options[:host]
      options
    end

    def initialize(user_options={})
      begin
        options = parsed_options(user_options)
        @timeout = options[:timeout].to_i

        option_flags = "-W \"#{options[:domain]}\" -U \"#{options[:user]}\""
        option_flags = "#{option_flags} -I #{options[:ip_address]}" if options[:ip_address]
        option_flags = "#{option_flags} -p #{options[:port]} -s /dev/null"
        password = options[:password] ? "'#{options[:password]}'" : "--no-pass"
        command = "COLUMNS=#{options[:columns]} smbclient \"//#{options[:host]}/#{options[:share]}\" #{password}"

        @output, @input, @pid = PTY.spawn(command + ' ' + option_flags)

        res = @output.expect(/(.*\n)?smb:.*\\>/, @timeout)[0] rescue nil
        @connected = case res
        when nil
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
          raise 'Failed to connect'
        end
      rescue => e
        raise RuntimeError, "Unknown Process Failed!! (#{$!.to_s}): #{e.message.inspect}\n"+e.backtrace.join("\n")
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

    def exists?(path)
      ls(path).key? File.basename(path)
    end

    def cd(dir)
      response = ask("cd \"#{dir}\"")
      if response.split("\r\n").join('') =~ /NT_STATUS_OBJECT_NAME_NOT_FOUND/
        Response.new(response, false)
      else
        Response.new(response, true)
      end
    end

    def get(filename, output)
      begin
        file_context(filename) do |file|
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

    def rename(old_filename, new_filename)
      response = ask_wrapped 'rename', [old_filename, new_filename]
      if response =~ /renaming\sfile/ # "renaming" reponse only exist if has error
        Response.new(response, false)
      else
        Response.new(response, true)
      end
    rescue InternalError => e
      Response.new(e.message, false)
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

    def mkdir(directory)
      return Response.new('directory name is empty', false) if directory.strip.empty?
      response = ask_wrapped('mkdir', directory)
      if response =~ /NT_STATUS_OBJECT_NAME_(INVALID|COLLISION)/
        Response.new(response, false)
      else
        Response.new(response, true)
      end
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

    def del(filename)
      begin
        file_context(filename) do |file|
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
      @input.close
      @output.close
      Process.wait(@pid)
      @connected = false
    end

    def ask(cmd)
      @input.printf("#{cmd}\n")
      response = @output.expect(/^smb:.*\\>/,@timeout)[0] rescue nil
      if response.nil?
        $stderr.puts "Failed to do #{cmd}"
        raise "Failed to do #{cmd}"
      else
        response
      end
    end

    def ask_wrapped(cmd,filenames)
      ask wrap_filenames(cmd,filenames)
    end

    def wrap_filenames(cmd,filenames)
      filenames = [filenames] unless filenames.kind_of?(Array)
      filenames.map!{ |filename| "\"#{filename}\"" }
      [cmd,filenames].flatten.join(' ')
    end

    # Parse output from Client#ls
    # Returns Hash of file names with meta information
    def parse_files(str)
      listing = str.each_line.inject({}) do |files, line|
        line.strip!
        name = line[/.*(?=\b\s+[ABDHNRS]+\s+\d+)/]
        name ||= line[/^\.\.|^\./]

        if name
          line.sub!(name, '')
          line.strip!

          type = line[0] == "D" ? :directory : :file
          size = line[/\d+/]

          date = line[/(?<=\d  )\D.*$/]
          modified = (Time.parse(date) rescue "!!#{date}")

          files[name] = {
            type: type,
            size: size,
            modified: modified
          }
        end
        files
      end
      Hash[listing.sort]
    end
  end
end
