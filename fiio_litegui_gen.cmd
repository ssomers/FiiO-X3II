@echo off
pushd go_litegui_gen
go run main.go
popd
set<nul /P=Press any key to close...
pause>nul
