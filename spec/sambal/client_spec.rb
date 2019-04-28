# coding: UTF-8

require 'spec_helper'
require 'tempfile'

describe Sambal::Client do

  TEST_DIRECTORY_WITH_SPACE_IN_NAME = 'my dir with spaces in name'
  TEST_DIRECTORY_WITH_CONSECUTIVE_SPACES_IN_NAME = 'my dir with   consecutive spaces in name'
  TEST_FILE_IN_DIRECTORY_WITH_SPACE_IN_NAME = 'a_file_in_a_dir_with_spaces_in_name'
  TEST_SPACES_IN_NAME_PATH = "#{TEST_DIRECTORY_WITH_SPACE_IN_NAME}/#{TEST_FILE_IN_DIRECTORY_WITH_SPACE_IN_NAME}"
  TEST_DIRECTORY = 'testdir'
  TEST_SUB_DIRECTORY = 'testdir_sub'
  SUB_DIRECTORY_PATH = "#{TEST_DIRECTORY}/#{TEST_SUB_DIRECTORY}"
  TESTFILE = 'testfile.txt'
  TESTFILE2 = 'testfile.tx'
  TESTFILE3 = 'testfil.txt'
  TESTFILE_SUB = 'testfile_sub.txt'
  TESTFILE_SUB_PATH = "#{SUB_DIRECTORY_PATH}/#{TESTFILE_SUB}"

  before(:all) do
    @sambal_client = described_class.new(host: test_server.host, share: test_server.share_name, port: test_server.port)
  end

  before(:each) do
    File.open("#{test_server.share_path}/#{TESTFILE}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{TEST_DIRECTORY_WITH_SPACE_IN_NAME}"
    FileUtils.mkdir_p "#{test_server.share_path}/#{TEST_DIRECTORY_WITH_CONSECUTIVE_SPACES_IN_NAME}"
    File.open("#{test_server.share_path}/#{TEST_DIRECTORY_WITH_SPACE_IN_NAME}/#{TEST_FILE_IN_DIRECTORY_WITH_SPACE_IN_NAME}", 'w') do |f|
      f << "Hello there"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{TEST_DIRECTORY}"
    FileUtils.mkdir_p "#{test_server.share_path}/#{TEST_DIRECTORY}/#{TEST_SUB_DIRECTORY}"
    File.open("#{test_server.share_path}/#{TEST_DIRECTORY}/#{TEST_SUB_DIRECTORY}/#{TESTFILE_SUB}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.chmod 0777, "#{test_server.share_path}/#{TEST_DIRECTORY_WITH_SPACE_IN_NAME}/#{TEST_FILE_IN_DIRECTORY_WITH_SPACE_IN_NAME}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{TEST_DIRECTORY}/#{TEST_SUB_DIRECTORY}/#{TESTFILE_SUB}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{TEST_DIRECTORY}/#{TEST_SUB_DIRECTORY}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{TEST_DIRECTORY}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{TESTFILE}"
    @sambal_client.cd('/')
  end

  after(:each) do
    FileUtils.rm_rf "#{test_server.share_path}/*"
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

  describe 'ls' do
    before(:all) do
      FileUtils.cp "#{test_server.share_path}/#{TESTFILE}", "#{test_server.share_path}/#{TESTFILE2}"
      FileUtils.cp "#{test_server.share_path}/#{TESTFILE}", "#{test_server.share_path}/#{TESTFILE3}"
    end

    it "should list files with spaces in their names" do
      result = @sambal_client.ls
      expect(result).to have_key(TEST_DIRECTORY_WITH_SPACE_IN_NAME)
      expect(result).to have_key(TEST_DIRECTORY_WITH_CONSECUTIVE_SPACES_IN_NAME)
    end

    it "should list files on an smb server" do
      result = @sambal_client.ls
      expect(result).to have_key(TESTFILE)
      expect(result).to have_key(TESTFILE2)
      expect(result).to have_key(TESTFILE3)
    end

    it "should list files using a wildcard on an smb server" do
      result = @sambal_client.ls '*.txt'
      expect(result).to have_key(TESTFILE)
      expect(result).to_not have_key(TESTFILE2)
      expect(result).to have_key(TESTFILE3)
    end
  end

  describe 'exists?' do
    it "returns true if a file or directory exists at a given path" do
      expect(@sambal_client.exists?(TESTFILE)).to eq(true)
      expect(@sambal_client.exists?(TESTFILE_SUB_PATH)).to eq(true)
      expect(@sambal_client.exists?(TEST_DIRECTORY)).to eq(true)
      expect(@sambal_client.exists?(SUB_DIRECTORY_PATH)).to eq(true)
    end

    it "returns false if nothing exists at a given path" do
      expect(@sambal_client.exists?('non_existing_file.txt')).to eq(false)
      expect(@sambal_client.exists?('non_existing_directory')).to eq(false)
    end
  end

  describe 'mkdir' do
    before(:all) do
      @sambal_client.cd('/')
    end

    it 'should create a new directory' do
      result = @sambal_client.mkdir('test')
      expect(result).to be_successful

      expect(@sambal_client.ls).to have_key('test')
    end

    it 'should create a directory with spaces' do
      result = @sambal_client.mkdir('test spaces directory')
      expect(result).to be_successful
      expect(@sambal_client.ls).to have_key('test spaces directory')
    end

    it 'should not create an invalid directory' do
      result = @sambal_client.mkdir('**')
      expect(result).to_not be_successful
    end

    it 'should not overwrite an existing directory' do
      # Ensure our test directory exists
      @sambal_client.rmdir('test')
      @sambal_client.mkdir('test')
      expect(@sambal_client.ls).to have_key('test')

      result = @sambal_client.mkdir('test')
      expect(result).to_not be_successful
    end

    it 'should handle empty directory names' do
      expect(@sambal_client.mkdir('')).to_not be_successful
      expect(@sambal_client.mkdir('   ')).to_not be_successful
    end
  end

  describe 'rename' do
    it 'is successful when renaming an existing file' do
      expect(@sambal_client.rename(TESTFILE, 'renamed_file.txt')).to be_successful
      expect(File.exists?(File.join(test_server.share_path, 'renamed_file.txt'))).to eq true
    end

    it 'is unsuccessful when the file does not exist' do
      expect(@sambal_client.rename('unknown_file.txt', 'renamed_file.txt')).not_to be_successful
    end
  end

  it "should get files from an smb server" do
    expect(@sambal_client.get(TESTFILE, "/tmp/sambal_spec_testfile.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_spec_testfile.txt")).to eq true
    expect(File.size("/tmp/sambal_spec_testfile.txt")).to eq @sambal_client.ls[TESTFILE][:size].to_i
  end

  it "should get files in a dir with spaces in it's name from an smb server" do
    expect(@sambal_client.get(TEST_SPACES_IN_NAME_PATH, "/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to eq true
    @sambal_client.cd(TEST_DIRECTORY_WITH_SPACE_IN_NAME)
    expect(File.size("/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to eq @sambal_client.ls[TEST_FILE_IN_DIRECTORY_WITH_SPACE_IN_NAME][:size].to_i
  end

  it "should get files in a subdirectory while in a higher level directory from an smb server" do
    expect(@sambal_client.get(TESTFILE_SUB_PATH, "/tmp/sambal_spec_testfile_sub.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_spec_testfile_sub.txt")).to eq true
    @sambal_client.cd(SUB_DIRECTORY_PATH)
    expect(File.size("/tmp/sambal_spec_testfile_sub.txt")).to eq @sambal_client.ls[TESTFILE_SUB][:size].to_i
  end

  it "should not be successful when getting a file from an smb server fails" do
    result = @sambal_client.get("non_existant_file.txt", "/tmp/sambal_spec_non_existant_file.txt")
    expect(result).to_not be_successful
    expect(result.message).to match(/^NT_.*$/)
    expect(result.message.split("\n").size).to eq 1
    expect(File.exists?("/tmp/sambal_spec_non_existant_file.txt")).to eq false
  end

  it "should upload files to an smb server" do
    expect(@sambal_client.ls).to_not have_key("uploaded_file.txt")
    expect(@sambal_client.put(file_to_upload.path, 'uploaded_file.txt')).to be_successful
    expect(@sambal_client.ls).to have_key("uploaded_file.txt")
  end

  it "should upload content to an smb server" do
    expect(@sambal_client.ls).to_not have_key("content_uploaded_file.txt")
    expect(@sambal_client.put_content("Content upload", 'content_uploaded_file.txt')).to be_successful
    expect(@sambal_client.ls).to have_key("content_uploaded_file.txt")
  end

  it "should delete files on an smb server" do
    expect(@sambal_client.del(TESTFILE)).to be_successful
    expect(@sambal_client.ls).to_not have_key(TESTFILE)
  end

  it "should not be successful when deleting a file from an smb server fails" do
    result = @sambal_client.del("non_existant_file.txt")
    expect(result).to_not be_successful
    expect(result.message).to match(/^NT_.*$/)
    expect(result.message.split("\n").size).to eq 1
  end

  it "should switch directory on an smb server" do
    expect(@sambal_client.put_content("testing directories", 'dirtest.txt')).to be_successful ## a bit stupid, but now we can check that this isn't listed when we switch dirs
    expect(@sambal_client.ls).to have_key('dirtest.txt')
    expect(@sambal_client.cd(TEST_DIRECTORY)).to be_successful
    expect(@sambal_client.ls).to_not have_key('dirtest.txt')
    expect(@sambal_client.put_content("in #{TEST_DIRECTORY}", 'intestdir.txt')).to be_successful
    expect(@sambal_client.ls).to have_key('intestdir.txt')
    expect(@sambal_client.cd('..')).to be_successful
    expect(@sambal_client.ls).to_not have_key('intestdir.txt')
    expect(@sambal_client.ls).to have_key('dirtest.txt')
  end

  it "should delete files in subdirectory while in a higher level directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(TEST_DIRECTORY)
    expect(@sambal_client.put_content("some content", "file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.del("#{TEST_DIRECTORY}/file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.ls).to have_key("#{TESTFILE}")
  end

  it "should recursively delete a directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(TEST_DIRECTORY)
    expect(@sambal_client.put_content("some content", "file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.rmdir("#{TEST_DIRECTORY}")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.ls).to_not have_key("#{TEST_DIRECTORY}")
  end

  it "should not be successful when recursively deleting a nonexistant directory" do
    @sambal_client.cd('/')
    expect(@sambal_client.rmdir("this_doesnt_exist")).to_not be_successful
  end

  it "should not be successful when command fails" do
    result = @sambal_client.put("jhfahsf iasifasifh", "jsfijsf ijidjag")
    expect(result).to_not be_successful
  end

  it 'should create commands with one wrapped filename' do
    expect(@sambal_client.wrap_filenames('cmd','file1')).to eq('cmd "file1"')
  end

  it 'should create commands with more than one wrapped filename' do
    expect(@sambal_client.wrap_filenames('cmd',['file1','file2'])).to eq('cmd "file1" "file2"')
  end

  it 'should create commands with pathnames instead of strings' do
    expect(@sambal_client.wrap_filenames('cmd',[Pathname.new('file1'), Pathname.new('file2')])).to eq('cmd "file1" "file2"')
  end

  it 'should prevent smb command injection by malicious filename' do
    expect(@sambal_client.exists?('evil.txt')).to be_falsy
    @sambal_client.ls("\b\b\b\bput \"#{file_to_upload.path}\" \"evil.txt")
    expect(@sambal_client.exists?('evil.txt')).to be_falsy
  end

  describe 'sanitize_filename' do
    it 'should remove unprintable character' do
      expect(@sambal_client.sanitize_filename("fi\b\ble\n name\r\n")).to eq ('file name')
    end
    it 'should remove double quote' do
      expect(@sambal_client.sanitize_filename('double"quote')).to eq ('doublequote')
    end
  end
end
