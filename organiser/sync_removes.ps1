Set-Variable SourcePattern -Value "*.src" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant

Write-Output "`n`n`n`n`n"

Get-ChildItem -Directory -Filter $SourcePattern |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $src_folder = Resolve-Path -LiteralPath $_.FullName -Relative
    Write-Progress $src_folder
    $c = $src_folder -Split '\\'
    if ($c[0] -ne "." -Or -Not ($c[1] -Like $SourcePattern)) {
        Throw "Quirky Path $src_folder"
    }
    $c[1] = $c[1].Substring(0, $c[1].Length - $SourcePattern.Length + 1)
    $dst_folder = $c -Join '\\'

    $cut_path = Join-Path $src_folder "cut.txt"
    $cuts = [string[]]@()
    $cuts += Get-Content -LiteralPath $cut_path -Encoding UTF8 -ErrorAction Ignore
    $unused = $cuts

    $cut_changes = 0
    $_.EnumerateFiles() |
    ForEach-Object {
        $src_name = $_.Name
        $converted_dst_name = $_.BaseName + ".m4a"
        $dst_name = $null
        switch -Wildcard ($src_name) {
            "*.new.*" { break }
            "*.old.*" { break }
            "*.raw.*" { break }
            "*.m4a" { $dst_name = $src_name }
            "*.mp3" { $dst_name = $src_name }
            "*.ogg" { $dst_name = $src_name }
            "*.wma" { $dst_name = $src_name }
            "*.ac3" { $dst_name = $converted_dst_name }
            "*.flac" { $dst_name = $converted_dst_name }
        }
        if ($dst_name) {
            $dst_path = Join-Path $dst_folder $dst_name
            if ($cuts -And $cuts.Contains($src_name)) {
                $unused = $unused | Where-Object { $_ -ne $src_name }
            }
            else {
                if (-Not (Test-Path -LiteralPath $dst_path)) {
                    Write-Output ($cut_path + ": adding " + $src_name)
                    $cuts += $src_name
                    ++$cut_changes
                }
            }
        }
    }
    foreach ($n in $unused) {
        Write-Output ("${cut_path}: dropping $n")
        $cuts = $cuts | Where-Object { $_ -ne $n }
        ++$cut_changes
    }
    if ($cut_changes) {
        if ($cuts) {
            $cuts | Sort-Object | Set-Content -LiteralPath $cut_path -Encoding UTF8
        }
        else {
            Write-Output "${cut_path}: removing"
            Remove-Item -Confirm -LiteralPath $cut_path
        }
    }
}

Get-ChildItem -Directory -Filter $SourcePattern |
ForEach-Object {
    $src_top = Resolve-Path -LiteralPath $_.FullName -Relative
    $c = $src_top -Split '\\'
    if ($c[0] -ne "." -Or -Not ($c[1] -Like $SourcePattern)) {
        Throw ("Quirky Path $src_top")
    }
    $c[1] = $c[1].Substring(0, $c[1].Length - $SourcePattern.Length + 1)
    $dst_top = $c -Join '\\'

    Get-ChildItem -LiteralPath $dst_top -Recurse -Directory |
    ForEach-Object {
        $dst_folder = Resolve-Path -LiteralPath $_.FullName -Relative
        $c = $dst_folder -Split '\\'
        if ($c[0] -ne ".") {
            Throw ("Bad path $dst_folder")
        }
        $c[1] += ".src"
        $src_folder = $c -Join '\\'

        $_.EnumerateFiles() |
        Where-Object -Property Name -ne $ImageName |
        ForEach-Object {
            $dst_path = $_.FullName
            $src_path1 = Join-Path $src_folder $_.Name
            $src_path2 = Join-Path $src_folder ($_.BaseName + ".ac3")
            $src_path3 = Join-Path $src_folder ($_.BaseName + ".flac")
            if (-Not (Test-Path -LiteralPath $src_path1) -And
                -Not (Test-Path -LiteralPath $src_path2) -And
                -Not (Test-Path -LiteralPath $src_path3)) {
                Remove-Item -LiteralPath $dst_path -Confirm
            }
        }
    }
}

Read-Host " :: Press Enter to close :"
