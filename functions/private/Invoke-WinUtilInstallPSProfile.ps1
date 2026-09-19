function Invoke-WinUtilInstallPSProfile {
    $guideUrl = 'https://github.com/ChrisTitusTech/powershell-profile'
    try {
        Start-Process -FilePath $guideUrl -ErrorAction Stop
    } catch {
        throw "无法打开 PowerShell 配置指南，请手动访问 $guideUrl 。$($_.Exception.Message)"
    }
}
