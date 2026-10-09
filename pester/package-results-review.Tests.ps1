BeforeAll {
    foreach ($name in @('Get-WinUtilPackageResultView', 'Show-WinUtilPackageDialog', 'Invoke-WinUtilPackageOperation')) {
        . ([scriptblock]::Create((Get-Content (Join-Path $PSScriptRoot "../functions/private/$name.ps1") -Raw -Encoding UTF8)))
    }
    . ([scriptblock]::Create((Get-Content (Join-Path $PSScriptRoot '../functions/public/Invoke-WPFPackageResults.ps1') -Raw -Encoding UTF8)))
    function New-ReviewResult($status, $id, $action = 'Install') {
        [pscustomobject]@{
            Status = $status; StatusText = $status; Id = $id; Name = $id; PackageId = $id
            Manager = 'Winget'; Action = $action; NeedsReboot = ($status -eq 'RebootRequired')
            Reason = 'Example reason'; ExitCode = 0; ExitCodeHex = '0x00000000'
            OutputPath = "C:\logs\$id.out"; ErrorPath = "C:\logs\$id.err"
            Plan = [pscustomobject]@{ Id = $id; PackageId = $id; Action = $action; Manager = 'Winget' }
        }
    }
}

Describe 'Reopening software results' {
    BeforeEach {
        $sync = @{ ProcessRunning = $false; LastPackageResults = @(); LastPackageRun = $null }
        Mock Show-WinUtilPackageDialog { 'Close' }
        Mock Invoke-WinUtilPackageOperation {}
    }
    It 'explains an empty session without starting any operation' {
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter {
            $Description -match '当前会话还没有' -and $Details -match '重新启动' -and -not $PrimaryLabel
        }
        Should -Invoke Invoke-WinUtilPackageOperation -Times 0
    }
    It 'does not reopen or retry an old result while another task runs' {
        $sync.ProcessRunning = $true
        $sync.LastPackageResults = @(New-ReviewResult Failed Example.Failed)
        Mock Show-WinUtilPackageDialog { 'Primary' }
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter { $Title -eq '软件任务正在进行' -and -not $PrimaryLabel }
        Should -Invoke Invoke-WinUtilPackageOperation -Times 0
    }
    It 'reopens the snapshot with its per-item log paths without executing it' {
        $sync.LastPackageResults = @(New-ReviewResult Failed Example.Failed; New-ReviewResult Succeeded Example.Good)
        $sync.LastPackageRun = @{ LogDirectory = 'C:\logs\latest'; LogWarning = 'Log write warning' }
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter {
            $Results.Count -eq 2 -and $Description -match 'Log write warning' -and $Details -match 'Example.Good.out' -and $LogDirectory -eq 'C:\logs\latest'
        }
        Should -Invoke Invoke-WinUtilPackageOperation -Times 0
    }
    It 'requests a reviewed retry for individual failures only' {
        $sync.LastPackageResults = @(
            New-ReviewResult Succeeded Example.Good
            New-ReviewResult Failed Example.Failed
            New-ReviewResult RebootRequired Example.Reboot
            New-ReviewResult Failed all UpgradeAll
        )
        Mock Show-WinUtilPackageDialog { 'Primary' }
        Invoke-WPFPackageResults
        Should -Invoke Invoke-WinUtilPackageOperation -Times 1 -Exactly -ParameterFilter {
            $Plan.Count -eq 1 -and $Plan[0].Id -eq 'Example.Failed' -and -not $NonInteractive
        }
    }
    It 'does not offer or execute whole-manager upgrade retries' {
        $sync.LastPackageResults = @(New-ReviewResult Failed all UpgradeAll)
        Mock Show-WinUtilPackageDialog { 'Primary' }
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter { -not $PrimaryLabel }
        Should -Invoke Invoke-WinUtilPackageOperation -Times 0
    }
    It 'distinguishes an interrupted task from a session with no operations' {
        $sync.PackageOperationError = 'Example worker failure'
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter {
            $Description -match '异常中止' -and $Details -match 'Example worker failure'
        }
    }
    It 'preserves interruption context beside any partial results' {
        $sync.PackageOperationError = 'Example worker failure'
        $sync.LastPackageResults = @(New-ReviewResult Succeeded Example.Good)
        Invoke-WPFPackageResults
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter {
            $Description -match '以下仅为已取得的结果' -and $Results.Count -eq 1
        }
    }
    It 'keeps reboot requirements and skipped results distinct from failures' {
        $view = Get-WinUtilPackageResultView -Results @(
            New-ReviewResult Succeeded Example.Good
            New-ReviewResult Skipped Example.Skipped
            New-ReviewResult RebootRequired Example.Reboot
        )
        $view.Summary | Should -Match '成功 1 项 · 失败 0 项 · 已跳过 1 项 · 需重启 1 项'
        $view.Summary | Should -Match '保存工作'
        $view.RetryPlan.Count | Should -Be 0
    }
}
