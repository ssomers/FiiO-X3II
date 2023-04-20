Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant
Set-Variable ImageQuality -Value 95 -Option Constant
Set-Variable ImageWidth -Value 320 -Option Constant
Set-Variable ImageHeight -Value 240 -Option Constant
Set-Variable InsetHeight -Value 208 -Option Constant
Set-Variable FfmpegQuality -Value 7 -Option Constant
$FfmpegJobs = (Get-WmiObject -Class Win32_processor | ForEach-Object NumberOfCores) - 1
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

$FfmpegDate_by_conversion = @{
    [Treatment] "convert_usual" = [datetime]"2023-03-03"
    [Treatment] "convert_hdcd"  = [datetime]"2023-03-03"
    [Treatment] "convert_xfeed" = [datetime]"2023-04-20"
    [Treatment] "convert_mono"  = [datetime]"2023-03-03"
    [Treatment] "convert_left"  = [datetime]"2023-03-03"
    [Treatment] "convert_right" = [datetime]"2023-03-03"
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

    $DstImage = New-Object -TypeName Drawing.Bitmap -ArgumentList $ImageWidth, $ImageHeight
    $Inset = New-Object -TypeName Drawing.Rectangle -ArgumentList $InsetX, $InsetY, $InsetWidth, $InsetHeight
    [Drawing.Graphics]::FromImage($DstImage).DrawImage($SrcImage, $Inset)
    $srcImage.Dispose()

    $DstStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList 48e3
    $jpegParams = New-Object -TypeName Drawing.Imaging.EncoderParameters -ArgumentList 1
    $jpegParams.Param[0] = New-Object -TypeName Drawing.Imaging.EncoderParameter -ArgumentList ([Drawing.Imaging.Encoder]::Quality, $ImageQuality)
    $jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object -Property FormatDescription -EQ "JPEG"
    $DstImage.Save($DstStream, $jpegCodec, $jpegParams)
    $DstStream.Close()
    $NewDstBytes = $DstStream.ToArray()

    try {
        $OldDstBytes = [System.IO.File]::ReadAllBytes($DstPath)
        $change = "Updating"
    }
    catch [System.IO.FileNotFoundException] {
        $OldDstBytes = [byte[]] @()
        $change = "Creating"
    }
    if ($OldDstBytes.Length -ne $NewDstBytes.Length -Or
        [msvcrt]::memcmp($OldDstBytes, $NewDstBytes, $NewDstBytes.Length) -ne 0) {
        Write-Host "$change $DstPath"
        [System.IO.File]::WriteAllBytes($DstPath, $NewDstBytes)
    }
    else {
        #Write-Host "Checked $DstPath"
    }
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
[string]$dst_top = Resolve-Path -LiteralPath $FolderDst

Get-ChildItem $FolderSrc -Directory |
Get-ChildItem -Directory |
ForEach-Object {
    $src_folder = $FolderSrc + (Get-Path-Suffix $src_top $_.FullName)
    Write-Progress "Looking in $src_folder"
    Write-Output $_
} |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $suffix = Get-Path-Suffix $src_top $_.FullName
    $src_folder = $FolderSrc + $suffix
    $dst_folder = $FolderDst + $suffix
    $dst_folder_abs = $dst_top + $suffix

    $covet_path = Join-Path $src_folder "covet.txt"
    $covets = Get-Covets $covet_path
    if ($null -ne $covets) {
        $names_unused = New-Object Collections.Generic.List[string]
        $covets.Keys | ForEach-Object { $names_unused.Add($_) }
        $src_count = 0
        $dst_count = 0

        $_.EnumerateFiles() |
        ForEach-Object {
            $src_path = $_.FullName
            $src_name = $_.Name
            $src_basename = $_.BaseName
            $src_LastWriteTime = $_.LastWriteTime
            [void] $names_unused.Remove($src_name)
            $covet = $covets[$src_name]
            [Treatment] $treatment = if ($null -ne $covet) { $covet } else { Get-DefaultTreatment $src_name }
            switch ($treatment) {
                "unknown" { Write-Warning "Unknown $src_path" }
                "ignore" {}
                default {
                    ++$src_count
                    $dst_name = switch ($treatment) {
                        "cover" { $ImageName }
                        "copy" { $src_name }
                        default { $src_basename + ".m4a" }
                    }
                    $dst_path = Join-Path $dst_folder $dst_name
                    # Must use absolute path because Convert-Cover somehow gets a different working
                    # directory (and Start-Process without -WorkingDirectory too).
                    $dst_path_abs = Join-Path $dst_folder_abs $dst_name
                    if (-Not (Test-Path -LiteralPath $dst_folder)) {
                        Write-Host "Creating $dst_folder"
                        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
                    }
                    switch ($treatment) {
                        "cover" {
                            Convert-Cover $src_path $dst_path_abs
                        }
                        "copy" {
                            ++$dst_count
                            if (-Not (Test-Path -LiteralPath $dst_path)) {
                                Write-Host "Linking $dst_path"
                                New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
                            }
                            elseif ((Get-FileID $src_path) -ne (Get-FileID $dst_path)) {
                                Write-Warning "Unhinged $dst_path"
                            }
                        }
                        default {
                            ++$dst_count
                            $dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
                            if ($null -eq $dst -Or -Not $dst.Length -Or $FfmpegDate_by_conversion[$treatment] -gt $dst.LastWriteTime -Or $src_LastWriteTime -gt $dst.LastWriteTime) {
                                $filters = New-Object Collections.Generic.List[string]
                                $ffmpeg_arglist = New-Object Collections.Generic.List[string]
                                $ffmpeg_arglist += @("-loglevel", "warning")
                                $ffmpeg_arglist += @("-i", "`"$src_path`"")
                                switch ($treatment) {
                                    "convert_hdcd" { $filters += @("hdcd=disable_autoconvert=0") }
                                    "convert_xfeed" { $filters += @("crossfeed=level_in=1:strength=.5") }
                                    "convert_left" { $filters += @("pan=mono|c0=FL") }
                                    "convert_rght" { $filters += @("pan=mono|c0=FR") }
                                    "convert_mono" { $ffmpeg_arglist += @("-ac", 1) }
                                }
                                $filters += @("aformat=sample_rates=48000|44100|32000|24000|22050|16000|12000|11025|8000|7350")
                                $filters += @("volume=replaygain=album")
                                $ffmpeg_arglist += @("-filter:a", ($filters -join ","))
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

Get-Job | Wait-Job | Receive-Job | Write-Error
Read-Host " :: Press Enter to close :"
