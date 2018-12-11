require 'pry'
require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

class FolderDiff
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'google drive folder diff'.freeze
  CREDENTIALS_PATH = 'auth/credentials.json'.freeze
  TOKEN_PATH = 'auth/token.yaml'.freeze
  SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_METADATA_READONLY

  def initialize
    folder_ids = ARGV
    raise 'There must be two folder IDs as arguments' if folder_ids.count != 2

    @service = Google::Apis::DriveV3::DriveService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize

    run(folder_ids)
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts 'Open the following URL in the browser and enter the ' \
           "resulting code after authorization:\n" + url
      code = STDIN.gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def run(folder_ids)

    folder_first = @service.list_files q: "'#{folder_urls.first}' in parents", fields: 'files/modified_time, files/name'
    folder_second = @service.list_files q: "'#{folder_urls.last}' in parents", fields: 'files/modified_time, files/name'

    folder_first_file_names = folder_first.files.map do |file|
      file.name
    end

    folder_second_file_names = folder_second.files.map do |file|
      file.name
    end

    diff_files = []
    folder_first.files.each do |file1|
      match = folder_second.files.detect do |file2|
        file1.name == file2.name
      end

      if !match.nil? && file1.modified_time != match.modified_time
        diff_files << [file1, match]
      end
    end

    log(diff_files, folder_first_file_names, folder_second_file_names)
  end

  def log(diff_files, folder_first_file_names, folder_second_file_names)
    puts "\e[1mModified Files:\e[22m\n\n"

    diff_files.each do |matches|
      puts "file name: #{matches.first.name}\ntime_in_folder_1: #{matches.first.modified_time}\t time_in_folder_2: #{matches.last.modified_time}\n\n"
    end

    new_files_in_folder_1 = folder_first_file_names - folder_second_file_names
    new_files_in_folder_2 = folder_second_file_names - folder_first_file_names

    puts "\e[1mNew Files:\e[22m\n\n"

    new_files_in_folder_1.each do |file_name|
      puts "File only found in folder1: #{file_name}"
    end

    puts "\n"

    new_files_in_folder_2.each do |file_name|
      puts "File only found in folder2: #{file_name}"
    end
  end
end

FolderDiff.new
