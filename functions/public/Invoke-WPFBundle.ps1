function Invoke-WPFBundle {
    <#

    .SYNOPSIS
        一键套用「应用组合推荐」:把指定组合里的全部应用加入已选(累加,不清空已有选择),并刷新安装页复选框。
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

    # 累加勾选(Update-WinUtilSelections 已做去重),再按选择列表刷新安装页 UI
    Update-WinUtilSelections -flatJson $bundle.apps
    Reset-WPFCheckBoxes -doToggles $false -checkboxfilterpattern "WPFInstall*"

    Write-Host "已套用组合「$($bundle.region)·$($bundle.name)」,新增/勾选 $($bundle.apps.Count) 个应用。"
}
