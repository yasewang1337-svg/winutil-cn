# winutil-cn 构建脚本
# 1) 调用上游 Compile.ps1 把 config/xaml/functions 拼成 winutil.ps1
#    Compile.ps1 内部对单个文件读取失败是非终止的,会跳过继续(故此处不设 -Stop)。
# 2) 将 winutil.ps1 重存为 UTF-8 with BOM —— 否则 Windows PowerShell 5.1 会把中文当 GBK 解码导致乱码。
# 用法:pwsh -File 汉化\build-cn.ps1   然后(管理员)运行 .\winutil.ps1
#
# 注意:若安全软件(本机为火绒)隔离了某些 functions 脚本(典型如 Invoke-WPFPanelAutologinXXX,
#       因其改自动登录会写明文密码,杀毒高敏感),该函数会缺失,对应面板功能不可用,其余完整。
#       要恢复完整功能:在火绒"信任区"添加目录 W:\dev\projects\winutil-cn 后重跑本脚本。
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent   # repo root
Push-Location $root
try {
    & '.\Compile.ps1' 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object {
        Write-Warning ("编译时跳过(可能被安全软件拦截): " + $_.Exception.Message)
    }
    $w = Join-Path $root 'winutil.ps1'
    if (-not (Test-Path $w)) { throw 'Compile.ps1 未生成 winutil.ps1' }

    # 读(no-BOM)再以 BOM 重写,兼容 PowerShell 5.1 中文显示
    $content = [IO.File]::ReadAllText($w, [System.Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($w, $content, [System.Text.UTF8Encoding]::new($true))

    $size = (Get-Item $w).Length
    Write-Output ("构建完成: winutil.ps1  {0} 字节  UTF-8+BOM" -f $size)
    Write-Output ("完整性 - 含自动登录面板函数: {0}" -f $content.Contains('Invoke-WPFPanelAutologin'))
    Write-Output ("中文抽样 - 含『运行优化』: {0} / 含『浏览器』: {1}" -f $content.Contains('运行优化'), $content.Contains('浏览器'))
} finally { Pop-Location }
