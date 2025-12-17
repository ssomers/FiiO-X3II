using module .\sys.psm1
using module .\cover.psm1
using module .\covets.psm1
using module .\IoUtils.psm1
Set-StrictMode -Version latest

$ErrorActionPreference = "Inquire" # "Break"

enum SyncMode {
    publish_changes
    register_removes
    clean_up
}
$modes = $args | ForEach-Object { [SyncMode] $_ }
if ($null -eq $modes) {
    Write-Host "Tell me what to do: any of publish_changes, register_removes, clean_up"
}

# `New-Variable -Option Constant` is barely usable in VS Code and plain `New-Variable` too,
# so using plain variables for constants.
$FolderSrc = "src"
$FolderDst = "X3"
$ImageName = "folder.jpg"
$AbsFolderSrc = (Resolve-Path -LiteralPath $FolderSrc).Path
$AbsFolderDst = (Resolve-Path -LiteralPath $FolderDst).Path

$FfmpegQuality = 7
$FfmpegJobs = [Environment]::ProcessorCount
$FfmpegDate_hdcd = [datetime]"2023-03-03"
$FfmpegDate_bass = [datetime]"2024-05-21"
$FfmpegDate_by_mix = @{
    [ChannelMix] "mix_xfeed" = [datetime]"2023-04-20"
    [ChannelMix] "mix_mono"  = [datetime]"2023-03-03"
    [ChannelMix] "mix_left"  = [datetime]"2023-03-03"
    [ChannelMix] "mix_right" = [datetime]"2023-03-03"
}

function Build-Destination {
    param (
        [string] $dst_folder
    )

    if (-not (Test-Path -LiteralPath $dst_folder)) {
        Write-Host "Creating $dst_folder"
        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
    }
}

function Update-FileFromSrc {
    param (
        [Covet] $covet,
        [string] $src_path,
        [DateTime] $src_LastWriteTime,
        [string] $dst_name,
        [string] $dst_path,
        [string] $dst_path_abs
    )

    switch ($covet.treatment) {
        "copy" {
            if (-not (Test-Path -LiteralPath $dst_path)) {
                Write-Host "Linking $dst_path"
                New-Item -ItemType "HardLink" -Path $dst_path -Target ([IoUtils]::LinkTarget($src_path)) | Out-Null
            }
            elseif ([IoUtils]::IsSameFile($src_path, $dst_path_abs)) {
                #Write-Host "Keeping $dst_path"
            }
            else {
                if ((Get-FileHash -LiteralPath $src_path).Hash -ne (Get-FileHash -LiteralPath $dst_path).Hash) {
                    Rename-Item $dst_path "$dst_name.prev"
                    Write-Output "$dst_path.prev"
                    Write-Host "Linking changed $dst_path"
                }
                else {
                    Write-Host "Re-linking $dst_path"
                }
                New-Item -ItemType "HardLink" -Path $dst_path -Target ([IoUtils]::LinkTarget($src_path)) -Force | Out-Null
            }
        }
        "convert" {
            $private:times = $src_LastWriteTime, $FfmpegDate_by_mix[$covet.mix]
            if ($covet.hdcd) { $times += $FfmpegDate_hdcd }
            if ($covet.bass) { $times += $FfmpegDate_bass }
            $private:dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
            if ($null -eq $dst -or -not $dst.Length -or ($times -gt $dst.LastWriteTime).Count) {
                $private:ffmpeg_arglist = [Collections.Generic.List[string]]::new()
                $private:filters = [Collections.Generic.List[string]]::new()
                $ffmpeg_arglist += "-loglevel", "warning"
                $ffmpeg_arglist += "-i", "`"$src_path`""
                if ($covet.hdcd) {
                    $filters += "hdcd=disable_autoconvert=0"
                }
                switch ($covet.mix) {
                    "mix_xfeed" { $filters += "crossfeed=level_in=1:strength=.5" }
                    "mix_left" { $filters += "pan=mono|c0=FL" }
                    "mix_rght" { $filters += "pan=mono|c0=FR" }
                    "mix_mono" { $ffmpeg_arglist += "-ac", 1 }
                }
                if ($covet.bass) {
                    $filters += "bass=gain=9"
                }
                $filters += "aformat=sample_rates=96000|88200|48000|44100|32000|24000|22050|16000|12000|11025|8000|7350"
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
                    if ($null -eq $dst -or -not $dst.Length) {
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
        $private:suffix = [IoUtils]::GetPathSuffix($AbsFolderSrc, $diritem)
        $private:src_folder = $diritem.FullName
        $private:dst_folder = $FolderDst + $suffix
        $private:dst_folder_abs = $AbsFolderDst + $suffix

        $private:covet_path = Join-Path $src_folder "covet.txt"
        $private:covets = [Covets]::Read($covet_path)
        if ($null -ne $covets) {
            $private:names_unused = [Collections.Generic.List[string]]::new()
            $covets.per_name.Keys | ForEach-Object { $names_unused.Add($_) }
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
                    $private:treatment = Get-DefaultTreatment $src_name
                    switch ($treatment) {
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
                            $private:covet = $covets.GetCovet($src_name)
                            if ($null -eq $covet) {
                                $covet = [Covet]::new($treatment)
                            }
                            $private:dst_name = switch ($covet.treatment) {
                                "copy" { $src_name }
                                "convert" { $src_basename + ".m4a" }
                                "ignore" { $null }
                                default { throw }
                            }
                            if ($null -ne $dst_name) {
                                $src_count += 1
                                $dst_count += 1
                                $private:dst_path = Join-Path $dst_folder $dst_name
                                $private:dst_path_abs = Join-Path $dst_folder_abs $dst_name
                                switch ($mode) {
                                    "publish_changes" {
                                        Build-Destination $dst_folder
                                        Update-FileFromSrc $covet $src_path $src_LastWriteTime $dst_name $dst_path $dst_path_abs
                                    }
                                    "register_removes" {
                                        if (-not (Test-Path -LiteralPath $dst_path)) {
                                            Write-Host "${covet_path}: adding ""$src_name"""
                                            $covets.per_name[$src_name] = [Covet]::new("ignore")
                                            ++$covet_changes
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Get-Job | Receive-Job | Write-Error
                }
            foreach ($n in $names_unused) {
                switch ($mode) {
                    "publish_changes" {
                        Write-Warning "${covet_path}: unused item ""$n"""
                    }
                    "register_removes" {
                        Write-Host "${covet_path}: removing ""$n"""
                        if (-not $covets.per_name.Remove($n)) {
                            throw "Lost covet!"
                        }
                        ++$covet_changes
                    }
                }
            }
            if ($covet_changes) {
                if ($covets.IsUseful()) {
                    $covets.WriteTo($covet_path)
                }
                else {
                    Write-Output $covet_path
                }
            }
            if ($src_count -and -not $dst_count) {
                Write-Warning "Unused folder $src_folder"
            }
        }
    }
}

function Update-FolderDst {
    process {
        $diritem = [IO.DirectoryInfo] $_
        $suffix = [IoUtils]::GetPathSuffix($AbsFolderDst, $diritem)
        $src_folder = $FolderSrc + $suffix
        if (Test-Path -LiteralPath $src_folder) {
            $covet_path = Join-Path $src_folder "covet.txt"
            $covets = [Covets]::Read($covet_path)

            $diritem.EnumerateFiles() |
                ForEach-Object {
                    if ($_.Name.StartsWith("cover.")) {
                        Write-Output $_
                    }
                    else {
                        $justifying_names = if ($_.Name -eq $ImageName) {
                            "cover.jpg", "cover.jpeg", "cover.png", "cover.webp"
                        }
                        else {
                            $_.Name,
                            ($_.BaseName + ".ac3"),
                            ($_.BaseName + ".flac"),
                            ($_.BaseName + ".webm"),
                            ($_.BaseName + ".m4a"),
                            ($_.BaseName + ".mp2"),
                            ($_.BaseName + ".mp3"),
                            ($_.BaseName + ".ogg"),
                            ($_.BaseName + ".wma") | Where-Object { $covets.DoesNotExclude($_) }
                        }
                        $justifying_paths = $justifying_names | ForEach-Object { Join-Path $src_folder $_ }
                        if ((Test-Path -LiteralPath $justifying_paths) -notcontains $true) {
                            Write-Output $_
                        }
                    }
                }
        }
        else {
            Write-Output $_
        }
    }
}

foreach ($mode in $modes) {
    $doomed = switch ($mode) {
        "clean_up" {
            # Full recursion in Dst but only reporting progress on the 1st level
            $diritems = @(Get-ChildItem $FolderDst -Directory)
            0..($diritems.Count - 1) | ForEach-Object {
                $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
                $dir = $diritems[$_]
                $dst_folder = $FolderDst + [IoUtils]::GetPathSuffix($AbsFolderDst, $dir)
                Write-Progress -Activity "Looking for spurious files" -Status $dst_folder -PercentComplete $pct
                Get-ChildItem $dir -Directory -Recurse
            } | Update-FolderDst
        }
        default {
            # Full recursion in Src but only reporting progress on the 2nd level
            Write-Progress -Activity "Looking in folder" -Status $FolderSrc -PercentComplete -1
            $diritems = @(Get-ChildItem $FolderSrc -Directory | Get-ChildItem -Directory)
            0..($diritems.Count - 1) | ForEach-Object {
                $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
                $dir = $diritems[$_]
                $src_folder = $FolderSrc + [IoUtils]::GetPathSuffix($AbsFolderSrc, $dir)
                Write-Progress -Activity "Looking in folder" -Status $src_folder -PercentComplete $pct
                @($dir) + (Get-ChildItem $dir -Directory -Recurse)
            } | Update-FolderSrc
        }
    }
    # Remove-Item does not delete streamed IO.FileInfo instances if their path contains
    # wildcard characters.
    # .Delete() on each works, but we want confirmation "all" to work on all.
    if ($null -ne $doomed) {
        Remove-Item -LiteralPath $doomed -Confirm
    }
}

Get-Job | Wait-Job | Receive-Job | Write-Error
