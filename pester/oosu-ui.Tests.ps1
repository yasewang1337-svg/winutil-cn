BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root 'functions/public/Invoke-WPFOOSU.ps1'))))
    function Invoke-WinUtilVerifiedTool { [CmdletBinding()] param($Tool); throw 'Tests must not run external tools.' }
    function Invoke-WPFRunspace { [CmdletBinding()] param($ScriptBlock); throw 'Tests must not create application runspaces.' }
    function Show-WinUtilTweakDialog { param($Title, $Message); throw 'Tests must not open a real dialog.' }
}

Describe 'O&O responsive UI entry point' {
    BeforeEach {
        $dispatcher = [pscustomobject]@{}
        $dispatcher | Add-Member -MemberType ScriptMethod -Name BeginInvoke -Value {
            param([delegate]$Callback, [object[]]$Arguments)
            $script:sync.OOSUUiDispatchCount++
            $null = $Callback.DynamicInvoke($Arguments)
        }
        $script:sync = [hashtable]::Synchronized(@{
            Form = [pscustomobject]@{ Dispatcher = $dispatcher }
            ProcessRunning = $true
            OOSURunning = $false
            OOSUUiDispatchCount = 0
        })
        $script:oosuWorker = $null
        Mock Invoke-WPFRunspace { $script:oosuWorker = $ScriptBlock }
        Mock Invoke-WinUtilVerifiedTool { [pscustomobject]@{ Tool = 'OOSU'; ExitCode = 0 } }
        Mock Show-WinUtilTweakDialog {}
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Invoke-WebRequest { throw 'The UI wrapper must not download content itself.' }
        Mock Start-Process { throw 'The UI wrapper must not launch an unchecked process.' }
    }

    It 'dispatches once without waiting and reserves busy state before the worker starts' {
        Mock Invoke-WPFRunspace {
            $script:sync.OOSURunning | Should -BeTrue
            $script:oosuWorker = $ScriptBlock
        }
        Invoke-WPFOOSU
        Invoke-WPFOOSU
        $script:sync.OOSURunning | Should -BeTrue
        $script:oosuWorker | Should -BeOfType ([scriptblock])
        Should -Invoke Invoke-WPFRunspace -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 0 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '正在准备或运行' }
        $script:sync.ProcessRunning | Should -BeTrue
    }

    It 'keeps its busy state through execution and releases it after success without changing other tasks' {
        Mock Invoke-WinUtilVerifiedTool {
            $script:sync.OOSURunning | Should -BeTrue
            [pscustomobject]@{ Tool = 'OOSU'; ExitCode = 0 }
        }
        Invoke-WPFOOSU
        & $script:oosuWorker
        $script:sync.OOSURunning | Should -BeFalse
        $script:sync.ProcessRunning | Should -BeTrue
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 1 -Exactly -ParameterFilter { $Tool -eq 'OOSU' -and $ErrorAction -eq 'Stop' }
        Should -Invoke Show-WinUtilTweakDialog -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'shows validation failure on the UI dispatcher and allows another attempt' {
        Mock Invoke-WinUtilVerifiedTool { throw '签名发布者校验失败，已停止运行。' }
        Invoke-WPFOOSU
        & $script:oosuWorker
        $script:sync.OOSURunning | Should -BeFalse
        $script:sync.OOSUUiDispatchCount | Should -Be 1
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter {
            $Title -eq 'O&O ShutUp10++ 启动失败' -and $Message -match '签名发布者校验失败'
        }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '签名发布者校验失败' }
        Invoke-WPFOOSU
        Should -Invoke Invoke-WPFRunspace -Times 2 -Exactly
        $script:sync.ProcessRunning | Should -BeTrue
    }

    It 'does not leave the tool busy when background dispatch fails' {
        Mock Invoke-WPFRunspace { throw 'runspace pool unavailable' }
        Invoke-WPFOOSU
        $script:sync.OOSURunning | Should -BeFalse
        $script:sync.ProcessRunning | Should -BeTrue
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 0 -Exactly
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter {
            $Message -match '无法启动.*后台任务' -and $Message -match 'runspace pool unavailable'
        }
    }

    It 'retains the error in console output when a closing window cannot dispatch a dialog' {
        $script:sync.Form.Dispatcher | Add-Member -MemberType ScriptMethod -Name BeginInvoke -Force -Value { throw 'dispatcher unavailable' }
        Mock Invoke-WinUtilVerifiedTool { throw '网络下载失败。' }
        Invoke-WPFOOSU
        & $script:oosuWorker
        $script:sync.OOSURunning | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '网络下载失败' }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '无法显示.*错误窗口' }
    }
}
