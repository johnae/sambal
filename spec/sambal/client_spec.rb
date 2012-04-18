# coding: UTF-8

require 'spec_helper'
require 'tempfile'

describe Sambal::Client do

  SMB_PORT = 2321
  SHARE_NAME = 'spec'

  def smbd_pids
    pids = `ps ax | grep smbd | grep #{SMB_PORT} | grep -v grep | awk '{print \$1}'`.chomp
    pids.split("\n").map {|p| (p.nil? || p=='') ? nil : p.to_i }
  end

  def start_smbd
    ## we just start an smb server here for the duration of this spec
    @smb_server_pid = fork do
      `smbd -S -F -s #{SAMBA_CONF} -p 2321`
    end
    sleep 2 ## takes a short time to start up
  end
  
  def stop_smbd
    ## stopping is done in an ugly way now by greping etc - it works
    pids = smbd_pids
    pids.each { |ppid| `kill -9 #{ppid} 2> /dev/null` }
  end

  let(:file_to_upload) do
    t = Tempfile.new('vp6server-smbclient-spec')
    File.open(t.path,'w') do |f|
      f << "Hello from specs"
    end
    t
  end

  let(:test_directory) do
    'testdir'
  end

  let(:testfile) do
    'testfile.txt'
  end

  before(:all) do
    File.open("#{SAMBA_SHARE}/#{testfile}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.mkdir_p "#{SAMBA_SHARE}/#{test_directory}"
    FileUtils.chmod 0775, "#{SAMBA_SHARE}/#{test_directory}"
    FileUtils.chmod 0777, "#{SAMBA_SHARE}/#{testfile}"
    start_smbd
    @sambal_client = described_class.new(host: '127.0.0.1', share: SHARE_NAME, port: SMB_PORT)
  end

  after(:all) do
    @sambal_client.close
    stop_smbd
  end

  it "should list files on an smb server" do
    @sambal_client.ls.should have_key(testfile)
  end

  it "should get files from an smb server" do
    @sambal_client.get(testfile, "/tmp/vp6server_spec_testfile.txt").should == true
    File.exists?("/tmp/vp6server_spec_testfile.txt").should == true
    File.size("/tmp/vp6server_spec_testfile.txt").should == @sambal_client.ls[testfile][:size].to_i
  end

  it "should return false when getting a file from an smb server fails" do
    @sambal_client.get("non_existant_file.txt", "/tmp/vp6server_spec_non_existant_file.txt").should == false
    File.exists?("/tmp/vp6server_spec_non_existant_file.txt").should == false
  end

  it "should upload files to an smb server" do
    @sambal_client.ls.should_not have_key("uploaded_file.txt")
    @sambal_client.put(file_to_upload.path, 'uploaded_file.txt')
    @sambal_client.ls.should have_key("uploaded_file.txt")
  end

  it "should upload content to an smb server" do
    @sambal_client.ls.should_not have_key("content_uploaded_file.txt")
    @sambal_client.put_content("Content upload", 'content_uploaded_file.txt')
    @sambal_client.ls.should have_key("content_uploaded_file.txt")
  end

  it "should delete files on an smb server" do
    @sambal_client.del(testfile).should == true
    @sambal_client.ls.should_not have_key(testfile)
  end

  it "should return false when deleting a file from an smb server fails" do
    @sambal_client.del("non_existant_file.txt").should == false
  end

  it "should switch directory on an smb server" do
    @sambal_client.put_content("testing directories", 'dirtest.txt') ## a bit stupid, but now we can check that this isn't listed when we switch dirs
    @sambal_client.ls.should have_key('dirtest.txt')
    @sambal_client.cd(test_directory)
    @sambal_client.ls.should_not have_key('dirtest.txt')
    @sambal_client.put_content("in #{test_directory}", 'intestdir.txt')
    @sambal_client.ls.should have_key('intestdir.txt')
    @sambal_client.cd('..')
    @sambal_client.ls.should_not have_key('intestdir.txt')
    @sambal_client.ls.should have_key('dirtest.txt')
  end


end