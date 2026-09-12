function Invoke-WinUtilPackageUiAction {
    param([ValidateSet('Progress', 'Hide', 'Results', 'Error')][string]$Action)
    $callback = $sync["Package${Action}Action"]
    if ($null -eq $callback) { throw '软件任务的界面回调尚未初始化。' }
    # In particular, Results must finish before a worker reads the user's retry choice.
    $sync.Form.Dispatcher.Invoke([action]$callback)
}
