function Invoke-WPFImpex {
    <# .SYNOPSIS
        Save or preview a selection list. GUI import does not execute system changes.
    #>
    param([ValidateSet('import','export')][string]$type, [string]$Config)

    if ($sync.ProcessRunning) { Write-Warning '请等待当前任务结束后再导入或导出清单。'; return }
    if (-not $Config) {
        $dialog = if ($type -eq 'export') { New-Object System.Windows.Forms.SaveFileDialog } else { New-Object System.Windows.Forms.OpenFileDialog }
        try {
            $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
            $dialog.Filter = '装机清单 (*.json)|*.json'
            $dialog.Title = if ($type -eq 'export') { '保存当前装机清单' } else { '导入装机清单（只选择，不执行）' }
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
            $Config = $dialog.FileName
        } finally { $dialog.Dispose() }
    }
    try {
        if ($type -eq 'export') {
            $selected = @($sync.selectedApps) + @($sync.selectedTweaks) + @($sync.selectedToggles) + @($sync.selectedFeatures)
            $selected = @($selected | Where-Object { $_ } | ForEach-Object { [string]$_ } | Select-Object -Unique)
            if (-not $selected.Count) { throw '还没有选择项目，请先勾选软件或设置再保存。' }
            [IO.File]::WriteAllText([IO.Path]::GetFullPath($Config), (ConvertTo-Json -InputObject $selected), [Text.UTF8Encoding]::new($true))
            if ($sync.Form) { $null = [Windows.MessageBox]::Show("已保存 $($selected.Count) 项到：`r`n$Config`r`n清单不包含个人文件或软件数据。", '装机清单') }
            return
        }
        $text = if ($Config -match '^https?://') { (Invoke-WebRequest -Uri $Config -UseBasicParsing -ErrorAction Stop).Content } else { [IO.File]::ReadAllText([IO.Path]::GetFullPath($Config)) }
        $decoded = $text | ConvertFrom-Json -ErrorAction Stop
        $items = @($decoded)
        if (-not $items.Count) { throw '清单为空，保留当前选择。' }
        $validated = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $items) {
            if ($item -isnot [string]) { throw '清单格式不正确：需要由软件或设置编号组成的 JSON 数组，保留当前选择。' }
            $exists = if ($item -like 'WPFInstall*') { $sync.configs.applicationsHashtable.$item }
                elseif ($item -like 'WPFTweaks*' -or $item -like 'WPFToggle*') { $sync.configs.tweaks.$item }
                elseif ($item -like 'WPFFeature*') { $sync.configs.feature.$item }
                else { $null }
            if (-not $exists) { throw "当前版本不认识清单项目：$item。请核对清单版本；当前选择未更改。" }
            if (-not $validated.Contains($item)) { $validated.Add($item) }
        }
        if ($sync.Form) {
            $toggleCount = @($validated | Where-Object { $_ -like 'WPFToggle*' }).Count
            $message = "即将用清单中的 $($validated.Count) 项替换当前选择，不会安装软件或执行系统修改。"
            if ($toggleCount) { $message += "`r`n其中 $toggleCount 个立即生效的开关只保存在清单中；请到设置页查看现状后手动调整。" }
            if ([Windows.MessageBox]::Show($message, '导入装机清单', 'OKCancel', 'Information') -ne 'OK') { return }
        }
        $sync.selectedApps = [System.Collections.Generic.List[string]]::new()
        $sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
        $sync.selectedToggles = [System.Collections.Generic.List[string]]::new()
        $sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
        Update-WinUtilSelections -flatJson $validated.ToArray()
        if ($sync.Form) { Reset-WPFCheckBoxes -doToggles $false }
    } catch {
        if ($sync.Form) { $null = [Windows.MessageBox]::Show($_.Exception.Message, '清单未完成', 'OK', 'Warning') }
        else { throw }
    }
}
