# FolderDiff
## Prereq
### Turn on the Drive API
1. Go to the [Google API Console](https://console.developers.google.com/)
2. Select/Create a project.
3. In the sidebar on the left, expand APIs & auth and select APIs.
4. In the displayed list of available APIs, click the link for the Drive API and click Enable API.

### Download credentials
1. Select project.
2. Download the configuration file.
3. Move the downloaded file to the program's auth directory and ensure it is named credentials.json.

## Usage
```shell
ruby folder-diff FOLDER_IDS
```
