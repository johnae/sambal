# coding: UTF-8

require 'spec_helper'
require 'tempfile'

describe Sambal::Client do

  before(:all) do
    File.open("#{test_server.share_path}/#{testfile}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{test_directory}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{test_directory}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{testfile}"
    @sambal_client = described_class.new(host: test_server.host, share: test_server.share_name, port: test_server.port)
  end

  after(:all) do
    @sambal_client.close
  end

  let(:file_to_upload) do
    t = Tempfile.new('sambal-smbclient-spec')
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

  it "should list files on an smb server" do
    @sambal_client.ls.should have_key(testfile)
  end

  it "should get files from an smb server" do
    @sambal_client.get(testfile, "/tmp/sambal_spec_testfile.txt").should be_successful
    File.exists?("/tmp/sambal_spec_testfile.txt").should == true
    File.size("/tmp/sambal_spec_testfile.txt").should == @sambal_client.ls[testfile][:size].to_i
  end

  it "should not be successful when getting a file from an smb server fails" do
    result = @sambal_client.get("non_existant_file.txt", "/tmp/sambal_spec_non_existant_file.txt")
    result.should_not be_successful
    result.message.should match /^NT_.*$/
    result.message.split("\n").should have(1).line
    File.exists?("/tmp/sambal_spec_non_existant_file.txt").should == false
  end

  it "should upload files to an smb server" do
    @sambal_client.ls.should_not have_key("uploaded_file.txt")
    @sambal_client.put(file_to_upload.path, 'uploaded_file.txt').should be_successful
    @sambal_client.ls.should have_key("uploaded_file.txt")
  end

  it "should upload content to an smb server" do
    @sambal_client.ls.should_not have_key("content_uploaded_file.txt")
    @sambal_client.put_content("Content upload", 'content_uploaded_file.txt').should be_successful
    @sambal_client.ls.should have_key("content_uploaded_file.txt")
  end

  it "should delete files on an smb server" do
    @sambal_client.del(testfile).should be_successful
    @sambal_client.ls.should_not have_key(testfile)
  end

  it "should not be successful when deleting a file from an smb server fails" do
    result = @sambal_client.del("non_existant_file.txt")
    result.should_not be_successful
    result.message.should match /^NT_.*$/
    result.message.split("\n").should have(1).line
  end

  it "should switch directory on an smb server" do
    @sambal_client.put_content("testing directories", 'dirtest.txt').should be_successful ## a bit stupid, but now we can check that this isn't listed when we switch dirs
    @sambal_client.ls.should have_key('dirtest.txt')
    @sambal_client.cd(test_directory).should be_successful
    @sambal_client.ls.should_not have_key('dirtest.txt')
    @sambal_client.put_content("in #{test_directory}", 'intestdir.txt').should be_successful
    @sambal_client.ls.should have_key('intestdir.txt')
    @sambal_client.cd('..').should be_successful
    @sambal_client.ls.should_not have_key('intestdir.txt')
    @sambal_client.ls.should have_key('dirtest.txt')
  end

  it "should not be successful when command fails" do
    result = @sambal_client.put("jhfahsf iasifasifh", "jsfijsf ijidjag")
    result.should_not be_successful
  end

end