Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant

enum Treatment {
    unknown
    ignore
    cover
    copy
    convert_usual
    convert_hdcd
    convert_xfeed
    convert_mono
    convert_left
    convert_right
}

$special_treatment_by_symbol = @{
    "-" = [Treatment] "ignore"
    "H" = [Treatment] "convert_hdcd"
    "X" = [Treatment] "convert_xfeed"
    "|" = [Treatment] "convert_mono"
    "<" = [Treatment] "convert_left"
    ">" = [Treatment] "convert_right"
}

function Get-Covets {
    param (
        [string] $InPath
    )
    $covets = New-Object "Collections.Generic.Dictionary[string,Treatment]"
    Get-Content -LiteralPath $InPath -Encoding UTF8 -ErrorAction Ignore |
    ForEach-Object {
        $symbol, $name = $_ -split " ", 2
        if (-Not $name) {
            Write-Warning "${InPath}: invalid line ""$_"""
            return $null
        }
        elseif ($covets.ContainsKey($name)) {
            Write-Warning "${InPath}: multiply defined ""$name"""
            return $null
        }
        $covet = $special_treatment_by_symbol[$symbol]
        if ($null -eq $covet) {
            Write-Warning "${InPath}: invalid symbol ""$symbol"""
            return $null
        }
        $covets[$name] = $covet
    }
    return $covets
}

function Set-Covets {
    # Outputs filename to be fed to Remove-Item
    param (
        [Collections.Generic.Dictionary[string, Treatment]] $covets,
        [string] $OutPath
    )
    $covets.GetEnumerator() | ForEach-Object {
        $name, $treatment = $_.Key, $_.Value
        $symbol = $symbol_by_special_treatment[$treatment]
        Write-Output "$symbol $name"
    } | Set-Content -LiteralPath $OutPath -Encoding UTF8
}

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

$symbol_by_special_treatment = @{}
foreach ($p in $special_treatment_by_symbol.GetEnumerator()) {
    ([string] $s, [Treatment] $t) = ($p.Key, $p.Value)
    $symbol_by_special_treatment[$t] = $s
}


function Get-DefaultTreatment {
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
        "*.ac3" { "convert_usual" }
        "*.flac" { "convert_usual" }
        "*.webm" { "convert_usual" }
        default { "unknown" }
    }
    $treatment
}

Write-Host "`n`n`n`n`n"

[string]$src_top = Resolve-Path -LiteralPath $FolderSrc

Get-ChildItem $FolderSrc -Directory |
ForEach-Object {
    $src_folder = $FolderSrc + (Get-Path-Suffix $src_top $_.FullName)
    Write-Progress "Looking for files to be marked as ignored in $src_folder"
    Write-Output $_
} |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $suffix = Get-Path-Suffix $src_top $_.FullName
    $src_folder = $FolderSrc + $suffix
    $dst_folder = $FolderDst + $suffix

    $covet_path = Join-Path $src_folder "covet.txt"
    $covets = Get-Covets $covet_path
    if ($null -ne $covets) {
        $names_unused = New-Object Collections.Generic.List[string]
        $covets.Keys | ForEach-Object { $names_unused.Add($_) }
        $covet_changes = 0

        $_.EnumerateFiles() |
        ForEach-Object {
            $src_path = $_.FullName
            $src_name = $_.Name
            $src_basename = $_.BaseName
            [void] $names_unused.Remove($src_name)
            $covet = $covets[$src_name]
            [Treatment] $treatment = if ($null -ne $covet) { $covet } else { Get-DefaultTreatment $src_name }
            switch ($treatment) {
                "unknown" { Write-Warning "Unknown $src_path" }
                "ignore" {}
                default {
                    $dst_name = switch ($treatment) {
                        "cover" { $ImageName }
                        "copy" { $src_name }
                        default { $src_basename + ".m4a" }
                    }
                    $dst_path = Join-Path $dst_folder $dst_name
                    if (-Not (Test-Path -LiteralPath $dst_path)) {
                        Write-Host "${covet_path}: adding ""$src_name"""
                        $covet[$src_name] = "ignore"
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
} |
Remove-Item -Confirm

Read-Host " :: Press Enter to close :"
