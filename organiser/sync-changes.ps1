Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant
Set-Variable ImageQuality -Value 95 -Option Constant
Set-Variable ImageWidth -Value 320 -Option Constant
Set-Variable ImageHeight -Value 240 -Option Constant
Set-Variable InsetHeight -Value 208 -Option Constant
Set-Variable FfmpegPath -Value "C:\Programs\ffmpeg\bin\ffmpeg.exe" -Option Constant
Set-Variable FfmpegQuality -Value 7 -Option Constant
$FfmpegDate = [datetime]"2023-03-03"
$FfmpegJobs = (Get-WmiObject -Class Win32_processor | ForEach-Object NumberOfCores) - 1

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

    $cut_path = Join-Path $src_folder "cut.txt"
    $cuts = [string[]]@()
    $cuts += Get-Content -LiteralPath $cut_path -Encoding UTF8 -ErrorAction Ignore

    $src_count = 0
    $dst_count = 0

    $_.EnumerateFiles() |
    ForEach-Object {
        $src_path = $_.FullName
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
                ++$src_count
                if (-Not (Test-Path -LiteralPath $dst_folder)) {
                    Write-Host "Creating $dst_folder"
                    New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
                }
                $dst_folder = Resolve-Path -LiteralPath $dst_folder
                $dst_path = Join-Path $dst_folder $dst_name
            }
            "cover" {
                Convert-Cover $src_path $dst_path
            }
            "copy" {
                ++$dst_count
                $dst_path = Join-Path $dst_folder $src_name
                if (-Not (Test-Path -LiteralPath $dst_path)) {
                    Write-Host "Linking $dst_path"
                    New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
                }
                elseif ((Get-FileID $src_path) -ne (Get-FileID $dst_path)) {
                    Write-Warning "Unhinged $dst_path"
                }
            }
            "convert" {
                ++$dst_count
                $dst_name = $src_basename + ".m4a" -Replace ".hdcd.", "." 
                $dst_path = Join-Path $dst_folder $dst_name
                $ffmpeg_arglist = @("-hide_banner", "-v", "warning", "-i", "`"$src_path`"")
                $ffmpeg_arglist += switch -Wildcard ($src_name) {
                    "*.hdcd.*" { @("-filter:a", "hdcd", "-sample_fmt", "s32") }
                    default { @("-filter:a", "aformat=sample_rates=22050|24000|32000|44100|48000") }
                }
                $ffmpeg_arglist += @("-filter:a", "volume=replaygain=album", "-map_metadata", "0", "-q", $FfmpegQuality, "`"$dst_path`"", "-y")

                $dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
                if ($null -eq $dst -Or $FfmpegDate -gt $dst.LastWriteTime -Or $_.LastWriteTime -gt $dst.LastWriteTime) {
                    while ((Get-Job -State "Running").count -ge $FfmpegJobs) {
                        Start-Sleep -Seconds 0.5
                    }
                    Write-Host "Writing $dst_path"
                    Start-Job -ScriptBlock {
                        # Call operator & avoids the insane quoting (https://github.com/PowerShell/PowerShell/issues/5576)
                        # but doesn't allow setting priority and doesn't let the process complete on Ctrl-C.
                        $p = Start-Process -WindowStyle "Hidden" -PassThru "$using:FfmpegPath" -ArgumentList $using:ffmpeg_arglist
                        $p.PriorityClass = "BelowNormal"
                        $p.WaitForExit() | Out-Null
                    } | Out-Null
                }
            }
        }
        #Get-Job | Receive-Job
    }
    ForEach ($n in $cuts) {
        Write-Warning "${cut_path}: unused item ""$n"""
    }
    if ($src_count -And -Not $dst_count) {
        Write-Warning "Unused folder $src_folder"
    }
}

Get-Job | Wait-Job | Receive-Job
Read-Host " :: Press Enter to close :"
