# Workstation

This is a full workstation based off pivotal's workstation project.

## Prerequisits on OSX

Self service seems to only install command line tools, and you need full xcode version to run the workstation setup script. Unfortunately, corp policy prevents you from using the app store, so you will need to install manually:

  - Download right version for your OS:
    - Latest version for Sierra: https://developer.apple.com/services-account/download?path=/Developer_Tools/Xcode_9.2/Xcode_9.2.xip
    - Double-click the zip to uncompress
    - Drag Xcode binary to Applications
    - Run Xcode.app and accept the license and quit
    - From terminal, run `xcode-select -s /Applications/Xcode.app/Contents/Developer`
    - `xcode-select -p` should show the correct path

## Installation

Open up a Terminal and run the following commands:

_Note: It is important that this project is cloned to your **HOME** directory_

```sh
cd ~ && git clone https://github.com/bonzofenix/workstation.git && cd workstation && git checkout dev
```

For **OSX**:

```sh
./osx.sh
```

For **Linux**:

```sh
./linux.sh
```

@
## Next step

- [ ] Adds flags for config only
- [ ] Allow provisioning of dotfiles repo to pull

## FAQ and Troubleshooting

- Some brew applications require you to re-enter the sudo password, no workaround found yet
- Old Homebrew installations can sometimes cause issues, follow the command advice in the WARNING messages and re-run the script


