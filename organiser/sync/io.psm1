# Given an absolute path and a FullName found under it, return the diverging part.
function Get-PathSuffix {
    param (
        [string] $AbsPath,
        [string] $SubPath
    )
    if (-Not $SubPath.StartsWith($AbsPath)) {
        Throw "Quirky path $SubPath does not start with $AbsPath"
    }
    $SubPath.Substring($AbsPath.Length)
}

# Identify file linked to from a path.
function Get-FileID {
    param (
        [string] $LiteralPath
    )
    (fsutil file queryFileID $LiteralPath) -Split " " |  Select-Object -Last 1
}
