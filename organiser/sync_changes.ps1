Set-Variable SourcePattern -Value "*.src" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant
Set-Variable ImageQuality -Value 95 -Option Constant
Set-Variable ImageWidth -Value 320 -Option Constant
Set-Variable ImageHeight -Value 240 -Option Constant
Set-Variable InsetHeight -Value 208 -Option Constant

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
        Write-Error ("Cannot read " + $SrcPath)
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
        $change = "updated"
    }
    catch [System.IO.FileNotFoundException] {
        $OldDstBytes = [byte[]] @()
        $change = "created"
    }
    if ($OldDstBytes.Length -ne $DstStream.Length -Or
        [msvcrt]::memcmp($OldDstBytes, $DstStream.GetBuffer(), $DstStream.Length) -ne 0) {
        $DstStream.Close()
        [System.IO.File]::WriteAllBytes($DstPath, $DstStream.ToArray())
        Write-Output ("$DstPath $change")
    }
    else {
        #Write-Output ("$DstPath OK")
    }
}

function Get-FileID {
    param (
        [string] $LiteralPath
    )
    (fsutil file queryFileID $LiteralPath) -Split " " |  Select-Object -Last 1
}

Get-ChildItem -Directory -Filter $SourcePattern |
Get-ChildItem -Directory -Recurse |
ForEach-Object {
    $src_folder = Resolve-Path -LiteralPath $_.FullName -Relative
    Write-Progress $src_folder
    $c = $src_folder -Split '\\'
    if ($c[0] -ne "." -Or -Not ($c[1] -Like $SourcePattern)) {
        Throw ("Quirky Path " + $src_folder)
    }
    $c[1] = $c[1].Substring(0, $c[1].Length - $SourcePattern.Length + 1)
    $dst_folder = $c -Join '\\'
    $c[1] += ".tmp"
    $int_folder = $c -Join '\\'

    $cut_path = Join-Path $src_folder "cut.txt"
    $cuts = [string[]]@()
    $cuts += Get-Content -LiteralPath $cut_path -Encoding UTF8 -ErrorAction Ignore

    $src_count = 0
    $dst_count = 0
    $conversions = @()
    $conversions_missing = 0

    if (-Not (Test-Path -LiteralPath $dst_folder)) {
        New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
    }
    $_.EnumerateFiles() |
    ForEach-Object {
        $src_path = $_.FullName
        $src_name = $_.Name
        $dst_name = $null
        $convert = $false
        if ($src_name -Like "*.aac" -Or $src_name -Like "*.m4a" -Or $src_name -Like "*.mp3" -Or $src_name -Like "*.ogg" -Or $src_name -Like "*.wma") {
            $dst_name = $src_name
        }
        elseif ($src_name -Like "*.ac3" -Or $src_name -Like "*.flac") {
            $dst_name = $_.BaseName + ".m4a"
            $convert = $true
        }
        elseif ($src_name -eq "cover.jpg" -Or $src_name -eq "cover.png") {
            $dst_path = Join-Path $dst_folder $ImageName
            Convert-Cover $src_path $dst_path
        }
        elseif (-Not($src_name -Like "*.txt" -Or $src_name -Like "*.pdf" -Or $src_name -Like "*.webp" -Or $src_name -Like "*.iso" -Or $_.BaseName -eq "cover_org")) {
            Write-Warning ("Spurious " + (Join-Path $src_folder $_))
        }
        if ($dst_name) {
            $dst_path = Join-Path $dst_folder $dst_name
            if ($cuts -And $cuts.Contains($src_name)) {
                if (Test-Path -LiteralPath $dst_path) {
                    Write-Warning ("Spurious " + $dst_path)
                }
            }
            else {
                if ($convert) {
                    if (-Not (Test-Path -LiteralPath $dst_path)) {
                        Write-Warning ("Missing " + $dst_path)
                        ++$conversions_missing
                    }
                    $conversions += $_
                }
                else {
                    if (-Not (Test-Path -LiteralPath $dst_path)) {
                        New-Item -ItemType "HardLink" -Path $dst_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
                    }
                    elseif ((Get-FileID $src_path) -ne (Get-FileID $dst_path)) {
                        Write-Warning ("Unhinged " + $dst_path)
                    }
                }
                ++$dst_count
            }
            ++$src_count
            $cuts = $cuts | Where-Object { $_ -ne $src_name }
        }
    }
    if ($conversions_missing) {
        if (-Not (Test-Path -LiteralPath $int_folder)) {
            New-Item -ItemType "Directory" -Path $int_folder | Out-Null
        }
        if (-Not (Test-Path -LiteralPath $dst_folder)) {
            New-Item -ItemType "Directory" -Path $dst_folder | Out-Null
        }
        foreach ($conversion in $conversions) {
            $src_path = $conversion.FullName
            $int_path = Join-Path $int_folder $conversion.Name
            if (Test-Path -LiteralPath $int_path) {
                if ((Get-FileID $src_path) -ne (Get-FileID $int_path)) {
                    Write-Warning ("Unhinged " + $int_path)
                }
            }
            else {
                New-Item -ItemType "HardLink" -Path $int_path -Target ([WildcardPattern]::Escape($src_path)) | Out-Null
            }
        }
        Write-Output ("Prepared " + $int_folder)
    }
    ForEach ($n in $cuts) {
        Write-Warning ($cut_path + ": " + "unused item " + $n)
    }
    if ($src_count -And -Not $dst_count) {
        Write-Warning ("Unused folder " + $src_folder)
    }
}

Read-Host " :: Press Enter to close :"
