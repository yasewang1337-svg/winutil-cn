function Set-WinUtilRegistry {
    <# .SYNOPSIS Sets one registry value and propagates failures to the caller. #>
    [CmdletBinding()]
    param($Name, $Path, $Type, $Value, [switch]$LiteralValue)
    if ($Path -match '^HKU:\\') { $Path = $Path -replace '^HKU:', 'Registry::HKEY_USERS' }
    if (-not $LiteralValue -and $Value -is [string] -and $Value -eq '<RemoveEntry>') {
        $state = Get-WinUtilTweakRegistryState -Path $Path -Name $Name
        if ($state.Exists) { Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop }
        return
    }
    if (-not (Test-Path -LiteralPath $Path -ErrorAction Stop)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -LiteralPath $Path -Name $Name -Type $Type -Value $Value -Force -ErrorAction Stop
}
