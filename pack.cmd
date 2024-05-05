@echo off
if exist res rmdir /Q/S res
if exist changes_generated rmdir /Q/S changes_generated
pushd go_litegui_gen
go run main.go
popd
for %%v in (1.4 2.0) do if exist unpacked_original_%%v (
    xcopy unpacked_original_%%v res /Q/S/I /EXCLUDE:pack\exclude_original.txt
    if errorlevel 1 set /P= unpacked_original_%%v

    rem Copy without themes 2 to 6, because we will superimpose them explicitly.
    xcopy changes_edited res /Q/S/Y /EXCLUDE:pack\exclude_partial.txt
    if errorlevel 1 set /P= changes_edited
    xcopy changes_generated res /Q/S/Y
    if errorlevel 1 set /P= changes_generated
    for %%t in (2 3 4 5 6) do (
        xcopy res\litegui\theme1 res\litegui\theme%%t /Q/S/I
        if errorlevel 1 set /P= res\litegui\theme1
        xcopy changes_edited\litegui\theme%%t res\litegui\theme%%t /Q/S/I/Y
        if errorlevel 1 set /P= changes_edited\litegui\theme%%t
    )

    if %%v == 1.4 for %%t in (1 2 3 4 5 6) do (
        mkdir res\litegui\theme%%t\category\main
        mkdir res\litegui\theme%%t\m3u\main
        mkdir res\litegui\theme%%t\m3u\menu
        copy changes_edited\litegui\theme1\bg\wallpaper.png res\litegui\theme%%t\category\menu\bg.png
        if errorlevel 1 set /P= changes_edited\litegui\bg\wallpaper.png
        for %%n in (category\menu\line category\menu\line_s m3u\long_menu_bg msg\bg_base msg\dock_insert msg\dock_remove msg\full msg\lock msg\low msg\none number\L number\R) do (
            copy changes_edited\litegui\theme1\eq\slider.png res\litegui\theme%%t\%%n.png
            if errorlevel 1 set /P= changes_edited\litegui\theme1\eq\slider.png @ theme%%t\%%n.png
        )
        for %%n in (bg album album_s all all_s artist artist_s collect collect_s genre genre_s) do (
            copy res\litegui\theme%%t\category\menu\%%n.png res\litegui\theme%%t\category\main\
            if errorlevel 1 set /P= res\litegui\theme%%t\category\menu\%%n.png
        )
        xcopy res\litegui\theme%%t\category\menu\playlist*.png res\litegui\theme%%t\m3u\main\ /Y
        if errorlevel 1 set /P= res\litegui\theme%%t\category\menu\playlist*.png
        move res\litegui\theme%%t\category\menu\playlist*.png res\litegui\theme%%t\m3u\menu\
        if errorlevel 1 set /P= res\litegui\theme%%t\category\menu\playlist*.png
        move res\litegui\theme%%t\list\collect.png res\litegui\theme%%t\collect\collect0.png
        if errorlevel 1 set /P= res\litegui\theme%%t\list\collect.png
        move res\litegui\theme%%t\list\collect_s.png res\litegui\theme%%t\collect\collect1.png
        if errorlevel 1 set /P= res\litegui\theme%%t\list\collect_s.png
        move res\litegui\theme%%t\list\m3u.png res\litegui\theme%%t\m3u\playlist.png
        if errorlevel 1 set /P= res\litegui\theme%%t\list\m3u.png res\litegui\theme%%t\m3u\playlist.png
        move res\litegui\theme%%t\playing\playing_menu_add?.png res\litegui\theme%%t\m3u\
        if errorlevel 1 set /P= res\litegui\theme%%t\playing\playing_menu_add?.png
        for %%n in (category\menu\recent category\menu\recent_s list\album_s list\artist_s list\dir_s list\genre_s list\m3u_s list\recent list\recent_s play_settings\single_play playing\single_play0 playing\single_play1)do (
            if exist res\litegui\theme%%t\%%n.png del res\litegui\theme%%t\%%n.png
            if errorlevel 1 set /P= res\litegui\theme%%t\%%n.png
        )
    )
    if %%v == 2.0 for %%t in (1 2 3 4 5 6) do (
        del res\litegui\theme%%t\playing\black.png
        if errorlevel 1 set /P= res\litegui\playing\black.png
    )

    pack\packtools --pack -o %%v\X3II.fw -m x3ii
    if errorlevel 1 pause

    if %%v == 2.0 if exist pack\eq.ini (
        copy pack\eq.ini res\str\english\
        if errorlevel 1 set /P= pack\eq.ini
        pack\packtools --pack -i res -o X3II.fw -m x3ii
        if errorlevel 1 pause
    )
    if %%v == 1.4 rmdir /Q/S res
    if errorlevel 1 set /P= res
)
rmdir /Q/S changes_generated
if errorlevel 1 set /P= changes_generated
if exist pack\eq.ini if exist X: (
    echo copy X3II.fw X:\
    copy X3II.fw X:\
    if errorlevel 1 set /P= X:
)
