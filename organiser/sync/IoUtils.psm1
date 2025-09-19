class IoUtils {
    # Given an absolute path and a directory found under it, return the diverging part.
    static [string] GetPathSuffix([string] $AbsPath, [IO.DirectoryInfo] $DirItem) {
        $SubPath = $DirItem.FullName
        if (-not $SubPath.StartsWith($AbsPath)) {
            throw "Quirky path $SubPath does not start with $AbsPath"
        }
        return $DirItem.FullName.Substring($AbsPath.Length)
    }

    # Identify the file that a path links to.
    static [kernel32+FILE_ID_INFO] GetFileIdInfo([string] $InPath) {
        $fileIdInfo = New-Object kernel32+FILE_ID_INFO
        $size = [System.Runtime.InteropServices.Marshal]::SizeOf($fileIdInfo)
        $buffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($size)
        try {
            $fileHandle = [System.IO.File]::Open($InPath, 'Open', 'Read', 'Read').SafeFileHandle
            try {
                $ok = [kernel32]::GetFileInformationByHandleEx($fileHandle.DangerousGetHandle(), [kernel32]::FileIdInfo, $buffer, $size)
                if (-not $ok) {
                    throw New-Object System.ComponentModel.Win32Exception([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())
                }
                $fileIdInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($buffer, [Type][kernel32+FILE_ID_INFO])
            }
            finally {
                $fileHandle.Close()
            }
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($buffer)
        }
        return $fileIdInfo
    }

    static [bool] IsSameFile([string] $InPath1, $InPath2) {
        $fileIdInfo1 = [IoUtils]::GetFileIdInfo($InPath1)
        $fileIdInfo2 = [IoUtils]::GetFileIdInfo($InPath2)
        return $fileIdInfo2.VolumeSerialNumber -eq $fileIdInfo1.VolumeSerialNumber
        -and [msvcrt]::memcmp($fileIdInfo1.FileId, $fileIdInfo2.FileId, 16) -eq 0
    }
}
