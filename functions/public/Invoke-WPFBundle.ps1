function Invoke-WPFBundle {
    <#

    .SYNOPSIS
        预览应用组合，确认后将用户勾选的软件加入已选清单，不清空已有选择、不立即安装。
        组合数据来自 config/bundles.json,由按钮 WPFBundle<id> 触发。

    .PARAMETER BundleId
        bundles.json 里的组合 id,例如 cn_office。

    #>
    param([string]$BundleId)

    $bundle = $sync.configs.bundles.$BundleId
    if (-not $bundle) {
        Write-Host "未找到应用组合: $BundleId"
        return
    }

    $plan = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $sync.configs.applications `
        -SelectedApps @($sync.selectedApps) -InstalledPrograms @($sync.InstalledPrograms))
    $result = Show-WinUtilBundleDialog -Bundle $bundle -Plan $plan -Owner $sync.Form
    if (-not $result.Confirmed) { return }

    # Revalidate the dialog result against this bundle's available candidates.
    $available = @($plan | Where-Object { $_.IsAvailable } | ForEach-Object { $_.Id })
    $selected = @($result.Apps | Where-Object { $_ -in $available } | Select-Object -Unique)
    if (-not $selected.Count) { return }
    $before = @($sync.selectedApps).Count
    Update-WinUtilSelections -flatJson $selected
    Reset-WPFCheckBoxes -doToggles $false -checkboxfilterpattern "WPFInstall*"

    $added = @($sync.selectedApps).Count - $before
    Write-Host "组合「$($bundle.region)·$($bundle.name)」已加入清单，新增 $added 项。请在安装页确认后点击安装/更新。"
}
