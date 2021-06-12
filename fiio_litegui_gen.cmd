@echo off
cd go_litegui_gen
go run %~n0.go
set<nul /P=Press any key to close...
pause>nul
