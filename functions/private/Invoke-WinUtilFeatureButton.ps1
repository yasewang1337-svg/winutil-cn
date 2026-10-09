function Invoke-WinUtilFeatureButton {
    <# Bind each configured button to its reviewed function or fixed action. #>
    param([Parameter(Mandatory)][string]$Button, [Parameter(Mandatory)]$Configuration)

    if ($Configuration.Type -cne 'Button' -or $Configuration.InvokeScript) {
        throw '按钮配置无效，已停止执行。请更新或重新下载程序。'
    }
    $functions = @{
        WPFFixesNTPPool = 'Invoke-WPFFixesNTPPool'
        WPFFeatureInstall = 'Invoke-WPFFeatureInstall'
        WPFPanelAutologin = 'Invoke-WPFPanelAutologin'
        WPFFixesUpdate = 'Invoke-WPFFixesUpdate'
        WPFFixesNetwork = 'Invoke-WPFFixesNetwork'
        WPFPanelDISM = 'Invoke-WPFSystemRepair'
        WPFFixesWinget = 'Invoke-WPFFixesWinget'
        WPFWinUtilInstallPSProfile = 'Invoke-WinUtilInstallPSProfile'
        WPFWinUtilUninstallPSProfile = 'Invoke-WinUtilUninstallPSProfile'
        WPFWinUtilSSHServer = 'Invoke-WPFSSHServer'
    }
    $actions = @{
        WPFPanelControl = 'Panel.Control'; WPFPanelComputer = 'Panel.Computer'
        WPFPanelNetwork = 'Panel.Network'; WPFPanelPower = 'Panel.Power'
        WPFPanelPrinter = 'Panel.Printer'; WPFPanelRegion = 'Panel.Region'
        WPFPanelRestore = 'Panel.Restore'; WPFPanelSound = 'Panel.Sound'
        WPFPanelSystem = 'Panel.System'; WPFPanelTimedate = 'Panel.Timedate'
        WPFFeatureMirrorPipCN = 'Mirror.Pip.CN'; WPFFeatureMirrorPipReset = 'Mirror.Pip.Official'
        WPFFeatureMirrorNpmCN = 'Mirror.Npm.CN'; WPFFeatureMirrorNpmReset = 'Mirror.Npm.Official'
        WPFFeatureMirrorYarnCN = 'Mirror.Yarn.CN'; WPFFeatureMirrorYarnReset = 'Mirror.Yarn.Official'
        WPFFeatureMirrorCondaCN = 'Mirror.Conda.CN'; WPFFeatureMirrorCondaReset = 'Mirror.Conda.Official'
        WPFFeatureMirrorGoCN = 'Mirror.Go.CN'; WPFFeatureMirrorGoReset = 'Mirror.Go.Official'
    }
    if ($functions.ContainsKey($Button)) {
        if ($Configuration.function -cne $functions[$Button] -or $Configuration.Action) {
            throw '按钮处理函数与内置定义不一致，已停止执行。'
        }
        $command = Get-Command -Name $functions[$Button] -CommandType Function -ErrorAction Stop
        & $command
    } elseif ($actions.ContainsKey($Button)) {
        if ($Configuration.Action -cne $actions[$Button] -or $Configuration.function) {
            throw '按钮动作与内置定义不一致，已停止执行。'
        }
        Invoke-WinUtilFeatureAction -Action $actions[$Button]
    } else {
        throw "不支持的按钮：$Button。请更新或重新下载程序。"
    }
}
