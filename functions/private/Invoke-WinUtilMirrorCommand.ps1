function Invoke-WinUtilMirrorCommand {
    <# The caller supplies a resolved application path and separate fixed arguments. #>
    param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)][string[]]$Arguments)
    # PS 5.1 wraps redirected native stderr as ErrorRecord; inspect the exit code
    # consistently on both engines instead of treating any stderr as a failure.
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $previousExitCode = $global:LASTEXITCODE
    try {
        $global:LASTEXITCODE = $null
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $global:LASTEXITCODE
    } finally {
        $global:LASTEXITCODE = $previousExitCode
    }
    if ($null -eq $exitCode -or $exitCode -ne 0) {
        throw "命令执行失败（退出码：$exitCode）：$([IO.Path]::GetFileName($FilePath)) $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return ($output -join "`n")
}
