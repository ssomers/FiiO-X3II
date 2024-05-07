Stuff to create a customized firmware for the FiiO X3II Digital Audio Player, and to shape album art for the same device. Binaries (somewhat unconventionally) published as releases.

## Customized firmware
The last regular firmware version of the FiiO X3II digital audio player is [2.0 at FiiO's site](hhttps://forum.fiio.com/firmwareDown.do). An interesting previous version was 1.4, the last with OTG support (adding storage on the USB port, which is not officially supported but apparently works for most - I never tried myself).
 
FiiO allows the firmwares to be customised with alternative images and graphical properties (colours, font sizes… though their explanation on fiio.me has vanished).

The [releases tab](https://github.com/ssomers/FiiO-X3II/releases) here lists my own cooked customized firmwares with these high contrast themes:
 1. to 5. White/green on black with increasing font size (the 5th one so large that the tail of lowercase letters g, j, p, q, y is cut off).
 6. White/orange/pastel colors with pacman progress bar

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

## Content Organizer

These Powershell scripts set up and maintain a parallel directory tree `X3` with contents extracted from a source tree `src` and prepared for the player, on a standard NTFS partition. It converts cover art to fit the middle of the screen, converts FLAC files to top quality M4A, hardlinks already compressed files, optionally mixes down to mono, optionally adds crossfeed, or leaves out files, controlled in an optional file covet.txt.

`sync-changes.ps1` initiates and incrementally updates whenever things are added to the source tree. You then sync the desintation tree with the player. If you delete a track on the player, and sync back with the destintation folder, `sync-removes.ps1` records the removal in a covet.txt file.
If you delete or rename a file in the soruce, or mark to exclude it in a covet.txt file, `sync-drops.ps1` cleans up the `X3` directory.

## Shaping album art

The player stretches original, typically square, cover art in a way that doesn't respect aspect ratio and interferes with displayed information.
So we inset the cover inside a black border with the player's display dimensions (320×240 pixels).

Operation:

* The script picks up album art from cover.jpg, cover.png or cover.webm files. To extract these from the embedded art in audio files, for instance in [Mp3tag](http://www.mp3tag.de/en/) by applying an action group defined with these actions:
 * Export cover to file "cover" (without enabling Export duplicate covers)
 * Remove fields "PICTURE"
