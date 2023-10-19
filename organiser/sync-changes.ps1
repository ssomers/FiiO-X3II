$ErrorActionPreference = "Inquire"

New-Variable -Option Constant FolderSrc -Value "src"
New-Variable -Option Constant FolderDst -Value "X3"
New-Variable -Option Constant AbsFolderSrc -Value (Resolve-Path -LiteralPath $FolderSrc).Path
New-Variable -Option Constant AbsFolderDst -Value (Resolve-Path -LiteralPath $FolderDst).Path
New-Variable -Option Constant ImageName -Value "folder.jpg"
New-Variable -Option Constant ImageQuality -Value 95
New-Variable -Option Constant ImageWidth -Value 320
New-Variable -Option Constant ImageHeight -Value 240
New-Variable -Option Constant InsetHeight -Value 208
New-Variable -Option Constant FfmpegQuality -Value 7
New-Variable -Option Constant FfmpegJobs -Value ([Environment]::ProcessorCount - 1)
New-Variable -Option Constant FfmpegDate_anyhow -Value ([datetime]"2023-03-03")
New-Variable -Option Constant FfmpegDate_by_conversion -Value @{
    [Conversion] "cnv_bass"  = [datetime]"2023-10-18"
    [Conversion] "cnv_hdcd"  = [datetime]"2023-03-03"
    [Conversion] "cnv_xfeed" = [datetime]"2023-04-20"
    [Conversion] "cnv_mono"  = [datetime]"2023-03-03"
    [Conversion] "cnv_left"  = [datetime]"2023-03-03"
    [Conversion] "cnv_right" = [datetime]"2023-03-03"
}
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
        $this.conversions = [Collections.Generic.List[Conversion]]::new(1)
    }
}

function Get-Covets {
    param (
        [string] $InPath
    )
    $covets = [Collections.Generic.Dictionary[string, Covet]]::new(16)
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

Add-Type -AssemblyName System.Drawing
Add-Type -Assembly PresentationCore
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class msvcrt {
        [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)]
        public static extern int memcmp(byte[] p1, byte[] p2, long count);
    }
"@

function Convert-Cover {
    param (
        [string] $SrcPath,
        [string] $DstPath
    )
    try {
        $SrcImage = [Drawing.Image]::FromFile($SrcPath)
    }
    catch {
        Write-Warning "Cannot read ${SrcPath}: $($_.FullyQualifiedErrorId)"
        return
    }
    $InsetWidth = $SrcImage.Width / $SrcImage.Height * $InsetHeight
    $InsetX = ($ImageWidth - $InsetWidth) / 2
    $InsetY = ($ImageHeight - $InsetHeight) / 2

    $DstImage = [Drawing.Bitmap]::new($ImageWidth, $ImageHeight)
    $Inset = [Drawing.Rectangle]::new($InsetX, $InsetY, $InsetWidth, $InsetHeight)
    [Drawing.Graphics]::FromImage($DstImage).DrawImage($SrcImage, $Inset)
    $srcImage.Dispose()

    $DstStream = [IO.MemoryStream]::new(48e3)
    $jpegParams = [Drawing.Imaging.EncoderParameters]::new(1)
    $jpegParams.Param[0] = [Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality, $ImageQuality)
    $jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object -Property FormatDescription -EQ "JPEG"
    $DstImage.Save($DstStream, $jpegCodec, $jpegParams)
    $DstStream.Close()
    $NewDstBytes = $DstStream.ToArray()

    try {
        $OldDstBytes = [IO.File]::ReadAllBytes($DstPath)
        $change = "Updating"
    }
    catch [IO.FileNotFoundException] {
        $OldDstBytes = [byte[]] @()
        $change = "Creating"
    }
    if ($OldDstBytes.Length -ne $NewDstBytes.Length -Or
        [msvcrt]::memcmp($OldDstBytes, $NewDstBytes, $NewDstBytes.Length) -ne 0) {
        Write-Host "$change $DstPath"
        [IO.File]::WriteAllBytes($DstPath, $NewDstBytes)
    }
    else {
        #Write-Host "Checked $DstPath"
    }
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
        if ($FfmpegDate_by_conversion[$c] -gt $LastWriteTime) {
            return $true
        }
    }
    $false
}

function Get-FileID {
    param (
        [string] $LiteralPath
    )
    (fsutil file queryFileID $LiteralPath) -Split " " |  Select-Object -Last 1
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

function Update-Folder {
    param (
        [IO.DirectoryInfo] $diritem
    )

    $suffix = Get-Path-Suffix $AbsFolderSrc $diritem.FullName
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

        $diritem.EnumerateFiles() |
        ForEach-Object {
            $src_path = $_.FullName
            $src_name = $_.Name
            $src_basename = $_.BaseName
            $src_LastWriteTime = $_.LastWriteTime
            [void] $names_unused.Remove($src_name)
            $covet = $covets[$src_name]
            if ($null -eq $covet) {
                $covet = [Covet]::new((Get-Default-Treatment $src_name))
            }
            switch ($covet.treatment) {
                "unknown" { Write-Warning "Unknown $src_path" }
                "ignore" {}
                default {
                    ++$src_count
                    $dst_name = switch ($covet.treatment) {
                        "cover" { $ImageName }
                        "copy" { $src_name }
                        "convert" { $src_basename + ".m4a" }
                    }
                    $dst_path = Join-Path $dst_folder $dst_name
                    # Must use absolute path because Convert-Cover somehow gets a different working
                    # directory (and Start-Process without -WorkingDirectory too).
                    $dst_path_abs = Join-Path $dst_folder_abs $dst_name
                    if (-Not (Test-Path -LiteralPath $dst_folder)) {
                        Write-Host "Creating $dst_folder"
                        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
                    }
                    switch ($covet.treatment) {
                        "cover" {
                            Convert-Cover $src_path $dst_path_abs
                        }
                        "copy" {
                            ++$dst_count
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
                            ++$dst_count
                            $dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
                            if ($null -eq $dst -Or -Not $dst.Length -Or (Compare-Dates $dst.LastWriteTime $covet.conversions) -Or $src_LastWriteTime -gt $dst.LastWriteTime) {
                                $ffmpeg_arglist = [Collections.Generic.List[string]]::new(8);
                                $ffmpeg_arglist += @("-loglevel", "warning")
                                $ffmpeg_arglist += @("-i", "`"$src_path`"")
                                $filters = [Collections.Generic.List[string]]::new(8);
                                foreach ($c in $covet.conversions.GetEnumerator()) {
                                    switch ($c) {
                                        "cnv_bass" { $filters += @("bass=gain=6") }
                                        "cnv_hdcd" { $filters += @("hdcd=disable_autoconvert=0") }
                                        "cnv_xfeed" { $filters += @("crossfeed=level_in=1:strength=.5") }
                                        "cnv_left" { $filters += @("pan=mono| c0=FL") }
                                        "cnv_rght" { $filters += @("pan=mono| c0=FR") }
                                        "cnv_mono" { $ffmpeg_arglist += @("-ac", 1) }
                                    }
                                }
                                $filters += @("aformat=sample_rates=48000|44100|32000|24000|22050|16000|12000|11025|8000|7350")
                                $filters += @("volume=replaygain=album")
                                $ffmpeg_arglist += @("-filter:a", "`"$($filters -join ",")`"")
                                $ffmpeg_arglist += @("-q:a", $FfmpegQuality)
                                $ffmpeg_arglist += @("`"$dst_path_abs`"", "-y")

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
            }
            Get-Job | Receive-Job | Write-Error
        }
        ForEach ($n in $names_unused) {
            Write-Warning "${covet_path}: unused item ""$n"""
        }
        if ($src_count -And -Not $dst_count) {
            Write-Warning "Unused folder $src_folder"
        }
    }
}

# Full recursion but only reporting progress on the 2nd level
Write-Progress -Activity "Looking in folder" -Status $FolderSrc -PercentComplete -1
$diritems = @(Get-ChildItem $FolderSrc -Directory | Get-ChildItem -Directory)
0..($diritems.Count - 1) | ForEach-Object {
    $pct = 1 + $_ / $diritems.Count * 99 # start at 1 because 0 draws as 100
    $dir = $diritems[$_]
    $src_folder = $FolderSrc + (Get-Path-Suffix $AbsFolderSrc $dir.FullName)
    Write-Progress -Activity "Looking in folder" -Status $src_folder -PercentComplete $pct
    Update-Folder $dir
    $dir | Get-ChildItem -Directory -Recurse | ForEach-Object { Update-Folder $_ }
}

Get-Job | Wait-Job | Receive-Job | Write-Error
