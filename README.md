## fiio_cover_to_folder: shaping album art

This script embeds scaled down album art in a black border so that the image is entirely visible, not covering  or covered by the player's information, and respecting aspect ratio.

creates folder.jpg files matching cover.jpg files, 
* [Wrapper for the above  so that the console window stays open](fiio_cover_to_folder.cmd)

Operation:

* The script picks up album art from cover.jpg file, for instance in [Mp3tag](http://www.mp3tag.de/en/) by applying an action group defined with these actions:
 * Export cover to file "cover" (without enabling Export duplicate covers)
 * Remove fields "PICTURE"
* Just like Mp3tag, the script doesn't overwrite any files and doesn't write duplicate files. For each cover.jpg, it creates a file folder.jpg if it didn't already exist. If the file does exist, and the contents don't match, the script creates folder(1).jpg or folder(2).jpg etc. instead, and you'll probably want to sort those out.

To run:

* Download and install Go from https://golang.org/dl/
* On the command line:

    go run fiio_cover_to_folder.go

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
