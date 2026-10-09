function Invoke-WinUtilMirrorAction {
    <# Confirm persistent package-manager configuration changes before execution. #>
    param([Parameter(Mandatory)][ValidateSet('Pip', 'Npm', 'Yarn', 'Conda', 'Go')][string]$Tool, [switch]$Reset)
    if ($sync.ProcessRunning) { throw '当前有任务正在运行，请等待结束后再修改软件源。' }
    $candidates = @{
        Pip = @('pip.exe'); Npm = @('npm.cmd'); Yarn = @('yarn.cmd', 'yarn.exe')
        Conda = @('conda.exe', 'conda.bat'); Go = @('go.exe')
    }
    $targets = @{
        Pip = 'https://pypi.tuna.tsinghua.edu.cn/simple'
        Npm = 'https://registry.npmmirror.com'; Yarn = 'https://registry.npmmirror.com'
        Conda = 'https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ 和 pkgs/free/'
        Go = 'https://goproxy.cn,direct'
    }
    $official = @{
        Pip = '移除 global.index-url 和 global.trusted-host，使用 pip 的其余配置/默认源'
        Npm = 'https://registry.npmjs.org'; Yarn = 'https://registry.yarnpkg.com'
        Conda = '移除当前配置的 channels，恢复默认频道'; Go = 'https://proxy.golang.org,direct'
    }
    $target = $targets[$Tool]
    if ($Reset) { $target = $official[$Tool] }
    # A modal dialog pumps UI events, so reserve before opening it as well.
    $sync.ProcessRunning = $true
    try {
        if (-not (Show-WinUtilTweakDialog -Title '确认修改软件源' -Message "$Tool 将写入持久配置，影响后续包下载。`n目标：$target`n`n不同配置文件或环境变量可能覆盖结果；恢复官方源不会还原此前的自定义地址。" -Confirm)) { return }
        $command = $null
        foreach ($candidate in $candidates[$Tool]) {
            $command = Get-Command -Name $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { break }
        }
        if (-not $command) { throw "未检测到 $Tool，请先安装该工具并重新打开 WinUtil。" }
        switch ($Tool) {
            'Pip' {
                if ($Reset) {
                    $configuration = Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', 'list')
                    foreach ($key in @('global.index-url', 'global.trusted-host')) {
                        if ($configuration -match "(?m)^$([regex]::Escape($key))=") {
                            Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', 'unset', $key) | Out-Null
                        }
                    }
                } else {
                    Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', 'set', 'global.index-url', $targets.Pip) | Out-Null
                }
            }
            'Npm' { Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', 'set', 'registry', $target) | Out-Null }
            'Yarn' { Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', 'set', 'registry', $target) | Out-Null }
            'Conda' {
                if ($Reset) {
                    $configuration = Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', '--get', 'channels', '--json') | ConvertFrom-Json -ErrorAction Stop
                    if ($configuration.success -ne $true -or $null -eq $configuration.get) {
                        throw '无法确认 conda 当前频道配置，已停止恢复操作。'
                    }
                    if ($configuration.get.PSObject.Properties.Name -contains 'channels') {
                        Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', '--remove-key', 'channels') | Out-Null
                    }
                } else {
                    foreach ($channel in @('https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/', 'https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/')) {
                        Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', '--add', 'channels', $channel) | Out-Null
                    }
                    Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('config', '--set', 'show_channel_urls', 'yes') | Out-Null
                }
            }
            'Go' { Invoke-WinUtilMirrorCommand -FilePath $command.Source -Arguments @('env', '-w', "GOPROXY=$target") | Out-Null }
        }
        Write-Host "$Tool 配置命令已成功执行。环境变量或项目配置仍可能覆盖此设置。" -ForegroundColor Green
    } catch {
        throw "$Tool 配置未完成：$($_.Exception.Message)`n已成功执行的步骤可能已经生效，请检查该工具配置。"
    } finally {
        $sync.ProcessRunning = $false
    }
}
