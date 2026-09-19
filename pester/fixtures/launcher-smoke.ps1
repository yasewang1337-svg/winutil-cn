# This is the only payload embedded by tools/Test-Launcher.ps1. It performs no
# system changes and must not import or start the real WinUtil application.
$ErrorActionPreference = 'Stop'
if (-not $env:WINUTIL_LAUNCHER_TEST_OUTPUT) {
    throw 'This harmless fixture requires the launcher test output path.'
}
$result = [ordered]@{
    Arguments = @($args)
    PowerShellMajorVersion = $PSVersionTable.PSVersion.Major
}
[IO.File]::WriteAllText(
    $env:WINUTIL_LAUNCHER_TEST_OUTPUT,
    ($result | ConvertTo-Json -Depth 4),
    (New-Object Text.UTF8Encoding($true))
)
exit 37
