$ImageQuality = 95
$ImageWidth = 320
$ImageHeight = 224
$InsetHeight = 224

Add-Type -AssemblyName System.Drawing
$jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders().Where{ $_.FormatDescription -eq "JPEG" }[0]
$jpegParams = [Drawing.Imaging.EncoderParameters]::new()
$jpegParams.Param[0] = [Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality, $ImageQuality)

function Convert-Cover {
    param (
        [string] $SrcPath,
        [string] $DstPath,
        [string] $DstPathAbs
    )
    $ActualSrcPath = $SrcPath
    if ($SrcPath.EndsWith(".webp")) {
        $ActualSrcPath = "$SrcPath.png"
        & "c:\Programs\libwebp\bin\dwebp.exe" -o "$ActualSrcPath" -- "$SrcPath" 2>nul
    }
    try {
        $SrcImage = [Drawing.Image]::FromFile($ActualSrcPath)
    }
    catch {
        Write-Warning "Cannot read ${SrcPath}: $($_.FullyQualifiedErrorId)"
        return
    }
    $InsetWidth = $SrcImage.Width / $SrcImage.Height * $InsetHeight
    $InsetX = ($ImageWidth - $InsetWidth) / 2
    $InsetY = 0 # ($ImageHeight - $InsetHeight) / 2

    $DstImage = [Drawing.Bitmap]::new($ImageWidth, $ImageHeight)
    $Inset = [Drawing.Rectangle]::new($InsetX, $InsetY, $InsetWidth, $InsetHeight)
    [Drawing.Graphics]::FromImage($DstImage).DrawImage($SrcImage, $Inset)
    $srcImage.Dispose()
    if ($ActualSrcPath -ne $SrcPath) {
        Remove-Item $ActualSrcPath
    }

    $DstStream = [IO.MemoryStream]::new(48kb)
    $DstImage.Save($DstStream, $jpegCodec, $jpegParams)
    $DstStream.Close()
    $NewDstBytes = $DstStream.ToArray()

    try {
        $OldDstBytes = [IO.File]::ReadAllBytes($DstPathAbs)
        $change = "Updating"
    }
    catch [IO.FileNotFoundException] {
        $OldDstBytes = [byte[]] @()
        $change = "Creating"
    }
    if ($OldDstBytes.Length -ne $NewDstBytes.Length -or
        [msvcrt]::memcmp($OldDstBytes, $NewDstBytes, $NewDstBytes.Length) -ne 0) {
        Write-Host "$change $DstPath"
        [IO.File]::WriteAllBytes($DstPathAbs, $NewDstBytes)
    }
    else {
        #Write-Host "Checked $DstPath"
    }
}

Export-ModuleMember -Function Convert-Cover
