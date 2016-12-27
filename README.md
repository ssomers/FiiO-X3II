## album art
* [Create missing folder.jpg files matching cover.jpg files, scaled down and with a black border so that it is entirely visible, not covering or covered by text, and respecting aspect ratio.](fiio_cover_to_folder.go)
* [Wrapper for the above  so that the console window stays open](fiio_cover_to_folder.cmd)

To run:

* Download and install Go from https://golang.org/dl/
* On the command line:

    go build -ldflags -s fiio_cover_to_folder.go

* Or to build once, so you can copy the program to another system and run it without the Go environment:

    go build -ldflags -s fiio_cover_to_folder.go

## customized firmware
Quite a challenge, probably incomplete steps:
* [Generate part of the graphics into directory "changes_generated".](fiio_litegui_gen.go)
* Open each of the .xcf files in "changes_exported" with GIMP and export as .png file
* Download X3II-FW2.0.zip and place X3II.fw in the working  directory
* Run [unpack](unpack.bat)
* Rename directory "unpacked" to "unpacked_original_2.0"
* Repeat previous 3 steps for firware version 1.4
* Place a copy of packtools.exe in directory pack
* Place a copy of msyh.ttf in directory changes_exported/fonts
* Place a copy if eq.ini in directory pack and edit the equaliser profile names as desired
* Run [pack](pack.bat)
