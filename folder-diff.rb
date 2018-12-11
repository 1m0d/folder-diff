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
    folders = [
      {id: folder_ids.first, files: []},
      {id: folder_ids.last, files: []}
    ]

    folders.each do |folder|
      get_all_files_from_folder(folder[:id], folder[:files], '/')
    end

    diff(folders)
  end

  def diff(folders)
    # TODO iterating through both folders overcomplicates things. Simplify!
    folders.each_with_index do |folder, folder_index|
      # find all matching files in other folder, by full path
      folder[:files].each do |source_folder_file|
        match = []
        folders[destination_folder_index(folder_index)][:files].each do |destination_folder_file|
          if source_folder_file[:full_path] == destination_folder_file[:full_path]
            match << source_folder_file << destination_folder_file
            break
          end
        end

        if match.empty?
          puts "-"*100
          puts "'#{source_folder_file[:full_path]}' only present in folder#{folder_index + 1}\n\n"
        elsif match && folder_index == 0 # don't repeat logging modified times on second iteration
          if match.first[:file].modified_time != match.last[:file].modified_time
            puts "-"*100
            puts "'#{match.first[:full_path]}' has been modified:\n"
            puts "modified_time in folder1: #{match.first[:file].modified_time}, in folder2: #{match.last[:file].modified_time}\n\n"
          end
        end
      end
    end
  end

  def destination_folder_index(x)
    return (-x + 1) # 0->1, 1->0
  end

  def get_all_files_from_folder(id, file_list, path)
    root_files = (@service.list_files q: "'#{id}' in parents", fields: 'files/modified_time, files/name, files/mimeType, files/id').files

    root_files.each do |file|
      if file.mime_type.include? 'folder'
        sub_path = "#{path}#{file.name}/"
        get_all_files_from_folder(file.id, file_list, sub_path)
      else
        file_list << { file: file, full_path: (path + file.name) }
      end
    end
  end
end

FolderDiff.new
