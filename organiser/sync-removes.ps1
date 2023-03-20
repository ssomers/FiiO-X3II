Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant

# Given an absolute path and a FullName found under it, return the diverging bit.
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
    ignore
    cover
    copy
    convert
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
        default { "ignore"; Write-Warning "Unknown $(Join-Path $src_folder $_)" }
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

    $cut_path = Join-Path $src_folder "cut.txt"
    $cuts = [string[]]@()
    $cuts += Get-Content -LiteralPath $cut_path -Encoding UTF8 -ErrorAction Ignore
    $cuts_new = $cuts
    $cut_changes = 0
    $_.EnumerateFiles() |
    ForEach-Object {
        $src_name = $_.Name
        $src_basename = $_.BaseName
        $treatment = Get-Treatment $src_name
        $dst_name = switch ($treatment) {
            "cover" { $ImageName }
            "copy" { $src_name }
            "convert" { $src_basename + ".m4a" -Replace ".hdcd.", "." }
        }
        switch ($treatment) {
            "ignore" { break }
            { $true } {
                if ($cuts -And $cuts.Contains($src_name)) {
                    $cuts = $cuts | Where-Object { $_ -ne $src_name }
                    break
                }
                $dst_path = Join-Path $dst_folder $dst_name
                if (-Not (Test-Path -LiteralPath $dst_path)) {
                    Write-Host "${cut_path}: adding ""$src_name"""
                    $cuts_new += $src_name
                    ++$cut_changes
                }
            }
        }
    }
    ForEach ($n in $cuts) {
        Write-Host "${cut_path}: dropping ""$n"""
        $cuts_new = $cuts_new | Where-Object { $_ -ne $n }
        ++$cut_changes
    }
    if ($cut_changes) {
        if ($cuts_new) {
            $cuts_new | Sort-Object | Set-Content -LiteralPath $cut_path -Encoding UTF8
        }
        else {
            Write-Host "${cut_path}: removing"
            Write-Output $cut_path
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
                  ($_.BaseName + ".hdcd.flac"),
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
