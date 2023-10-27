$ErrorActionPreference = "Inquire"

New-Variable -Option Constant FolderSrc -Value "src"
New-Variable -Option Constant FolderDst -Value "X3"
New-Variable -Option Constant AbsFolderSrc -Value (Resolve-Path -LiteralPath $FolderSrc).Path
New-Variable -Option Constant AbsFolderDst -Value (Resolve-Path -LiteralPath $FolderDst).Path
New-Variable -Option Constant ImageName -Value "folder.jpg"
New-Variable -Option Constant ignore_symbol -Value ([char]"-")
New-Variable -Option Constant conversion_by_symbol -Value @{
    [char]"B" = [Conversion] "cnv_bass"
    [char]"H" = [Conversion] "cnv_hdcd"
    [char]"X" = [Conversion] "cnv_xfeed"
    [char]"|" = [Conversion] "cnv_mono"
    [char]"<" = [Conversion] "cnv_left"
    [char]">" = [Conversion] "cnv_right"
}


enum Treatment {
    unknown
    ignore
    cover
    copy
    convert
}

enum Conversion {
    cnv_hdcd
    cnv_bass
    cnv_xfeed
    cnv_mono
    cnv_left
    cnv_right
}

class Covet {
    [Treatment]$treatment
    [Collections.Generic.List[Conversion]]$conversions
    Covet([Treatment]$treatment) {
        $this.treatment = $treatment
        $this.conversions = [Collections.Generic.List[Conversion]]::new()
    }
}

function Get-Covets {
    param (
        [string] $InPath
    )
    $covets = [Collections.Generic.Dictionary[string, Covet]]::new()
    Get-Content -LiteralPath $InPath -Encoding UTF8 -ErrorAction Ignore |
    ForEach-Object {
        $symbols, $name = $_ -split " ", 2
        if (-Not $name) {
            Write-Warning "${InPath}: invalid line ""$_"""
            return $null
        }
        if ($covets.ContainsKey($name)) {
            Write-Warning "${InPath}: multiply defined ""$name"""
            return $null
        }
        if ($symbols -eq $ignore_symbol) {
            $covet = [Covet]::new("ignore")
        }
        else {
            $covet = [Covet]::new("convert")
            foreach ($s in $symbols.GetEnumerator()) {
                $conversion = $conversion_by_symbol[$s]
                if ($null -eq $conversion) {
                    Write-Error "${InPath}: invalid symbol ""$s"" for name ""$name"""
                    return $null
                }
                $covet.conversions.Add($conversion)
            }
        }
        $covets[$name] = $covet
    }
    return $covets
}

function Set-Covets {
    param (
        [Collections.Generic.Dictionary[string, Covet]] $covets,
        [string] $OutPath
    )
    $covets.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
        $name, $covet = $_.Key, $_.Value
        $symbols = ""
        switch ($covet.treatment) {
            "ignore" { 
                $symbols += $ignore_symbol
            }
            "convert" { 
                foreach ($p in $conversion_by_symbol.GetEnumerator()) {
                    ([string] $symbol, [Conversion] $c) = ($p.Key, $p.Value)
                    if ($covet.conversions -contains $c) {
                        $symbols += $symbol
                    }
                }
            }
        }
        if ($symbols -eq "") {
            Write-Error "${InPath}: unknown treatment for name ""$name"""
        }
        Write-Output "$symbols $name"
    } | Set-Content -LiteralPath $OutPath -Encoding UTF8
}

# Given an absolute path and a FullName found under it, return the diverging part.
function Get-Path-Suffix {
    param (
        [string] $AbsPath,
        [string] $SubPath
    )
    if (-Not $SubPath.StartsWith($AbsPath)) {
        Throw "Quirky path $SubPath does not start with $AbsPath"
    }
    $SubPath.Substring($AbsPath.Length)
}


function Get-Default-Treatment {
    param (
        [string] $Filename
    )

    [Treatment]$treatment = switch -Wildcard ($Filename) {
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

function Update-Folder {
    param (
        [IO.DirectoryInfo] $diritem
    )

    $suffix = Get-Path-Suffix $AbsFolderSrc $diritem.FullName
    $src_folder = $FolderSrc + $suffix
    $dst_folder = $FolderDst + $suffix

    $covet_path = Join-Path $src_folder "covet.txt"
    $covets = Get-Covets $covet_path
    if ($null -ne $covets) {
        $names_unused = [Collections.Generic.List[string]]::new()
        $covets.Keys | ForEach-Object { $names_unused.Add($_) }
        $covet_changes = 0

        $diritem.EnumerateFiles() |
        ForEach-Object {
            $src_path = $_.FullName
            $src_name = $_.Name
            $src_basename = $_.BaseName
            [void] $names_unused.Remove($src_name)
            $covet = $covets[$src_name]
            if (-not $covet) {
                $covet = [Covet]::new((Get-Default-Treatment $src_name))
            }
            switch ($covet.treatment) {
                "unknown" { Write-Warning "Unknown $src_path" }
                "ignore" {}
                default {
                    $dst_name = switch ($covet.treatment) {
                        "cover" { $ImageName }
                        "copy" { $src_name }
                        "convert" { $src_basename + ".m4a" }
                    }
                    $dst_path = Join-Path $dst_folder $dst_name
                    if (-Not (Test-Path -LiteralPath $dst_path)) {
                        Write-Host "${covet_path}: adding ""$src_name"""
                        $covets[$src_name] = [Covet]::new("ignore")
                        ++$covet_changes
                    }
                }
            }
        }
        ForEach ($n in $names_unused) {
            Write-Host "${covet_path}: removing ""$n"""
            if (-Not $covets.Remove($n)) {
                throw "Lost covet!"
            }
            ++$covet_changes
        }
        if ($covet_changes) {
            if ($covets.Count) {
                Set-Covets $covets $covet_path
            }
            else {
                Write-Output $covet_path
            }
        }
    }
}

# Full recursion but only reporting progress on the 2nd level
Write-Progress -Activity "Looking in folder" -Status $FolderSrc -PercentComplete -1
$diritems = Get-ChildItem $FolderSrc -Directory | Get-ChildItem -Directory
0..($diritems.Count - 1) | ForEach-Object {
    $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
    $dir = $diritems[$_]
    $src_folder = $FolderSrc + (Get-Path-Suffix $AbsFolderSrc $dir.FullName)
    Write-Progress -Activity "Looking in folder" -Status $src_folder -PercentComplete $pct
    Update-Folder $dir
    $dir | Get-ChildItem -Directory -Recurse | ForEach-Object { Update-Folder $_ }
}  | Remove-Item -Confirm

Get-ChildItem $FolderDst -Directory |
ForEach-Object {
    $dst_folder = $FolderDst + (Get-Path-Suffix $AbsFolderDst $_.FullName)
    Write-Progress -Activity "Looking for spurious files" -Status $dst_folder -PercentComplete -1
    Write-Output $_
} |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $suffix = Get-Path-Suffix $AbsFolderDst $_.FullName
    $src_folder = $FolderSrc + $suffix
    if (Test-Path -LiteralPath $src_folder) {
        $covet_path = Join-Path $src_folder "covet.txt"
        $covets = Get-Covets $covet_path

        $_.EnumerateFiles() |
        ForEach-Object {
            [Boolean[]] $justifications = if ($_.Name -eq $ImageName) {
                foreach ($n in "cover.jpg", "cover.jpeg", "cover.png", "cover.webm") {
                    Join-Path $src_folder $n | Test-Path
                }
            }
            else {
                foreach ($n in $_.Name,
                               ($_.BaseName + ".ac3"),
                               ($_.BaseName + ".flac"),
                               ($_.BaseName + ".webm")) {
                    (Join-Path $src_folder $n | Test-Path) -And ($null -eq $covets[$n] -Or $covets[$n].treatment -ne "ignore")
                }
            }
            if ($justifications -NotContains $true) {
                Write-Output $_
            }
        }
    }
    else {
        Write-Output $_
    }
} |
Remove-Item -Confirm
