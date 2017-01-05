@echo off
for %%v in (1.4 2.0) do if exist unpacked_original_%%v (
    xcopy unpacked_original_%%v unpacked_tmp /Q/S/I /EXCLUDE:pack\exclude_original.txt
    if errorlevel 1 set /P= unpacked_original_%%v
    rem Copy without themes 2,4,5 and 6, because they need to be superimposed
    rem on the customization of theme1 resp. theme3
    xcopy changes_edited unpacked_tmp /Q/S/Y /EXCLUDE:pack\exclude_partial.txt
    if errorlevel 1 set /P= changes_edited
    xcopy changes_exported unpacked_tmp /Q/S/Y /EXCLUDE:pack\exclude_partial.txt
    if errorlevel 1 set /P= changes_exported
    xcopy changes_generated unpacked_tmp /Q/S/Y
    if errorlevel 1 set /P= changes_generated
    for %%n in (charge number scrollbar theme usb) do (
        xcopy unpacked_tmp\litegui\theme1\%%n unpacked_tmp\litegui\theme3\%%n /Q/S/I
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme1\%%n
    )
    xcopy unpacked_tmp\litegui\theme1 unpacked_tmp\litegui\theme2 /Q/S/I
    if errorlevel 1 set /P= unpacked_tmp\litegui\theme1
    xcopy unpacked_tmp\litegui\theme3 unpacked_tmp\litegui\theme4 /Q/S/I
    if errorlevel 1 set /P= unpacked_tmp\litegui\theme3
    xcopy unpacked_tmp\litegui\theme1 unpacked_tmp\litegui\theme5 /Q/S/I
    if errorlevel 1 set /P= unpacked_tmp\litegui\theme1
    xcopy unpacked_tmp\litegui\theme1 unpacked_tmp\litegui\theme6 /Q/S/I
    if errorlevel 1 set /P= unpacked_tmp\litegui\theme1

    rem Now superimpose partial themes
    for %%t in (2 4 5 6) do (
        xcopy changes_edited\litegui\theme%%t unpacked_tmp\litegui\theme%%t /Q/S/Y /EXCLUDE:pack\exclude_source.txt
        if errorlevel 1 set /P= changes_edited\litegui\theme%%t
    )
    for %%t in (2) do (
        xcopy changes_exported\litegui\theme%%t unpacked_tmp\litegui\theme%%t /Q/S/Y /EXCLUDE:pack\exclude_source.txt
        if errorlevel 1 set /P= changes_exported\litegui\theme%%t
    )

    if %%v == 1.4 for %%t in (1 2 3 4 5 6) do (
        mkdir unpacked_tmp\litegui\theme%%t\category\main
        mkdir unpacked_tmp\litegui\theme%%t\m3u\main
        mkdir unpacked_tmp\litegui\theme%%t\m3u\menu
        copy changes_edited\litegui\theme1\bg\wallpaper.png unpacked_tmp\litegui\theme%%t\category\menu\bg.png
        if errorlevel 1 set /P= changes_edited\litegui\bg\wallpaper.png
        for %%n in (category\menu\line category\menu\line_s m3u\long_menu_bg msg\bg_base msg\dock_insert msg\dock_remove msg\full msg\lock msg\low msg\none number\L number\R playing\black) do (
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
        del unpacked_tmp\litegui\theme%%t\list\m3u_s.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\list\m3u_s.png
        for %%n in (album_s artist_s dir_s genre_s recent recent_s) do (
          del unpacked_tmp\litegui\theme%%t\list\%%n.png
          if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\list\%%n.png
        )
        for %%n in (recent recent_s) do (
          del unpacked_tmp\litegui\theme%%t\category\menu\%%n.png
          if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\category\menu\%%n.png
        )
        del unpacked_tmp\litegui\theme%%t\play_settings\single_play.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\play_settings\single_play.png
        move unpacked_tmp\litegui\theme%%t\playing\playing_menu_add?.png unpacked_tmp\litegui\theme%%t\m3u\
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\playing\playing_menu_add?.png
        del unpacked_tmp\litegui\theme%%t\playing\single_play?.png
        if errorlevel 1 set /P= unpacked_tmp\litegui\theme%%t\playing\single_play?.png
        del unpacked_tmp\litegui\theme%%t\playing\single_play?.png
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
if exist pack\eq.ini if exist X: copy X3II.fw X:\