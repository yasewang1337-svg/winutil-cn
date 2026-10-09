function Invoke-WinUtilFeatureAction {
    <# Fixed system-panel targets and mirror operations; no script text from JSON. #>
    param([Parameter(Mandatory)][string]$Action)
    $systemDirectory = [Environment]::SystemDirectory
    switch -CaseSensitive -Exact ($Action) {
        'Panel.Control' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ErrorAction Stop }
        'Panel.Computer' { Start-Process -FilePath (Join-Path $systemDirectory 'mmc.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'compmgmt.msc')) -ErrorAction Stop }
        'Panel.Network' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'ncpa.cpl')) -ErrorAction Stop }
        'Panel.Power' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'powercfg.cpl')) -ErrorAction Stop }
        'Panel.Printer' { Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}' -ErrorAction Stop }
        'Panel.Region' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'intl.cpl')) -ErrorAction Stop }
        'Panel.Restore' { Start-Process -FilePath (Join-Path $systemDirectory 'rstrui.exe') -ErrorAction Stop }
        'Panel.Sound' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'mmsys.cpl')) -ErrorAction Stop }
        'Panel.System' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'sysdm.cpl')) -ErrorAction Stop }
        'Panel.Timedate' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'timedate.cpl')) -ErrorAction Stop }
        'Mirror.Pip.CN' { Invoke-WinUtilMirrorAction -Tool Pip }
        'Mirror.Pip.Official' { Invoke-WinUtilMirrorAction -Tool Pip -Reset }
        'Mirror.Npm.CN' { Invoke-WinUtilMirrorAction -Tool Npm }
        'Mirror.Npm.Official' { Invoke-WinUtilMirrorAction -Tool Npm -Reset }
        'Mirror.Yarn.CN' { Invoke-WinUtilMirrorAction -Tool Yarn }
        'Mirror.Yarn.Official' { Invoke-WinUtilMirrorAction -Tool Yarn -Reset }
        'Mirror.Conda.CN' { Invoke-WinUtilMirrorAction -Tool Conda }
        'Mirror.Conda.Official' { Invoke-WinUtilMirrorAction -Tool Conda -Reset }
        'Mirror.Go.CN' { Invoke-WinUtilMirrorAction -Tool Go }
        'Mirror.Go.Official' { Invoke-WinUtilMirrorAction -Tool Go -Reset }
        default { throw "不支持的按钮动作：$Action。" }
    }
}
