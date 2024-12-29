Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class msvcrt {
        [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)]
        public static extern int memcmp(byte[] p1, byte[] p2, long count);
    }

    public class kernel32 {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetFileInformationByHandleEx(
            IntPtr hFile,
            int FileInformationClass,
            IntPtr lpFileInformation,
            uint dwBufferSize
        );

        [StructLayout(LayoutKind.Sequential)]
        public struct FILE_ID_INFO {
            public ulong VolumeSerialNumber;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
            public byte[] FileId;
        }

        public const int FileIdInfo = 0x12;
    }
"@
