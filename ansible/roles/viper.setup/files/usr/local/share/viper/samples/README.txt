ViPER sample files
==================

This folder is reachable from the desktop shortcut "Sample Files".

It is shared and read only, so it is a fixed reference set rather than a working
directory. Copy a file into your home folder before editing it, and point the tools
at your own files from anywhere on the system.

The folder ships empty. To add a corpus, drop the files into
ansible/roles/viper.setup/files/usr/local/share/viper/samples/ in the ViPER build
repository and rebuild, or change viper_desktop_folders in
ansible/roles/viper.setup/defaults/main.yml to point the shortcut somewhere else.
