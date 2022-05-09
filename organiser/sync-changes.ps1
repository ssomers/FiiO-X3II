Set-Variable SourcePattern -Value "*.src" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant
Set-Variable ImageQuality -Value 95 -Option Constant
Set-Variable ImageWidth -Value 320 -Option Constant
Set-Variable ImageHeight -Value 240 -Option Constant
Set-Variable InsetHeight -Value 208 -Option Constant
Set-Variable FfmpegPath -Value "C:\Programs\ffmpeg\bin\ffmpeg.exe" -Option Constant
Set-Variable FfmpegQuality -Value 5 -Option Constant
Set-Variable FfmpegJobs -Value 5 -Option Constant

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
        Write-Error "Cannot read $SrcPath"
    }
    $InsetWidth = $SrcImage.Width / $SrcImage.Height * $InsetHeight
    $InsetX = ($ImageWidth - $InsetWidth) / 2
    $InsetY = ($ImageHeight - $InsetHeight) / 2

    $DstImage = New-Object -TypeName Drawing.Bitmap -ArgumentList $ImageWidth, $ImageHeight
    $Inset = New-Object -TypeName Drawing.Rectangle -ArgumentList $InsetX, $InsetY, $InsetWidth, $InsetHeight
    [Drawing.Graphics]::FromImage($DstImage).DrawImage($SrcImage, $Inset)

    $DstStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList 48e3
    $jpegParams = New-Object -TypeName Drawing.Imaging.EncoderParameters -ArgumentList 1
    $jpegParams.Param[0] = New-Object -TypeName Drawing.Imaging.EncoderParameter -ArgumentList ([Drawing.Imaging.Encoder]::Quality, $ImageQuality)
    $jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object -Property FormatDescription -eq "JPEG"
    $DstImage.Save($DstStream, $jpegCodec, $jpegParams)

    try {
        $OldDstBytes = [System.IO.File]::ReadAllBytes($DstPath)
        $change = "Updating"
    }
    catch [System.IO.FileNotFoundException] {
        $OldDstBytes = [byte[]] @()
        $change = "Creating"
    }
    if ($OldDstBytes.Length -ne $DstStream.Length -Or
        [msvcrt]::memcmp($OldDstBytes, $DstStream.GetBuffer(), $DstStream.Length) -ne 0) {
        $DstStream.Close()
        Write-Output ("$change $DstPath")
        [System.IO.File]::WriteAllBytes($DstPath, $DstStream.ToArray())
    }
    else {
        #Write-Output ("Checked $DstPath")
    }
}

function Get-FileID {
    param (
        [string] $LiteralPath
    )
    (fsutil file queryFileID $LiteralPath) -Split " " |  Select-Object -Last 1
}

Write-Output "`n`n`n`n`n"

Get-ChildItem -Directory -Filter $SourcePattern |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $src_folder = Resolve-Path -LiteralPath $_.FullName -Relative
    Write-Progress $src_folder
    $c = $src_folder -Split '\\'
    if ($c[0] -ne "." -Or -Not ($c[1] -Like $SourcePattern)) {
        Throw "Quirky Path $src_folder"
    }
    $c[1] = $c[1].Substring(0, $c[1].Length - $SourcePattern.Length + 1)
    $dst_folder = $c -Join '\\'

    $cut_path = Join-Path $src_folder "cut.txt"
    $cuts = [string[]]@()
    $cuts += Get-Content -LiteralPath $cut_path -Encoding UTF8 -ErrorAction Ignore

    $src_count = 0
    $dst_count = 0

    $_.EnumerateFiles() |
    ForEach-Object {
        $src_path = $_.FullName
        $src_name = $_.Name
        $converted_dst_name = $_.BaseName + ".m4a"
        $convert_cover = $false
        $dst_name = $null
        switch -Wildcard ($src_name) {
            "*.new.*" { break }
            "*.old.*" { break }
            "*.raw.*" { break }
            "cover.*" { $convert_cover = $true }
            "*.m4a" { $dst_name = $src_name }
            "*.mp2" { $dst_name = $src_name }
            "*.mp3" { $dst_name = $src_name }
            "*.ogg" { $dst_name = $src_name }
            "*.wma" { $dst_name = $src_name }
            "*.ac3" { $dst_name = $converted_dst_name }
            "*.flac" { $dst_name = $converted_dst_name }
            "*.webm" { $dst_name = $converted_dst_name }
            "*.iso" {}
            "*.llc" {}
            "*.mp4" {}
            "*.pdf" {}
            "*.txt" {}
            default { Write-Warning "Unknown $(Join-Path $src_folder $_)" }
        }
        if ($convert_cover -Or $dst_name) {
            if (-Not (Test-Path -LiteralPath $dst_folder)) {
                Write-Output "Creating $dst_folder"
                New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
            }
            $dst_folder = Resolve-Path -LiteralPath $dst_folder
            if ($convert_cover) {
                Convert-Cover $src_path (Join-Path $dst_folder $ImageName)
            }
            if ($dst_name) {
                $dst_path = Join-Path $dst_folder $dst_name
                if ($cuts -And $cuts.Contains($src_name)) {
                    if (Test-Path -LiteralPath $dst_path) {
                        Remove-Item -LiteralPath $dst_path -Confirm
                    }
                }
                else {
                    if ($src_name -eq $dst_name) {
                        if (-Not (Test-Path -LiteralPath $dst_path)) {
                            Write-Output "Linking $dst_path"
                            New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
                        }
                        elseif ((Get-FileID $src_path) -ne (Get-FileID $dst_path)) {
                            Write-Warning "Unhinged $dst_path"
                        }
                    }
                    else {
                        $dst = Get-Item -LiteralPath $dst_path -ErrorAction:SilentlyContinue
                        if ($null -eq $dst -Or $_.LastWriteTime -gt $dst.LastWriteTime) {
                            while ((Get-Job -State "Running").count -gt $FfmpegJobs) {
                                Start-Sleep -Seconds 1
                            }
                            Write-Output "Writing $dst_path"
                            Start-Job -ScriptBlock {
                                & $using:FfmpegPath -hide_banner -v warning -i $using:src_path -filter:a "aformat=sample_rates=22050|24000|32000|44100|48000,volume=replaygain=album" -map_metadata 0 -q $using:FfmpegQuality $using:dst_path -y 2>&1
                            } | Out-Null
                        }
                    }
                    ++$dst_count
                }
            }
            ++$src_count
            $cuts = $cuts | Where-Object { $_ -ne $src_name }
            Get-Job | Receive-Job
        }
    }
    ForEach ($n in $cuts) {
        Write-Warning ($cut_path + ": unused item " + $n)
    }
    if ($src_count -And -Not $dst_count) {
        Write-Warning ("Unused folder " + $src_folder)
    }
}

Get-Job | Wait-Job | Receive-Job
Read-Host " :: Press Enter to close :"
