Stuff to create a customized firmware for the FiiO X3II Digital Audio Player, and to shape album art for the same device. Binaries (somewhat unconventionally) published as releases.

## fiio_cover_to_folder: shaping album art

This script scales down album art and adds a black border so that the image is entirely visible (whereas the player stretches original, square cover art in such a way that doesn't respect aspect ratio and interferes with displayed information.

Operation:

* The script picks up album art from cover.jpg files. To extract these from the embedded art in audio files, for instance in [Mp3tag](http://www.mp3tag.de/en/) by applying an action group defined with these actions:
 * Export cover to file "cover" (without enabling Export duplicate covers)
 * Remove fields "PICTURE"
* The script doesn't overwrite any files and doesn't write duplicate files. For each cover.jpg, it creates a file folder.jpg if it didn't already exist. If the file does exist, and the contents don't match, it prompts for a resolution.

To run:

* Download and install Go from https://golang.org/dl/
* On the command line:

    go run fiio_cover_to_folder.go

* Or to build once, so you can copy the program to another system and run it without the Go environment:

    go build -ldflags -s fiio_cover_to_folder.go
    
* On Windows, launch a [wrapper](fiio_cover_to_folder.cmd) to avoid the command line and keep the console window open


## customized firmware
To generate customized firmware (probably incomplete steps):
* [Generate part of the graphics into directory "changes_generated".](fiio_litegui_gen.go)
* Open each of the .xcf files in "changes_exported" with GIMP and export as .png file
* Download X3II-FW2.0.zip and place X3II.fw in the working  directory
* Run [unpack](unpack.bat)
* Rename directory "unpacked" to "unpacked_original_2.0"
* Repeat previous 3 steps for firware version 1.4 (if needed)
* Place a copy of packtools.exe in directory pack
* Place a copy of msyh.ttf in directory changes_exported/fonts
* If desired, place a copy if eq.ini in directory pack and edit the equaliser profile names
* Run [pack](pack.bat)
