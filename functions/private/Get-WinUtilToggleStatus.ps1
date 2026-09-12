Function Get-WinUtilToggleStatus ($ToggleSwitch) {

    $ToggleSwitchReg = $sync.configs.tweaks.$ToggleSwitch.registry

    foreach ($regentry in $ToggleSwitchReg) {
        # Read only the requested value. Enumerating the entire key can throw an
        # InvalidCastException for an unrelated malformed value (issue #6).
        # Provider-qualified HKU paths avoid creating a drive during a read.
        $path = $regentry.Path -replace '^HKU:\\', 'Registry::HKEY_USERS\'
        $regstate = $null
        $key = $null
        try {
            $key = Get-Item -LiteralPath $path -ErrorAction Stop
            $regstate = $key.GetValue($regentry.Name, $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        } catch [System.Management.Automation.ItemNotFoundException] {
            # A missing key/value has the configured Windows default.
        } catch {
            # Unreadable state is not evidence that an optimization is enabled.
            Write-Warning "无法读取开关 $ToggleSwitch 的注册表值 $path [$($regentry.Name)]：$($_.Exception.Message)"
            return $false
        } finally {
            if ($null -ne $key) { $key.Dispose() }
        }

        if ($null -eq $regstate) {
            switch ([string]$regentry.DefaultState) {
                "true"  { $regstate = $regentry.Value }
                "false" { $regstate = $regentry.OriginalValue }
            }
        }

        if ($regstate -ne $regentry.Value) {
            return $false
        }
    }

    return $true
}
