function Initialize-WinUtilPackageUiCallbacks {
    <# Create delegates on the UI runspace. Workers only publish data and invoke these existing delegates. #>
    $sync.PackageProgressAction = [action]{ Show-WPFInstallAppBusy -text $sync.PackageProgressText }
    $sync.PackageHideAction = [action]{ Hide-WPFInstallAppBusy }
    $sync.PackageResultsAction = [action]{
        if (@($sync.LastPackageResults | Where-Object Status -eq 'Failed').Count) {
            Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
        } else { Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark' }
        $choice = Show-WinUtilPackageDialog -Title '软件操作结果' -Description $sync.PackageResultSummary -Details $sync.PackageResultDetails -PrimaryLabel $sync.PackageRetryLabel -CloseLabel '关闭' -LogDirectory $sync.LastPackageRun.LogDirectory
        $sync.PackageRetryRequested = ($choice -eq 'Primary')
    }
    $sync.PackageErrorAction = [action]{
        Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
        $null = [Windows.MessageBox]::Show("软件任务异常中止，未确认全部完成。`r`n$($sync.PackageOperationError)`r`n请查看操作日志。", 'WinUtil CN')
    }
}
