function Show-WinUtilAppActions {
    param([string]$AppKey, $PlacementTarget, [switch]$Keyboard)
    if ([string]::IsNullOrWhiteSpace($AppKey) -or -not $sync.appPopup -or -not $sync.configs.applicationsHashtable.ContainsKey($AppKey)) { return }
    $app = $sync.configs.applicationsHashtable[$AppKey]
    $sync.appPopup.IsOpen = $false
    $sync.appPopupSelectedApp = $AppKey
    $sync.AppActionsKeyboard = [bool]$Keyboard
    $sync.AppActionsHeading.Text = [string]$app.content
    $offline = [bool]$PARAM_OFFLINE
    $sync.AppActionButtons.Install.IsEnabled = -not ($sync.ProcessRunning -or $offline -or ($sync.WPFInstall -and -not $sync.WPFInstall.IsEnabled))
    $sync.AppActionButtons.Uninstall.IsEnabled = -not ($sync.ProcessRunning -or $offline -or ($sync.WPFUninstall -and -not $sync.WPFUninstall.IsEnabled))
    $address = $null
    $hasWebsite = [Uri]::TryCreate([string]$app.link, [UriKind]::Absolute, [ref]$address) -and $address.Scheme -in @('https', 'http')
    $sync.AppActionButtons.Info.IsEnabled = $hasWebsite -and -not $offline
    $sync.AppActionButtons.Info.ToolTip = if ($offline) { '当前为离线浏览模式。' } elseif ($hasWebsite) { "在默认浏览器中打开：$($address.AbsoluteUri)" } else { '软件目录尚未提供有效官网。' }
    $sync.appPopup.PlacementTarget = $PlacementTarget
    $sync.appPopup.IsOpen = $true
}
