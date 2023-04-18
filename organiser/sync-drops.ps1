Set-Variable FolderSrc -Value "src" -Option Constant
Set-Variable FolderDst -Value "X3" -Option Constant
Set-Variable ImageName -Value "folder.jpg" -Option Constant

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

[string]$dst_top = Resolve-Path -LiteralPath $FolderDst

Get-ChildItem $FolderDst -Recurse -Directory |
ForEach-Object {
    $suffix = Get-Path-Suffix $dst_top $_.FullName
    $src_folder = $FolderSrc + $suffix

    if (-Not (Test-Path -LiteralPath $src_folder)) {
        Write-Output $_
    }
    else {
        $_.EnumerateFiles() |
        ForEach-Object {
            $names = if ($_.Name -eq $ImageName) {
                @("cover.jpg", "cover.jpeg", "cover.png", "cover.webm")
            }
            else {
                @($_.Name,
                  ($_.BaseName + ".ac3"),
                  ($_.BaseName + ".flac"),
                  ($_.BaseName + ".webm")
                )
            }
            $t = foreach ($n in $names) { Join-Path $src_folder $n | Test-Path }
            if ($t -NotContains $true) {
                Write-Output $_.FullName
            }
        }
    }
} |
Remove-Item -Confirm

Read-Host " :: Press Enter to close :"
