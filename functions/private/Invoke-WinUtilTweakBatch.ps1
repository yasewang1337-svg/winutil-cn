function Invoke-WinUtilTweakBatch {
    <# .SYNOPSIS Executes selected changes with per-item results and guaranteed busy-state cleanup. #>
    param([string[]]$Tweaks, [switch]$Undo, [string]$DNSProvider = 'Default')
    $results = @()
    try {
        $ordered = @($Tweaks)
        if (-not $Undo) {
            $ordered = @($Tweaks | Where-Object { $_ -eq 'WPFTweaksRestorePoint' }) + @($Tweaks | Where-Object { $_ -ne 'WPFTweaksRestorePoint' })
        } else {
            # Most recently modified tweaks first, so overlapping recorded settings unwind in order.
            $ordered = @($Tweaks | Sort-Object { (Get-WinUtilTweakHistory -TweakId $_ | Where-Object { -not $_.Restored } | Select-Object -First 1).CreatedAt } -Descending)
        }
        $abort = $false
        for ($i = 0; $i -lt $ordered.Count; $i++) {
            $id = $ordered[$i]
            if ($abort) {
                $results += [pscustomobject]@{ TweakId = $id; Name = $sync.configs.tweaks.$id.Content; Status = 'Skipped'; Message = '创建还原点失败，后续修改已停止。'; HistoryId = $null }
                continue
            }
            if ($sync.Form -and $sync.TweakProgressAction) {
                $sync.TweakProgressLabel = "正在处理：$($sync.configs.tweaks.$id.Content)"
                $sync.TweakProgressPercent = $i / [Math]::Max($ordered.Count, 1) * 100
                $sync.Form.Dispatcher.Invoke($sync.TweakProgressAction)
            }
            $result = Invoke-WinUtilTweaks -CheckBox $id -undo ([bool]$Undo)
            $results += $result
            Write-Host "$($result.Name)：$($result.Message)"
            if (-not $Undo -and $id -eq 'WPFTweaksRestorePoint' -and $result.Status -ne 'Success') { $abort = $true }
        }
        if (-not $Undo -and $DNSProvider -ne 'Default') {
            $dnsResult = [pscustomobject]@{ TweakId = 'DNS'; Name = "DNS：$DNSProvider"; Status = 'Skipped'; Message = '创建还原点失败，DNS 未修改。'; HistoryId = $null }
            if (-not $abort) {
                Set-WinUtilDNS -DNSProvider $DNSProvider
                $dnsResult.Status = 'Unverified'
                $dnsResult.Message = 'DNS 命令已执行，当前流程未逐网卡核验结果且不记录原 DNS，请在网络设置中确认。'
            }
            $results += $dnsResult
        }
    } catch {
        $results += [pscustomobject]@{ TweakId = 'Batch'; Name = '执行流程'; Status = 'Failed'; Message = $_.Exception.Message; HistoryId = $null }
    } finally {
        $sync.LastTweakResults = @($results)
        $sync.ProcessRunning = $false
        if ($sync.Form -and $sync.TweakProgressAction) {
            $sync.TweakProgressLabel = '处理结束，请查看逐项结果'
            $sync.TweakProgressPercent = 100
            $sync.Form.Dispatcher.Invoke($sync.TweakProgressAction)
        }
        if ($sync.Form -and $sync.TweakResultsAction) {
            # Pass this batch's completed results; a later job may replace LastTweakResults.
            $sync.Form.Dispatcher.BeginInvoke($sync.TweakResultsAction, [object[]](, @($results))) | Out-Null
        }
    }
    # Keep the legacy latest-selection file for export/status consumers.
    if (-not $Undo) {
        $latest = @($results | Where-Object { $_.HistoryId } | ForEach-Object TweakId)
        $directory = Join-Path $env:LOCALAPPDATA 'WinUtil'
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        ConvertTo-Json -InputObject $latest | Set-Content -LiteralPath (Join-Path $directory 'lastrun.json') -Encoding UTF8
    }
}
