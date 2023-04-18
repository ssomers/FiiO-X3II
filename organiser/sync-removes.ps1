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
    xf50
    mono
    left
    rght
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

Get-ChildItem $FolderSrc -Directory |
ForEach-Object {
    $src_folder = $FolderSrc + (Get-Path-Suffix $src_top $_.FullName)
    Write-Progress "Looking for files to be registered as dropped in $src_folder"
    Write-Output $_
} |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $suffix = Get-Path-Suffix $src_top $_.FullName
    $src_folder = $FolderSrc + $suffix
    $dst_folder = $FolderDst + $suffix

    $covet_path = Join-Path $src_folder "covet.txt"
    $covets = New-Object "System.Collections.Generic.Dictionary[string,Covet]"
    $covets_new = New-Object "System.Collections.Generic.Dictionary[string,Covet]"
    $covets_ok = $true
    Get-Content -LiteralPath $covet_path -Encoding UTF8 -ErrorAction Ignore |
    ForEach-Object {
        $err = try { [Covet] $typed_covet, [String] $name = $_ -split " ", 2 } catch { $_ }
        if (-Not $err -And -Not $name) {
            $err = "invalid line ""$_"""
        }
        if (-Not $err -And $covets.ContainsKey($name)) {
            $err = """$name"" multiply defined"
        }
        if ($err) {
            Write-Warning "${covet_path}: $err"
            $covets_ok = $false
        }
        else {
            $covets[$name] = $typed_covet
        }
    }
    if ($covets_ok) {
        $covet_changes = 0

        $_.EnumerateFiles() |
        ForEach-Object {
            $src_path = $_.FullName
            $src_name = $_.Name
            $src_basename = $_.BaseName
            $treatment = Get-Treatment $src_name
            switch ($treatment) {
                "unknown" { Write-Warning "Unknown $src_path" }
                "ignore" {}
                default {
                    $covet = $covets[$src_name]
                    if ($covets.Remove($src_name)) {
                        $covets_new[$src_name] = $covet
                        if ($covet -eq "drop") {
                            break
                        }
                        $treatment = "convert"
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
    }
} |
Remove-Item -Confirm

Read-Host " :: Press Enter to close :"
