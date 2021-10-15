Stuff to create a customized firmware for the FiiO X3II Digital Audio Player, and to shape album art for the same device. Binaries (somewhat unconventionally) published as releases.

## Customized firmware
The last regular firmware version of the FiiO X3II digital audio player is [2.0 at FiiO's site](http://fiio.net/en/story/455). An interesting previous version is [1.4, the last with OTG support](http://www.fiio.me/forum.php?mod=viewthread&tid=40827) (adding storage on the USB port, which is not officially supported but works for most).
 
[FiiO allows the firmwares to be customised](http://fiio.me/forum.php?mod=viewthread&tid=41293) with alternative images and graphical properties (colours, font sizes...).

The [releases tab](https://github.com/ssomers/FiiO-X3II/releases) here lists my own cooked customized firmwares with these high contrast themes:
 1. White/green on black
 2. Same with bigger font
 3. Same with very big font - the biggest that still shows all letters completely
 4. Same with an even taller font - cutting off the tail of lowercase letters g, j, p, q, y.
 5. White/orange/pastel colors in slightly bigger font, with watery progress bar
 6. Same as 5 but with pacman progress bar

### DIY
To generate customized firmware yourself (probably incomplete steps):
* Open each of the .xcf files in "changes_exported" with GIMP and export as .png file
* Download X3II-FW2.0.zip and place X3II.fw in the working directory
* Run unpack.bat
* Rename directory "unpacked" to "unpacked_original_2.0"
* Repeat previous 3 steps for firware version 1.4 (if needed)
* Place a copy of packtools.exe in directory pack
* Place a copy of msyh.ttf in directory changes_exported/fonts
* If desired, place a copy if eq.ini in directory pack and edit the equaliser profile names
* Run pack.bat

By the way, in 2.0, these folders and files are not used at all by the firmware's binary and can be removed:

    litegui/test
    litegui/theme?/list/headset.png
    litegui/theme?/list/lineout.png
    litegui/theme?/m3u/long_menu_bg.png
    litegui/theme?/msg/bg_base.png
    litegui/theme?/msg/dock_insert.png
    litegui/theme?/msg/dock_remove.png
    litegui/theme?/msg/full.png
    litegui/theme?/msg/lock.png
    litegui/theme?/number/L.png
    litegui/theme?/number/R.png
    litegui/theme?/topbar/shade.png

## Organizer

These Powershell scripts set up and maintain parallel directory trees with contents extracted from a source and prepared for the player, on a standard NTFS partition. FLAC files are (manually) converted, more compressed files are hardlinked, cover art is converted, and some files are cut out.

`sync-changes.ps1` initiates and incrementally updates whenever things change in the source tree. You then sync the desintation tree with the player. If you delete a track on the player, and sync back with the destintation folder, `sync-removes.ps1` records the removal in a small text file.

## Shaping album art: fiio_cover_to_folder

This script scales down album art and adds a black border so that the image is entirely visible (whereas the player stretches original, square cover art in such a way that doesn't respect aspect ratio and interferes with displayed information.

Operation:

* The script picks up album art from cover.jpg files. To extract these from the embedded art in audio files, for instance in [Mp3tag](http://www.mp3tag.de/en/) by applying an action group defined with these actions:
 * Export cover to file "cover" (without enabling Export duplicate covers)
 * Remove fields "PICTURE"
* The script doesn't overwrite any files and doesn't write duplicate files. For each cover.jpg, it creates a file folder.jpg if it didn't already exist. If the file does exist, and the contents don't match, it prompts for a resolution.

To run:

* Download and install Go from https://golang.org/dl/
* On the command line:

    cd go_cover_to_folder
    go mod tidy
    go run fiio_cover_to_folder.go

* Or to build once, so you can copy the program to another system and run it without the Go environment:

    go build -ldflags -s fiio_cover_to_folder.go
    
* On Windows, launch a [wrapper](fiio_cover_to_folder.cmd) to avoid the command line and keep the console window open


