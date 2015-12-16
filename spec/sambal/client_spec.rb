# coding: UTF-8

require 'spec_helper'
require 'tempfile'

describe Sambal::Client do

  before(:all) do
    @sambal_client = described_class.new(host: test_server.host, share: test_server.share_name, port: test_server.port)
    @test_directory_with_space_in_name = 'my dir with spaces in name'
    @test_file_in_directory_with_space_in_name = 'a_file_in_a_dir_with_spaces_in_name'

    @test_spaces_in_name_path = "#{@test_directory_with_space_in_name}/#{@test_file_in_directory_with_space_in_name}"

    @test_directory = 'testdir'

    @test_sub_directory = 'testdir_sub'

    @sub_directory_path = "#{@test_directory}/#{@test_sub_directory}"

    @testfile = 'testfile.txt'

    @testfile2 = 'testfile.tx'

    @testfile3 = 'testfil.txt'

    @testfile_sub = 'testfile_sub.txt'

    @testfile_sub_path = "#{@sub_directory_path}/#{@testfile_sub}"
  end

  before(:each) do
    File.open("#{test_server.share_path}/#{@testfile}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{@test_directory_with_space_in_name}"
    File.open("#{test_server.share_path}/#{@test_directory_with_space_in_name}/#{@test_file_in_directory_with_space_in_name}", 'w') do |f|
      f << "Hello there"
    end
    FileUtils.mkdir_p "#{test_server.share_path}/#{@test_directory}"
    FileUtils.mkdir_p "#{test_server.share_path}/#{@test_directory}/#{@test_sub_directory}"
    File.open("#{test_server.share_path}/#{@test_directory}/#{@test_sub_directory}/#{@testfile_sub}", 'w') do |f|
      f << "Hello"
    end
    FileUtils.chmod 0775, "#{test_server.share_path}/#{@test_directory_with_space_in_name}/#{@test_file_in_directory_with_space_in_name}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{@test_directory}/#{@test_sub_directory}/#{@testfile_sub}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{@test_directory}/#{@test_sub_directory}"
    FileUtils.chmod 0775, "#{test_server.share_path}/#{@test_directory}"
    FileUtils.chmod 0777, "#{test_server.share_path}/#{@testfile}"
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
      FileUtils.cp "#{test_server.share_path}/#{@testfile}", "#{test_server.share_path}/#{@testfile2}"
      FileUtils.cp "#{test_server.share_path}/#{@testfile}", "#{test_server.share_path}/#{@testfile3}"
    end

    it "should list files with spaces in their names" do
      result = @sambal_client.ls
      expect(result).to have_key(@test_directory_with_space_in_name)
    end

    it "should list files on an smb server" do
      result = @sambal_client.ls
      expect(result).to have_key(@testfile)
      expect(result).to have_key(@testfile2)
      expect(result).to have_key(@testfile3)
    end

    it "should list files using a wildcard on an smb server" do
      result = @sambal_client.ls '*.txt'
      expect(result).to have_key(@testfile)
      expect(result).to_not have_key(@testfile2)
      expect(result).to have_key(@testfile3)
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

  it "should get files from an smb server" do
    expect(@sambal_client.get(@testfile, "/tmp/sambal_spec_testfile.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_spec_testfile.txt")).to eq true
    expect(File.size("/tmp/sambal_spec_testfile.txt")).to eq @sambal_client.ls[@testfile][:size].to_i
  end

  it "should get files in a dir with spaces in it's name from an smb server" do
    expect(@sambal_client.get(@test_spaces_in_name_path, "/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to eq true
    @sambal_client.cd(@test_directory_with_space_in_name)
    expect(File.size("/tmp/sambal_this_file_was_in_dir_with_spaces.txt")).to eq @sambal_client.ls[@test_file_in_directory_with_space_in_name][:size].to_i
  end

  it "should get files in a subdirectory while in a higher level directory from an smb server" do
    expect(@sambal_client.get(@testfile_sub_path, "/tmp/sambal_spec_testfile_sub.txt")).to be_successful
    expect(File.exists?("/tmp/sambal_spec_testfile_sub.txt")).to eq true
    @sambal_client.cd(@sub_directory_path)
    expect(File.size("/tmp/sambal_spec_testfile_sub.txt")).to eq @sambal_client.ls[@testfile_sub][:size].to_i
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
    expect(@sambal_client.del(@testfile)).to be_successful
    expect(@sambal_client.ls).to_not have_key(@testfile)
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
    expect(@sambal_client.cd(@test_directory)).to be_successful
    expect(@sambal_client.ls).to_not have_key('dirtest.txt')
    expect(@sambal_client.put_content("in #{@test_directory}", 'intestdir.txt')).to be_successful
    expect(@sambal_client.ls).to have_key('intestdir.txt')
    expect(@sambal_client.cd('..')).to be_successful
    expect(@sambal_client.ls).to_not have_key('intestdir.txt')
    expect(@sambal_client.ls).to have_key('dirtest.txt')
  end

  it "should delete files in subdirectory while in a higher level directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(@test_directory)
    expect(@sambal_client.put_content("some content", "file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.del("#{@test_directory}/file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.ls).to have_key("#{@testfile}")
  end

  it "should recursively delete a directory" do
    @sambal_client.cd('/')
    @sambal_client.cd(@test_directory)
    expect(@sambal_client.put_content("some content", "file_to_delete")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.rmdir("#{@test_directory}")).to be_successful
    @sambal_client.cd('/')
    expect(@sambal_client.ls).to_not have_key("#{@test_directory}")
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

end
