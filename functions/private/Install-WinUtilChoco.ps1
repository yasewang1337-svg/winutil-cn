function Install-WinUtilChoco {

    <#

    .SYNOPSIS
        Checks Chocolatey availability and directs missing installations to the official guide

    #>
    if ((Test-WinUtilPackageManager -choco) -eq "installed") {
        return
    }

    throw '未安装 Chocolatey。请按官方说明手动安装：https://chocolatey.org/install ，安装后重启 WinUtil；也可以在设置中改用默认的 WinGet 软件包管理器。'
}
