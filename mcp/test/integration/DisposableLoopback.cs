// Test-only adapter lifecycle. Never used by the shipped MCP runtime.
// SetupAPI is deliberately scoped to one newly generated device instance. Do not
// replace this with UpdateDriverForPlugAndPlayDevices (which matches all devices).
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;

namespace WinUtilMcp.Integration {
    public sealed class DisposableLoopback : IDisposable {
        [StructLayout(LayoutKind.Sequential)]
        struct DeviceInfo {
            public uint Size;
            public Guid ClassGuid;
            public uint DevInst;
            public IntPtr Reserved;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct InstallParams {
            public uint Size, Flags, FlagsEx;
            public IntPtr Window, Callback, CallbackContext, FileQueue, ClassReserved;
            public uint Reserved;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string DriverPath;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DriverInfo {
            public uint Size, DriverType;
            public IntPtr Reserved;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Description;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Manufacturer;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Provider;
            public System.Runtime.InteropServices.ComTypes.FILETIME Date;
            public ulong Version;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct RemoveParams {
            public uint HeaderSize, Function, Scope, HardwareProfile;
        }
        [DllImport("setupapi.dll", SetLastError = true)]
        static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid ClassGuid, IntPtr Window);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiCreateDeviceInfoW(IntPtr Set, string Name, ref Guid ClassGuid, string Description, IntPtr Window, uint Flags, ref DeviceInfo Device);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiSetDeviceRegistryPropertyW(IntPtr Set, ref DeviceInfo Device, uint Property, byte[] Buffer, uint Length);
        [DllImport("setupapi.dll", SetLastError = true)]
        static extern bool SetupDiCallClassInstaller(uint Function, IntPtr Set, ref DeviceInfo Device);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiGetDeviceInstallParamsW(IntPtr Set, ref DeviceInfo Device, ref InstallParams Parameters);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiSetDeviceInstallParamsW(IntPtr Set, ref DeviceInfo Device, ref InstallParams Parameters);
        [DllImport("setupapi.dll", SetLastError = true)]
        static extern bool SetupDiBuildDriverInfoList(IntPtr Set, ref DeviceInfo Device, uint DriverType);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiEnumDriverInfoW(IntPtr Set, ref DeviceInfo Device, uint DriverType, uint Index, ref DriverInfo Driver);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiSetSelectedDriverW(IntPtr Set, ref DeviceInfo Device, ref DriverInfo Driver);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiGetDeviceInstanceIdW(IntPtr Set, ref DeviceInfo Device, StringBuilder Id, uint Length, out uint RequiredLength);
        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SetupDiSetClassInstallParamsW(IntPtr Set, ref DeviceInfo Device, ref RemoveParams Parameters, uint Size);
        [DllImport("setupapi.dll", SetLastError = true)]
        static extern bool SetupDiDestroyDeviceInfoList(IntPtr Set);
        [DllImport("newdev.dll", SetLastError = true)]
        static extern bool DiInstallDevice(IntPtr Window, IntPtr Set, ref DeviceInfo Device, ref DriverInfo Driver, uint Flags, [MarshalAs(UnmanagedType.Bool)] out bool NeedReboot);

        IntPtr set = new IntPtr(-1);
        DeviceInfo device;
        bool registered;
        public string InstanceId { get; private set; }
        public string DriverProvider { get; private set; }
        public string DriverDescription { get; private set; }
        public bool Removed { get; private set; }

        static void AssertDisposableRunner() {
            if (Environment.GetEnvironmentVariable("GITHUB_ACTIONS") != "true" ||
                Environment.GetEnvironmentVariable("RUNNER_ENVIRONMENT") != "github-hosted" ||
                Environment.GetEnvironmentVariable("RUNNER_OS") != "Windows" ||
                Environment.GetEnvironmentVariable("WINUTIL_MCP_DISPOSABLE_TEST") != "1")
                throw new InvalidOperationException("DISPOSABLE_RUNNER_REQUIRED: real device changes are allowed only in the explicit hosted-runner test job.");
            if (!Environment.Is64BitProcess) throw new InvalidOperationException("A 64-bit test process is required.");
            using (var identity = WindowsIdentity.GetCurrent()) {
                if (!new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator))
                    throw new InvalidOperationException("The disposable runner must already be elevated; this helper never elevates.");
            }
        }
        static void Check(bool okay, string operation) {
            if (!okay) {
                int error = Marshal.GetLastWin32Error();
                throw new Win32Exception(error, operation + " (Win32 " + error + ": " + new Win32Exception(error).Message + ")");
            }
        }
        public static DisposableLoopback Create() {
            AssertDisposableRunner();
            string inf = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "INF", "netloop.inf");
            if (!File.Exists(inf)) throw new FileNotFoundException("The Windows inbox loopback INF is unavailable; no driver will be downloaded.", inf);
            var result = new DisposableLoopback();
            try {
                Guid netClass = new Guid("4d36e972-e325-11ce-bfc1-08002be10318");
                result.set = SetupDiCreateDeviceInfoList(ref netClass, IntPtr.Zero);
                Check(result.set != new IntPtr(-1), "SetupDiCreateDeviceInfoList");
                result.device.Size = (uint)Marshal.SizeOf(typeof(DeviceInfo));
                string name = "WINUTILMCP_" + Guid.NewGuid().ToString("N");
                Check(SetupDiCreateDeviceInfoW(result.set, name, ref netClass, "WinUtil MCP disposable DNS test", IntPtr.Zero, 1, ref result.device), "SetupDiCreateDeviceInfo"); // DICD_GENERATE_ID
                byte[] hardwareIds = Encoding.Unicode.GetBytes("*MSLOOP\0\0");
                Check(SetupDiSetDeviceRegistryPropertyW(result.set, ref result.device, 1, hardwareIds, (uint)hardwareIds.Length), "Set newly created device hardware ID"); // SPDRP_HARDWAREID
                Check(SetupDiCallClassInstaller(0x19, result.set, ref result.device), "DIF_REGISTERDEVICE");
                result.registered = true;
                var id = new StringBuilder(512);
                uint required;
                Check(SetupDiGetDeviceInstanceIdW(result.set, ref result.device, id, (uint)id.Capacity, out required), "Read created device instance ID");
                result.InstanceId = id.ToString();
                if (!result.InstanceId.StartsWith("ROOT\\" + name + "\\", StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The created device instance does not have the unique requested identity.");

                var install = new InstallParams();
                install.Size = (uint)Marshal.SizeOf(typeof(InstallParams));
                Check(SetupDiGetDeviceInstallParamsW(result.set, ref result.device, ref install), "Get device installation parameters");
                install.Flags |= 0x00010000 | 0x00800000; // DI_ENUMSINGLEINF | DI_QUIETINSTALL
                install.DriverPath = inf;
                Check(SetupDiSetDeviceInstallParamsW(result.set, ref result.device, ref install), "Restrict compatible-driver search to inbox netloop.inf");
                Check(SetupDiBuildDriverInfoList(result.set, ref result.device, 2), "Build compatible driver list"); // SPDIT_COMPATDRIVER
                var driver = new DriverInfo();
                driver.Size = (uint)Marshal.SizeOf(typeof(DriverInfo));
                Check(SetupDiEnumDriverInfoW(result.set, ref result.device, 2, 0, ref driver), "Read compatible inbox loopback driver");
                Check(SetupDiSetSelectedDriverW(result.set, ref result.device, ref driver), "Select compatible driver for the new device only");
                result.DriverProvider = driver.Provider;
                result.DriverDescription = driver.Description;
                bool needReboot;
                Check(DiInstallDevice(IntPtr.Zero, result.set, ref result.device, ref driver, 0, out needReboot), "Install inbox driver on the new device only");
                Check(SetupDiGetDeviceInstallParamsW(result.set, ref result.device, ref install), "Read installation result");
                if (needReboot || (install.Flags & (0x00000080 | 0x00000100)) != 0)
                    throw new InvalidOperationException("Installing the test adapter requires a restart; the test cannot proceed.");
                return result;
            } catch (Exception error) {
                try { result.Dispose(); }
                catch (Exception cleanup) { throw new AggregateException("Device setup and scoped cleanup both failed.", error, cleanup); }
                throw;
            }
        }
        public void Dispose() {
            AssertDisposableRunner();
            if (set == new IntPtr(-1)) return;
            try {
                if (registered) {
                    var remove = new RemoveParams { HeaderSize = 8, Function = 0x05, Scope = 1, HardwareProfile = 0 }; // DIF_REMOVE, DI_REMOVEDEVICE_GLOBAL
                    Check(SetupDiSetClassInstallParamsW(set, ref device, ref remove, (uint)Marshal.SizeOf(typeof(RemoveParams))), "Scope removal to the created device");
                    Check(SetupDiCallClassInstaller(0x05, set, ref device), "Remove the created loopback device");
                    registered = false;
                    Removed = true;
                }
            } finally {
                SetupDiDestroyDeviceInfoList(set);
                set = new IntPtr(-1);
            }
        }
    }
}
