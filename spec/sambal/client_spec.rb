# coding: UTF-8

require 'spec_helper'
require 'tempfile'

describe Sambal::Client do

  before(:all) do
    @sambal_client = described_class.new(host: test_server.host, share: test_server.share_name, port: test_server.port)
  end

  before(:each) do
    File.open("#{test_server.share_path}/#{testfile}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{test_directory_with_space_in_name}"
    File.open("#{test_server.share_path}/#{test_directory_with_space_in_name}/#{test_file_in_directory_with_space_in_name}", 'w') do |f|
      f << "Hello there"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{test_directory}"
    FileUtils.mkdir_p "#{test_server.share_path}/#{test_directory}/#{test_sub_directory}"
    File.open("#{test_server.share_path}/#{test_directory}/#{test_sub_directory}/#{testfile_sub}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.chmod 0775, "#{test_server.share_path}/#{test_directory_with_space_in_name}/#{test_file_in_directory_with_space_in_name}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{test_directory}/#{test_sub_directory}/#{testfile_sub}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{test_directory}/#{test_sub_directory}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{test_directory}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{testfile}"
    @sambal_client.cd('/')
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

  let(:test_directory_with_space_in_name) { 'my dir with spaces in name' }

  let(:test_file_in_directory_with_space_in_name) { 'a_file_in_a_dir_with_spaces_in_name' }

  let(:test_spaces_in_name_path) { "#{test_directory_with_space_in_name}/#{test_file_in_directory_with_space_in_name}" }

  let(:test_directory) do
    'testdir'
  end

  let(:test_sub_directory) do
    'testdir_sub'
  end

  let(:sub_directory_path) do
    "#{test_directory}/#{test_sub_directory}"
  end

  let(:testfile) do
    'testfile.txt'
  end

  let(:testfile2) do
    'testfile.tx'
  end

  let(:testfile3) do
    'testfil.txt'
  end

  let(:testfile_sub) do
    'testfile_sub.txt'
  end

  let(:testfile_sub_path) do
    "#{sub_directory_path}/#{testfile_sub}"
  end

  describe 'ls' do
    before(:all) do
      FileUtils.cp "#{test_server.share_path}/#{testfile}", "#{test_server.share_path}/#{testfile2}"
      FileUtils.cp "#{test_server.share_path}/#{testfile}", "#{test_server.share_path}/#{testfile3}"
    end

    it "should list files with spaces in their names" do
      result = @sambal_client.ls
      result.should have_key(test_directory_with_space_in_name)
    end

    it "should list files on an smb server" do
      result = @sambal_client.ls
      result.should have_key(testfile)
      result.should have_key(testfile2)
      result.should have_key(testfile3)
    end

    it "should list files using a wildcard on an smb server" do
      result = @sambal_client.ls '*.txt'
      result.should have_key(testfile)
      result.should_not have_key(testfile2)
      result.should have_key(testfile3)
    end
  end

  it "should get files from an smb server" do
    @sambal_client.get(testfile, "/tmp/sambal_spec_testfile.txt").should be_successful
    File.exists?("/tmp/sambal_spec_testfile.txt").should == true
    File.size("/tmp/sambal_spec_testfile.txt").should == @sambal_client.ls[testfile][:size].to_i
  end

  it "should get files in a dir with spaces in it's name from an smb server" do
    @sambal_client.get(test_spaces_in_name_path, "/tmp/sambal_this_file_was_in_dir_with_spaces.txt").should be_successful
    File.exists?("/tmp/sambal_this_file_was_in_dir_with_spaces.txt").should == true
    @sambal_client.cd(test_directory_with_space_in_name)
    File.size("/tmp/sambal_this_file_was_in_dir_with_spaces.txt").should == @sambal_client.ls[test_file_in_directory_with_space_in_name][:size].to_i
  end

  it "should get files in a subdirectory while in a higher level directory from an smb server" do
    @sambal_client.get(testfile_sub_path, "/tmp/sambal_spec_testfile_sub.txt").should be_successful
    File.exists?("/tmp/sambal_spec_testfile_sub.txt").should == true
    @sambal_client.cd(sub_directory_path)
    File.size("/tmp/sambal_spec_testfile_sub.txt").should == @sambal_client.ls[testfile_sub][:size].to_i
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

  it "should delete files in subdirectory while in a higher level directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(test_directory)
    @sambal_client.put_content("some content", "file_to_delete").should be_successful
    @sambal_client.cd('/')
    @sambal_client.del("#{test_directory}/file_to_delete").should be_successful
    @sambal_client.cd('/')
    @sambal_client.ls.should have_key("#{testfile}")
  end

  it "should recursively delete a directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(test_directory)
    @sambal_client.put_content("some content", "file_to_delete").should be_successful
    @sambal_client.cd('/')
    @sambal_client.rmdir("#{test_directory}").should be_successful
    @sambal_client.cd('/')
    @sambal_client.ls.should_not have_key("#{test_directory}")
  end

  it "should not be successful when recursively deleting a nonexistant directory" do
    @sambal_client.cd('/')
    @sambal_client.rmdir("this_doesnt_exist").should_not be_successful
  end

  it "should not be successful when command fails" do
    result = @sambal_client.put("jhfahsf iasifasifh", "jsfijsf ijidjag")
    result.should_not be_successful
  end

  it 'should create commands with one wrapped filename' do
    @sambal_client.wrap_filenames('cmd','file1').should eq('cmd "file1"')
  end

  it 'should create commands with more than one wrapped filename' do
    @sambal_client.wrap_filenames('cmd',['file1','file2']).should eq('cmd "file1" "file2"')
  end

  it 'should create commands with pathnames instead of strings' do
    @sambal_client.wrap_filenames('cmd',[Pathname.new('file1'), Pathname.new('file2')]).should eq('cmd "file1" "file2"')
  end

end
