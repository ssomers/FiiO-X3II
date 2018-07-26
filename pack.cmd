@echo off
if exist unpacked_tmp rmdir /Q/S unpacked_tmp
if exist changes_generated rmdir /Q/S changes_generated
go run fiio_litegui_gen.go
for %%v in (1.4 2.0) do if exist unpacked_original_%%v (
    xcopy unpacked_original_%%v unpacked_tmp /Q/S/I /EXCLUDE:pack\exclude_original.txt
    if errorlevel 1 set /P= unpacked_original_%%v

    rem Copy without themes 2,3,4 and 6, because they need to be superimposed
    rem on the customization of theme1 resp. theme5
    xcopy changes_edited unpacked_tmp /Q/S/Y /EXCLUDE:pack\exclude_partial.txt
    if errorlevel 1 set /P= changes_edited
    xcopy changes_generated unpacked_tmp /Q/S/Y
    if errorlevel 1 set /P= changes_generated
    for %%n in (charge number scrollbar theme usb) do (
        xcopy unpacked_tmp\litegui\theme1\%%n unpacked_tmp\litegui\theme5\%%n /Q/S/I
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme1\%%n
    )
    for %%t in (2 3 4) do (
        xcopy unpacked_tmp\litegui\theme1 unpacked_tmp\litegui\theme%%t /Q/S/I
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme1
        copy changes_edited\litegui\theme%%t\config.ini unpacked_tmp\litegui\theme%%t
        if errorlevel 1 set /P= changes_edited changes_edited\litegui\theme%%t\config.ini
    )
    for %%t in (6) do (
        xcopy unpacked_tmp\litegui\theme5 unpacked_tmp\litegui\theme%%t /Q/S/I
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme5
        xcopy changes_edited\litegui\theme%%t unpacked_tmp\litegui\theme%%t /Q/S/Y
        if errorlevel 1 set /P= changes_edited changes_edited\litegui\theme%%t
    )

    if %%v == 1.4 for %%t in (1 2 3 4 5 6) do (
        mkdir unpacked_tmp\litegui\theme%%t\category\main
        mkdir unpacked_tmp\litegui\theme%%t\m3u\main
        mkdir unpacked_tmp\litegui\theme%%t\m3u\menu
        copy changes_edited\litegui\theme1\bg\wallpaper.png unpacked_tmp\litegui\theme%%t\category\menu\bg.png
        if errorlevel 1 set /P= changes_edited\litegui\bg\wallpaper.png
        for %%n in (category\menu\line category\menu\line_s m3u\long_menu_bg msg\bg_base msg\dock_insert msg\dock_remove msg\full msg\lock msg\low msg\none number\L number\R) do (
            copy changes_edited\litegui\theme1\eq\slider.png unpacked_tmp\litegui\theme%%t\%%n.png
            if errorlevel 1 set /P= changes_edited\litegui\theme1\eq\slider.png
        )
        for %%n in (bg album album_s all all_s artist artist_s collect collect_s genre genre_s) do (
            copy unpacked_tmp\litegui\theme%%t\category\menu\%%n.png unpacked_tmp\litegui\theme%%t\category\main\
            if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\category\menu\%%n.png
        )
        xcopy unpacked_tmp\litegui\theme%%t\category\menu\playlist*.png unpacked_tmp\litegui\theme%%t\m3u\main\ /Y
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\category\menu\playlist*.png
        move unpacked_tmp\litegui\theme%%t\category\menu\playlist*.png unpacked_tmp\litegui\theme%%t\m3u\menu\
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\category\menu\playlist*.png
        move unpacked_tmp\litegui\theme%%t\list\collect.png unpacked_tmp\litegui\theme%%t\collect\collect0.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\list\collect.png
        move unpacked_tmp\litegui\theme%%t\list\collect_s.png unpacked_tmp\litegui\theme%%t\collect\collect1.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\list\collect_s.png
        move unpacked_tmp\litegui\theme%%t\list\m3u.png unpacked_tmp\litegui\theme%%t\m3u\playlist.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\list\m3u.png unpacked_tmp\litegui\theme%%t\m3u\playlist.png
        move unpacked_tmp\litegui\theme%%t\playing\playing_menu_add?.png unpacked_tmp\litegui\theme%%t\m3u\
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\playing\playing_menu_add?.png
        for %%n in (category\menu\recent category\menu\recent_s list\album_s list\artist_s list\dir_s list\genre_s list\m3u_s list\recent list\recent_s play_settings\single_play playing\single_play0 playing\single_play1)do (
            if exist unpacked_tmp\litegui\theme%%t\%%n.png del unpacked_tmp\litegui\theme%%t\%%n.png
            if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\%%n.png
        )
    )
    if %%v == 2.0 for %%t in (1 2 3 4 5 6) do (
        for %%n in (list\all playing\black) do (
            del unpacked_tmp\litegui\theme%%t\%%n.png
            if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\%%n.png
        )
    )

    pack\packtools --pack -i unpacked_tmp -o %%v\X3II.fw -m x3ii
    if errorlevel 1 pause

    if %%v == 2.0 if exist pack\eq.ini (
        copy pack\eq.ini unpacked_tmp\str\english\
        if errorlevel 1 set /P= pack\eq.ini
        pack\packtools --pack -i unpacked_tmp -o X3II.fw -m x3ii
        if errorlevel 1 pause
    )
    rmdir /Q/S unpacked_tmp
    if errorlevel 1 set /P= unpacked_tmp
)
rmdir /Q/S changes_generated
if errorlevel 1 set /P= changes_generated
if exist pack\eq.ini if exist X: (
    echo copy X3II.fw X:\
    copy X3II.fw X:\
    if errorlevel 1 set /P= X:
)
