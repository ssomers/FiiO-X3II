using module .\cover.psm1
using module .\covets.psm1
using module .\io.psm1
Set-StrictMode -Version latest

$ErrorActionPreference = "Inquire"

New-Variable -Option Constant FolderSrc -Value "src"
New-Variable -Option Constant FolderDst -Value "X3"
New-Variable -Option Constant AbsFolderSrc -Value (Resolve-Path -LiteralPath $FolderSrc).Path
New-Variable -Option Constant AbsFolderDst -Value (Resolve-Path -LiteralPath $FolderDst).Path

New-Variable -Option Constant FfmpegQuality -Value 7
New-Variable -Option Constant FfmpegJobs -Value ([Environment]::ProcessorCount - 1)
New-Variable -Option Constant FfmpegDate_anyhow -Value ([datetime]"2023-03-03")
New-Variable -Option Constant FfmpegDate_by_cnv -Value @{
    [Conversion] "cnv_bass"  = [datetime]"2023-10-21"
    [Conversion] "cnv_hdcd"  = [datetime]"2023-03-03"
    [Conversion] "cnv_xfeed" = [datetime]"2023-04-20"
    [Conversion] "cnv_mono"  = [datetime]"2023-03-03"
    [Conversion] "cnv_left"  = [datetime]"2023-03-03"
    [Conversion] "cnv_right" = [datetime]"2023-03-03"
}

enum Mode {
    publish_changes
    register_removes
    clean_up
}

function Compare-Dates {
    param (
        [DateTime] $LastWriteTime,
        [Conversion[]] $conversions
    )
    if ($FfmpegDate_anyhow -gt $LastWriteTime) {
        return $true
    }
    foreach ($c in $conversions.GetEnumerator()) {
        if ($FfmpegDate_by_cnv[$c] -gt $LastWriteTime) {
            return $true
        }
    }
    $false
}

function Update-FileFromSrc {
    param (
        [Covet] $covet,
        [string] $src_path,
        [DateTime] $src_LastWriteTime,
        [string] $dst_path,
        [string] $dst_path_abs
    )

    if (-Not (Test-Path -LiteralPath $dst_folder)) {
        Write-Host "Creating $dst_folder"
        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
    }
    switch ($covet.treatment) {
        "cover" {
            # Must use absolute path because Convert-Cover somehow gets a different working
            # directory (and Start-Process without -WorkingDirectory too).
            Convert-Cover $src_path $dst_path_abs
        }
        "copy" {
            if (-Not (Test-Path -LiteralPath $dst_path)) {
                Write-Host "Linking $dst_path"
                New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
            }
            elseif ((Get-FileID $src_path) -eq (Get-FileID $dst_path)) {
                #Write-Host "Keeping $dst_path"
            }
            elseif ((Get-FileHash $src_path).Hash -eq (Get-FileHash $dst_path).Hash) {
                Write-Host "Re-linking $dst_path"
                New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) -Force | Out-Null
            }
            else {
                Write-Warning "Unhinged $dst_path"
            }
        }
        "convert" {
            $dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
            if ($null -eq $dst -Or -Not $dst.Length -Or (Compare-Dates $dst.LastWriteTime $covet.conversions) -Or $src_LastWriteTime -gt $dst.LastWriteTime) {
                $ffmpeg_arglist = [Collections.Generic.List[string]]::new();
                $ffmpeg_arglist += "-loglevel", "warning"
                $ffmpeg_arglist += "-i", "`"$src_path`""
                $filters = [Collections.Generic.List[string]]::new();
                foreach ($c in $covet.conversions.GetEnumerator()) {
                    switch ($c) {
                        "cnv_bass" { $filters += "bass=gain=5" }
                        "cnv_hdcd" { $filters += "hdcd=disable_autoconvert=0" }
                        "cnv_xfeed" { $filters += "crossfeed=level_in=1:strength=.5" }
                        "cnv_left" { $filters += "pan=mono| c0=FL" }
                        "cnv_rght" { $filters += "pan=mono| c0=FR" }
                        "cnv_mono" { $ffmpeg_arglist += "-ac", 1 }
                    }
                }
                $filters += "aformat=sample_rates=48000|44100|32000|24000|22050|16000|12000|11025|8000|7350"
                $filters += "volume=replaygain=album"
                $ffmpeg_arglist += "-filter:a", "`"$($filters -join ",")`""
                $ffmpeg_arglist += "-q:a", $FfmpegQuality
                $ffmpeg_arglist += "`"$dst_path_abs`"", "-y"

                while ((Get-Job -State "Running").count -ge $FfmpegJobs) {
                    Start-Sleep -Seconds 0.5
                }
                Write-Host "Writing $dst_path"
                Start-Job -ScriptBlock {
                    # Call operator & avoids the insane quoting needed for file names
                    # (https://github.com/PowerShell/PowerShell/issues/5576) but doesn't allow
                    # setting priority and doesn't let the process complete on Ctrl-C.
                    # We can't use -RedirectStandardError, it blocks the process from the start.
                    $p = Start-Process -WindowStyle "Hidden" -PassThru "ffmpeg.exe" -ArgumentList $using:ffmpeg_arglist
                    $p.PriorityClass = "BelowNormal"
                    $p.WaitForExit()
                    $dst = Get-Item -LiteralPath $using:dst_path_abs -ErrorAction:SilentlyContinue
                    if ($null -eq $dst -Or -Not $dst.Length) {
                        Remove-Item -LiteralPath $using:dst_path_abs
                        "Failed to create $using:dst_path_abs { ffmpeg $using:ffmpeg_arglist }"
                    }
                } | Out-Null
            }
        }
    }
}

function Update-FolderSrc {
    process {
        $diritem = [IO.DirectoryInfo] $_
        $suffix = Get-PathSuffix $AbsFolderSrc $diritem.FullName
        $src_folder = $FolderSrc + $suffix
        $dst_folder = $FolderDst + $suffix
        $dst_folder_abs = $AbsFolderDst + $suffix

        $covet_path = Join-Path $src_folder "covet.txt"
        $covets = Get-Covets $covet_path
        if ($null -ne $covets) {
            $names_unused = [Collections.Generic.List[string]]::new()
            $covets.Keys | ForEach-Object { $names_unused.Add($_) }
            $src_count = 0
            $dst_count = 0
            $covet_changes = 0

            $diritem.EnumerateFiles() |
            ForEach-Object {
                $src_path = $_.FullName
                $src_name = $_.Name
                $src_basename = $_.BaseName
                $src_LastWriteTime = $_.LastWriteTime
                [void] $names_unused.Remove($src_name)
                $covet = $covets[$src_name]
                if (-not $covet) {
                    $covet = [Covet]::new((Get-DefaultTreatment $src_name))
                }
                switch ($covet.treatment) {
                    "unknown" { Write-Warning "Unknown $src_path" }
                    "ignore" {}
                    default {
                        $src_count += 1
                        $dst_count += switch ($covet.treatment) {
                            "cover" { 0 }
                            "copy" { 1 }
                            "convert" { 1 }
                        }
                        $dst_name = switch ($covet.treatment) {
                            "cover" { $ImageName }
                            "copy" { $src_name }
                            "convert" { $src_basename + ".m4a" }
                        }
                        $dst_path = Join-Path $dst_folder $dst_name
                        $dst_path_abs = Join-Path $dst_folder_abs $dst_name
                        switch ($mode) {
                            "publish_changes" {
                                if (-Not (Test-Path -LiteralPath $dst_folder)) {
                                    Write-Host "Creating $dst_folder"
                                    New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
                                }
                                Update-FileFromSrc $covet $src_path $src_LastWriteTime $dst_path $dst_path_abs
                            }
                            "register_removes" { 
                                if (-Not (Test-Path -LiteralPath $dst_path)) {
                                    Write-Host "${covet_path}: adding ""$src_name"""
                                    $covets[$src_name] = [Covet]::new("ignore")
                                    ++$covet_changes
                                }
                            }
                        }
                    }
                }
                Get-Job | Receive-Job | Write-Error
            }
            ForEach ($n in $names_unused) {
                switch ($mode) {
                    "publish_changes" {
                        Write-Warning "${covet_path}: unused item ""$n"""
                    }
                    "register_removes" { 
                        Write-Host "${covet_path}: removing ""$n"""
                        if (-Not $covets.Remove($n)) {
                            throw "Lost covet!"
                        }
                        ++$covet_changes
                    }
                }
            }
            if ($covet_changes) {
                if ($covets.Count) {
                    Set-Covets $covets $covet_path
                }
                else {
                    Write-Output $covet_path
                }
            }
            if ($src_count -And -Not $dst_count) {
                Write-Warning "Unused folder $src_folder"
            }
        }
    }
}

function Update-FolderDst {
    process {
        $diritem = [IO.DirectoryInfo] $_
        $suffix = Get-PathSuffix $AbsFolderDst $diritem.FullName
        $src_folder = $FolderSrc + $suffix
        if (Test-Path -LiteralPath $src_folder) {
            $covet_path = Join-Path $src_folder "covet.txt"
            $covets = Get-Covets $covet_path

            $diritem.EnumerateFiles() |
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
    }
}

$mode = [Mode] $args[0]
switch ($mode) {
    "clean_up" {
        # Full recursion in Dst but only reporting progress on the 1st level
        $diritems = Get-ChildItem $FolderDst -Directory
        0..($diritems.Count - 1) | ForEach-Object {
            $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
            $dir = $diritems[$_]
            $dst_folder = $FolderDst + (Get-PathSuffix $AbsFolderDst $dir.FullName)
            Write-Progress -Activity "Looking for spurious files" -Status $dst_folder -PercentComplete $pct
            Get-ChildItem $dir -Directory -Recurse
        } | Update-FolderDst | Remove-Item -Confirm
    }
    Default { 
        # Full recursion in Src but only reporting progress on the 2nd level
        Write-Progress -Activity "Looking in folder" -Status $FolderSrc -PercentComplete -1
        $diritems = Get-ChildItem $FolderSrc -Directory | Get-ChildItem -Directory
        0..($diritems.Count - 1) | ForEach-Object {
            $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
            $dir = $diritems[$_]
            $src_folder = $FolderSrc + (Get-PathSuffix $AbsFolderSrc $dir.FullName)
            Write-Progress -Activity "Looking in folder" -Status $src_folder -PercentComplete $pct
            @($dir) + (Get-ChildItem $dir -Directory -Recurse)
        } | Update-FolderSrc | Remove-Item -Confirm
    }
}

Get-Job | Wait-Job | Receive-Job | Write-Error
