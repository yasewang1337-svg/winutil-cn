function Complete-WinUtilRunspaceJobs {
    <# .SYNOPSIS Releases only completed task pipelines; the shared runspace pool stays open. #>
    if ($null -eq $sync.RunspaceJobs) { return }
    foreach ($job in $sync.RunspaceJobs.Values) {
        if (-not $job.Handle.IsCompleted) { continue }
        $removed = $null
        if (-not $sync.RunspaceJobs.TryRemove($job.Id, [ref]$removed)) { continue }
        try { $null = $removed.Pipeline.EndInvoke($removed.Handle) }
        catch { Write-Warning "后台任务未正常完成：$($_.Exception.Message)" }
        finally { $removed.Pipeline.Dispose() }
    }
}
