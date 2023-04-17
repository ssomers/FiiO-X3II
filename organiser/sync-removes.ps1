Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant

# Given an absolute path and a FullName found under it, return the diverging part.
function Get-Path-Suffix {
    param (
        [string] $TopPath,
        [string] $SubPath
    )
    if (-Not $SubPath.StartsWith($TopPath)) {
        Throw "Quirky path $SubPath"
    }
    $SubPath.Substring($TopPath.Length)
}

enum Treatment {
    unknown
    ignore
    cover
    copy
    convert
}

enum Covet {
    drop
    hdcd
}

function Get-Treatment {
    param (
        [string] $Filename
    )

    [Treatment]$treatment = switch -Wildcard ($Filename) {
        "*.new.*" { "ignore"; break }
        "*.old.*" { "ignore"; break }
        "*.raw.*" { "ignore"; break }
        "*.iso" { "ignore" }
        "*.llc" { "ignore" }
        "*.mp4" { "ignore" }
        "*.pdf" { "ignore" }
        "*.txt" { "ignore" }
        "cover.*" { "cover" }
        "*.m4a" { "copy" }
        "*.mp2" { "copy" }
        "*.mp3" { "copy" }
        "*.ogg" { "copy" }
        "*.wma" { "copy" }
        "*.ac3" { "convert" }
        "*.flac" { "convert" }
        "*.webm" { "convert" }
        default { "unknown" }
    }
    $treatment
}

Write-Host "`n`n`n`n`n"

[string]$src_top = Resolve-Path -LiteralPath $FolderSrc
[string]$dst_top = Resolve-Path -LiteralPath $FolderDst

Get-ChildItem $FolderSrc -Directory |
ForEach-Object {
    $src_folder = $FolderSrc + (Get-Path-Suffix $src_top $_.FullName)
    Write-Progress "Looking for files to be cut in $src_folder"
    Write-Output $_
} |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $suffix = Get-Path-Suffix $src_top $_.FullName
    $src_folder = $FolderSrc + $suffix
    $dst_folder = $FolderDst + $suffix

    $covet_path = Join-Path $src_folder "covet.txt"
    $covets = New-Object "System.Collections.Generic.Dictionary[String,Covet]"
    $covets_new = New-Object "System.Collections.Generic.Dictionary[String,Covet]"
    Get-Content -LiteralPath $covet_path -Encoding UTF8 -ErrorAction Ignore |
    ForEach-Object {
        $c, $name = $_ -split " ", 2
        $covets[$name] = $c
    }

    $covet_changes = 0

    $_.EnumerateFiles() |
    ForEach-Object {
        $src_name = $_.Name
        $src_basename = $_.BaseName
        $treatment = Get-Treatment $src_name
        switch ($treatment) {
            "unknown" {
                Write-Warning "Unknown $src_path"
                break
            }
            "ignore" {
                break
            }
            { $true } {
                $covet = $covets[$src_name]
                if ($covets.Remove($src_name)) {
                    $covets_new[$src_name] = $covet
                }
                if ($covet -eq "drop") {
                    break
                }

                $dst_name = switch ($treatment) {
                    "cover" { $ImageName }
                    "copy" { $src_name }
                    "convert" { $src_basename + ".m4a" }
                }
                $dst_path = Join-Path $dst_folder $dst_name
                if (-Not (Test-Path -LiteralPath $dst_path)) {
                    Write-Host "${covet_path}: adding ""$src_name"""
                    $covets_new[$src_name] = "drop"
                    ++$covet_changes
                }
            }
        }
    }
    ForEach ($p in $covets.GetEnumerator()) {
        Write-Host "${covet_path}: removing ""$($p.Key)"""
        ++$covet_changes
    }
    if ($covet_changes) {
        if ($covets_new.Count) {
            $covets_new.GetEnumerator() | ForEach-Object { "$($_.Value) $($_.Key)" } | Set-Content -LiteralPath $covet_path -Encoding UTF8
        }
        else {
            Write-Output $covet_path
        }
    }
} |
Remove-Item -Confirm

Get-ChildItem $FolderDst -Directory |
ForEach-Object {
    $dst_folder = $FolderDst + (Get-Path-Suffix $dst_top $_.FullName)
    Write-Progress "Looking for files to be deleted from $dst_folder"
    Write-Output $_
} |
Get-ChildItem -Recurse -Directory |
ForEach-Object {
    $suffix = Get-Path-Suffix $dst_top $_.FullName
    $src_folder = $FolderSrc + $suffix

    if (-Not (Test-Path -LiteralPath $src_folder)) {
        Write-Output $_
    }
    else {
        $_.EnumerateFiles() |
        ForEach-Object {
            $names = if ($_.Name -eq $ImageName) {
                @("cover.jpg", "cover.jpeg", "cover.png", "cover.webm")
            }
            else {
                @($_.Name,
                  ($_.BaseName + ".ac3"),
                  ($_.BaseName + ".flac"),
                  ($_.BaseName + ".webm")
                )
            }
            $t = foreach ($n in $names) { Join-Path $src_folder $n | Test-Path }
            if ($t -NotContains $true) {
                Write-Output $_.FullName
            }
        }
    }
} |
Remove-Item -Confirm

Read-Host " :: Press Enter to close :"
