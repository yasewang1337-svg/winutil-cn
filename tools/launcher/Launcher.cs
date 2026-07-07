// WinUtil 中文汉化版 · 离线自包含启动器
//
// 设计要点：
//   · 自包含  —— 编译好的 winutil-cn.ps1 作为嵌入资源打进本 EXE，运行时释放到临时目录执行。
//                全程离线、不联网、不下载远程代码（区别于 irm|iex 那种下载器壳，也是 winget 收录的前提）。
//   · 透明    —— 不加壳、不混淆、不用 -EncodedCommand，只做「释放脚本 → 调用系统 PowerShell → 清理」，
//                以降低杀软启发式误报。
//   · 可靠    —— 管理员权限由 app.manifest 强制申请（启动即弹 UAC）；透传命令行参数（-Preset / -Config）；
//                等待子进程退出、透传退出码、清理临时文件。
//
// 兼容旧版 .NET Framework C# 编译器（C# 5），因此不使用字符串插值等新语法。

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

[assembly: AssemblyTitle("WinUtil 中文汉化版启动器")]
[assembly: AssemblyProduct("WinUtil-CN")]
[assembly: AssemblyDescription("WinUtil 中文汉化版 · 离线自包含启动器")]
[assembly: AssemblyCompany("Holha1337")]
[assembly: AssemblyCopyright("MIT · https://github.com/yasewang1337-svg/winutil-cn")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace WinUtilCN
{
    internal static class Launcher
    {
        // 嵌入资源的逻辑名，须与 build.ps1 里 /resource:...,<此名> 一致。
        private const string ScriptResource = "WinUtilCN.winutil-cn.ps1";

        private static int Main(string[] args)
        {
            string scriptPath = null;
            try
            {
                scriptPath = ExtractScript();
                return RunPowerShell(scriptPath, args);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("[WinUtil-CN] 启动失败：" + ex.Message);
                Console.Error.WriteLine("请到 https://github.com/yasewang1337-svg/winutil-cn/issues 反馈。");
                return 1;
            }
            finally
            {
                TryDelete(scriptPath);
            }
        }

        // 把嵌入的 winutil-cn.ps1 原样释放到临时文件（保留 UTF-8 BOM，供 PowerShell 5.1 正确解码中文）。
        private static string ExtractScript()
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream res = asm.GetManifestResourceStream(ScriptResource))
            {
                if (res == null)
                    throw new InvalidOperationException("EXE 内未找到嵌入的 winutil-cn.ps1 资源。");

                string path = Path.Combine(
                    Path.GetTempPath(),
                    "winutil-cn-" + Guid.NewGuid().ToString("N") + ".ps1");

                using (FileStream fs = new FileStream(path, FileMode.CreateNew, FileAccess.Write))
                {
                    res.CopyTo(fs);
                }
                return path;
            }
        }

        // 用 Windows PowerShell 5.1 运行脚本，并透传本进程收到的命令行参数。
        private static int RunPowerShell(string scriptPath, string[] args)
        {
            StringBuilder cmd = new StringBuilder();
            cmd.Append("-NoProfile -ExecutionPolicy Bypass -File ");
            cmd.Append(QuoteArg(scriptPath));
            for (int i = 0; i < args.Length; i++)
            {
                cmd.Append(' ');
                cmd.Append(QuoteArg(args[i]));
            }

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = ResolvePowerShell(),
                Arguments = cmd.ToString(),
                UseShellExecute = false,
            };

            using (Process p = Process.Start(psi))
            {
                p.WaitForExit();
                return p.ExitCode;
            }
        }

        // 定位系统自带的 Windows PowerShell 5.1；找不到则退回 PATH 查找。
        private static string ResolvePowerShell()
        {
            string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
            string ps = Path.Combine(system, "WindowsPowerShell\\v1.0\\powershell.exe");
            return File.Exists(ps) ? ps : "powershell.exe";
        }

        // 按 Windows 命令行规则给单个参数加引号（正确处理空格、引号、反斜杠）。
        private static string QuoteArg(string arg)
        {
            if (arg.Length > 0 && arg.IndexOfAny(new char[] { ' ', '\t', '\n', '\v', '"' }) < 0)
                return arg;

            StringBuilder sb = new StringBuilder();
            sb.Append('"');
            for (int i = 0; i < arg.Length; i++)
            {
                int backslashes = 0;
                while (i < arg.Length && arg[i] == '\\') { backslashes++; i++; }

                if (i == arg.Length)
                {
                    sb.Append('\\', backslashes * 2);
                    break;
                }
                else if (arg[i] == '"')
                {
                    sb.Append('\\', backslashes * 2 + 1);
                    sb.Append('"');
                }
                else
                {
                    sb.Append('\\', backslashes);
                    sb.Append(arg[i]);
                }
            }
            sb.Append('"');
            return sb.ToString();
        }

        private static void TryDelete(string path)
        {
            try
            {
                if (path != null && File.Exists(path))
                    File.Delete(path);
            }
            catch
            {
                // 临时文件清理失败可忽略：TEMP 目录由系统定期回收。
            }
        }
    }
}
