---
layout: page
title: User Guide
---
# User Guide

Here we provide help for users who are new to VirtualBox and using virtual machines.

## Starting ViPER

Following [installation](/setup) the normal start up procedure is to open the VirtualBox Manager window, the left side of which will contain the ViPER virtual machine icon which will be in the powered off state.
To start, select the ViPER icon and then the green start arrow on the top menu selecting ‘Normal Start’ - this will open the virtual machine and the ViPER display window.
Note the VirtualBox Manager is also used for managing/configuring VirtualBox settings  - further details can be found on the Oracle VirtualBox user guide.

## Using ViPER

The ViPER desktop environment is [{{ site.data.vars.desktop }}](https://mate-desktop.org/), themed with [{{ site.data.vars.desktop_theme }}](https://linuxmint.com/). It uses a traditional desktop layout, so if you have used Windows or an earlier Linux desktop it should already be familiar: a menu button opens the applications menu, and open windows appear in a taskbar.

The applications menu is the Linux Mint menu. Its **Favourites** pane lists the ViPER preservation tools, so every tool is two clicks away without hunting through categories. The same menu holds the full application list, a search box, and the logout and shutdown controls.

The preservation tools also have icons on the desktop. Double click one to launch it.

A terminal is available from the menu. Every bundled tool has a command line entry point on the `PATH`, and the shell is preconfigured with completion, syntax highlighting and a seeded history of worked ViPER examples, so typing a tool name and pressing the up arrow shows you real invocations. See the [Command Line Reference](../tools/cli.md) for the full set.

### Signing in and shutting down

The machine logs in automatically as `viper`, so you will not normally be asked to sign in. The account is in the `sudo` group so that you can install your own tools, and `sudo` will ask for the account password. That password is supplied with the machine rather than published here; ask the Open Preservation Foundation if you do not have it.

It is there to stop an accidental administrative command, not to secure the machine. Anyone with access to the console, or to a copy of the disk image, effectively has root.

Shut down from the applications menu using **Quit**, and choose **Shut Down**. Prefer this to closing the VirtualBox window, which is the equivalent of pulling the power cable.

### File Sharing

To make best use of the DP tools you will need access to the files located on your normal operational computer (the host). These files will need to be accessed or shared with the  virtual machine (often referred to as the guest). This is a straightforward, VirtualBox control function. The detail covering set up can be found [online here](https://www.virtualbox.org/manual/ch04.html#sharedfolders).

From the VirtualBox Manager:

1. Ensure that the relevant virtual machine is selected - ViPER. The machine should be powered off
2. Select Settings - This is selected via the Settings icon that is by the Start icon or via the pull down selection menu entitled Machine on the left side of the VirtualBox window immediately above the ViPER virtual machine icon
3. Select the Shared Folders menu. A window will appear. The top right will display the Settings icon with the label ViPER Settings. Above the main body of the window the heading ‘Shared Folders’. To the right side of the main window note a + symbol; select the + symbol this will open a further window
4. This new smaller window is entitled ‘Select Share’ - this will be displayed alongside the Settings icon at the top of the window. The window contains 3 main boxes entitled ‘Folder path’, ‘Folder name’ and ‘Mount point’. Two smaller tick boxes entitled ‘Read only’ and ‘Auto mount’ will also be visible
5. Select Folder path that will allow you to select one of two options. Select ‘Other’
6. A further window will now open that should contain a list of folders located on your host machine. Select the folders that you wish to have access to from your host machine and press ‘Select Folder’. The folders window will close and bring you back to the preceding Select Share window
7. The Select Share window will automatically define the path of the host folder selected. It is recommended that you tick the ‘Read only’ box, this will ensure that you do not inadvertently overwrite a file or folder on the host machine whilst using it on the guest machine.
8. Enable Auto Mount’ - now select ‘OK’
9. Start the ViPER virtual machine - note the new shared folders icon in the virtual machine window

## Using the tools

Once ViPER and the shared folders are set up, the tools are ready to use. But what tool to start with, and which one to use with what goal in mind? The OPF developed a Reference Workflow for digital preservation consisting of the following steps:

- Identification: identify file formats and versions (to be stored as technical metadata). Tool:
  - DROID
- Validation: determine the level of compliance of a digital object to the relevant format specification. Tools:
  - JHOVE (AIF, GIF, GZ, HTML, JPG, JPEG2000, PDF, TIFF, WARC, WAV, XML, EPUB, MP3, ZIP)
  - veraPDF (PDF/A)
  - MediaConch (AV files, specifically Matroska and FFV1)
- Charactarization /  Metadata extraction: determine the format-specific significant properties of an object of a given format. Tools:
  - Apache Tika (over a thousand different file types)
  - MediaInfo (audio, video, subtitles)
- Other, conversion-related tools included in ViPER are:
  - HandBrake, for converting video from nearly any format to a selection of modern, widely supported codecs
  - InkScape, image manipulation software
  - GIMP, image manipulation software

For an overview of all tools bundled in ViPER and their specific uses, visit the [Tool Reference guide](../tools/).
