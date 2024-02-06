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
New-Variable -Option Constant FfmpegDate_hdcd -Value ([datetime]"2023-03-03")
New-Variable -Option Constant FfmpegDate_bass -Value ([datetime]"2023-10-21")
New-Variable -Option Constant FfmpegDate_by_mix -Value @{
    [ChannelMix] "mix_xfeed" = [datetime]"2023-04-20"
    [ChannelMix] "mix_mono"  = [datetime]"2023-03-03"
    [ChannelMix] "mix_left"  = [datetime]"2023-03-03"
    [ChannelMix] "mix_right" = [datetime]"2023-03-03"
}

function Build-Destination {
    param (
        [string] $dst_folder
    )

    if (-Not (Test-Path -LiteralPath $dst_folder)) {
        Write-Host "Creating $dst_folder"
        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
    }
}

function Update-FileFromSrc {
    param (
        [Covet] $covet,
        [string] $src_path,
        [DateTime] $src_LastWriteTime,
        [string] $dst_path,
        [string] $dst_path_abs
    )

    switch ($covet.treatment) {
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
                Write-Warning "Keeping unhinged $dst_path"
            }
        }
        "convert" {
            $private:times = $src_LastWriteTime, $FfmpegDate_by_mix[$covet.mix]
            if ($covet.hdcd) { $times += $FfmpegDate_hdcd }
            if ($covet.bass) { $times += $FfmpegDate_bass }
            $private:dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
            if ($null -eq $dst -Or -Not $dst.Length -Or ($times -gt $dst.LastWriteTime).Count) {
                $private:ffmpeg_arglist = [Collections.Generic.List[string]]::new()
                $private:filters = [Collections.Generic.List[string]]::new()
                $ffmpeg_arglist += "-loglevel", "warning"
                $ffmpeg_arglist += "-i", "`"$src_path`""
                if ($covet.hdcd) {
                    $filters += "hdcd=disable_autoconvert=0"
                }
                switch ($covet.mix) {
                    "mix_xfeed" { $filters += "crossfeed=level_in=1:strength=.5" }
                    "mix_left" { $filters += "pan=mono| c0=FL" }
                    "mix_rght" { $filters += "pan=mono| c0=FR" }
                    "mix_mono" { $ffmpeg_arglist += "-ac", 1 }
                }
                if ($covet.bass) {
                    $filters += "bass=gain=5"
                }
                $filters += "aformat=sample_rates=48000|44100|32000|24000|22050|16000|12000|11025|8000|7350"
                $filters += "volume=replaygain=album"
                $ffmpeg_arglist += "-filter:a", "`"$($filters -join ",")`""
                $ffmpeg_arglist += "-q:a", $FfmpegQuality
                $ffmpeg_arglist += "`"$dst_path_abs`"", "-y"

                while (@(Get-Job -State "Running").count -ge $FfmpegJobs) {
                    Start-Sleep -Seconds 0.5
                }
                Write-Host "Writing $dst_path"
                Start-Job -ScriptBlock {
                    # Call operator & avoids the insane quoting needed for file names
                    # (https://github.com/PowerShell/PowerShell/issues/5576) but doesn't allow
                    # setting priority and doesn't let the process complete on Ctrl-C.
                    # We can't use -RedirectStandardError, it blocks the process from the start.
                    $private:p = Start-Process -WindowStyle "Hidden" -PassThru "ffmpeg.exe" -ArgumentList $using:ffmpeg_arglist
                    $p.PriorityClass = "BelowNormal"
                    $p.WaitForExit()
                    $private:dst = Get-Item -LiteralPath $using:dst_path_abs -ErrorAction:SilentlyContinue
                    if ($null -eq $dst -Or -Not $dst.Length) {
                        Remove-Item -LiteralPath $using:dst_path_abs
                        throw "Failed to create $using:dst_path_abs { ffmpeg $using:ffmpeg_arglist }"
                    }
                } | Out-Null
            }
        }
    }
}

function Update-FolderSrc {
    process {
        $private:diritem = [IO.DirectoryInfo] $_
        $private:suffix = Get-PathSuffix $AbsFolderSrc $diritem.FullName
        $private:src_folder = $diritem.FullName
        $private:dst_folder = $FolderDst + $suffix
        $private:dst_folder_abs = $AbsFolderDst + $suffix

        $private:covet_path = Join-Path $src_folder "covet.txt"
        $private:covets = Get-Covets $covet_path
        if ($null -ne $covets) {
            $private:names_unused = [Collections.Generic.List[string]]::new()
            $covets.Keys | ForEach-Object { $names_unused.Add($_) }
            $private:src_count = 0
            $private:dst_count = 0
            $private:covet_changes = 0

            $diritem.EnumerateFiles() |
                ForEach-Object {
                    $private:src_path = $_.FullName
                    $private:src_name = $_.Name
                    $private:src_basename = $_.BaseName
                    $private:src_LastWriteTime = $_.LastWriteTime
                    [void] $names_unused.Remove($src_name)
                    $private:covet = $covets[$src_name]
                    if (-not $covet) {
                        $covet = [Covet]::new((Get-DefaultTreatment $src_name))
                    }
                    switch ($covet.treatment) {
                        "unknown" { Write-Warning "Unknown $src_path" }
                        "ignore" {}
                        "cover" { 
                            $private:dst_path = Join-Path $dst_folder $ImageName
                            $private:dst_path_abs = Join-Path $dst_folder_abs $ImageName
                            switch ($mode) {
                                "publish_changes" {
                                    Build-Destination $dst_folder
                                    # Must use absolute path because Convert-Cover somehow gets a different working
                                    # directory (and Start-Process without -WorkingDirectory too).
                                    Convert-Cover $src_path $dst_path $dst_path_abs
                                }
                                "register_removes" {
                                }
                            }
                        }
                        default {
                            $src_count += 1
                            $dst_count += 1
                            $private:dst_name = switch ($covet.treatment) {
                                "copy" { $src_name }
                                "convert" { $src_basename + ".m4a" }
                            }
                            $private:dst_path = Join-Path $dst_folder $dst_name
                            $private:dst_path_abs = Join-Path $dst_folder_abs $dst_name
                            switch ($mode) {
                                "publish_changes" {
                                    Build-Destination $dst_folder
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
                    $justifying_names = if ($_.Name -eq $ImageName) {
                        "cover.jpg", "cover.jpeg", "cover.png", "cover.webm"
                    }
                    else {
                        $_.Name,
                        ($_.BaseName + ".ac3"),
                        ($_.BaseName + ".flac"),
                        ($_.BaseName + ".webm") |
                            Where-Object { $null -eq $covets[$_] -Or $covets[$_].treatment -ne "ignore" }
                        }
                        # This crazy indentation is courtesy of Visual Studio Code
                        $justifying_paths = $justifying_names | ForEach-Object { Join-Path $src_folder $_ }
                        if ((Test-Path -LiteralPath $justifying_paths) -NotContains $true) {
                            Write-Output $_
                        }
                    }
            # Visual Studio Code resumes proper indentation
        }
        else {
            Write-Output $_
        }
    }
}

enum Mode {
    publish_changes
    register_removes
    clean_up
}
foreach ($arg in $args) {
    $mode = [Mode] $arg
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
}

Get-Job | Wait-Job | Receive-Job | Write-Error
