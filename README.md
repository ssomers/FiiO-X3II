# FiiO-X3II-custom-fw
Scripts helping customisation of the FiiO X3II Digital Audio Player firmware

* [Generate part of the graphics in a folder "litegui".](fiio_litegui_gen.go)
* [Create missing folder.jpg files matching cover.jpg files, scaled down and with a black border so that it is entirely visible, not covering or covered by text, and respecting aspect ratio.](fiio_cover_to_folder.go)
* [Wrapper for the above  so that the console window stays open](fiio_cover_to_folder.cmd)

To run the Go scripts:

* Download and install Go from https://golang.org/dl/
* On the command line:

    go build -ldflags -s fiio_cover_to_folder.go

* Or to build once, so you can copy the program to another system and run it without the Go environment:

    go build -ldflags -s fiio_cover_to_folder.go
