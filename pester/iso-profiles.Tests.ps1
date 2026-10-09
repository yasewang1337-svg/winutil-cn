BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Get-WinUtilISOImageProfile','New-WinUtilISOWorkspace','Install-WinUtilISOAnswerFile','Initialize-WinUtilISOContents','Assert-WinUtilISOUSBTarget','Invoke-WinUtilISOScript')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/private/$name.ps1"))))
    }
    function Get-WindowsImage { [CmdletBinding()]param($ImagePath,$Index,[switch]$Mounted) throw 'Unmocked DISM read' }
    function Export-WindowsImage { [CmdletBinding()]param($SourceImagePath,$SourceIndex,$DestinationImagePath,$CompressionType,[switch]$CheckIntegrity) throw 'Unmocked image export' }
    function Export-WindowsDriver { [CmdletBinding()]param([switch]$Online,$Destination) throw 'Unmocked driver export' }
    function Mount-WindowsImage { [CmdletBinding()]param($ImagePath,$Index,$Path) throw 'Unmocked image mount' }
    function Dismount-WindowsImage { [CmdletBinding()]param($Path,[switch]$Save,[switch]$Discard) throw 'Unmocked image dismount' }
    function New-WinUtilToolWorkspace { throw 'Unmocked protected directory creation' }
    function robocopy { throw 'Unmocked copy' }
    function dism { throw 'Unmocked DISM' }
    function reg { throw 'Unmocked registry' }
    function New-TestImage($Name='Windows 10 Pro',$Version='10.0.19041.1',$Architecture=9,$Index=1) {
        [pscustomobject]@{ImageName=$Name; Version=$Version; Architecture=$Architecture; ImageIndex=$Index; InstallationType='Client'}
    }
}

Describe 'Windows image profile selection' {
    It 'recognizes <Name> using architecture and build metadata' -ForEach @(
        @{Name='Windows 10 Home';Version='10.0.19041.1';Expected='Windows10'},
        @{Name='Windows 10 Pro';Version='10.0.19045.1';Expected='Windows10'},
        @{Name='Windows 11 Pro';Version='10.0.22000.1';Expected='Windows11'},
        @{Name='Windows 11 Home';Version='10.0.26100.1';Expected='Windows11'}
    ) {
        $profile = Get-WinUtilISOImageProfile (New-TestImage -Name $Name -Version $Version)
        $profile.WindowsVersion | Should -Be $Expected
        $profile.Architecture | Should -Be 'x64'
    }
    It 'rejects mismatched or unsupported <Name> / <Version> / <Architecture>' -ForEach @(
        @{Name='Windows 10 Pro';Version='10.0.19041.1';Architecture=0},
        @{Name='Windows 11 Pro';Version='10.0.26100.1';Architecture=12},
        @{Name='Windows 11 Pro';Version='10.0.19045.1';Architecture=9},
        @{Name='Windows 10 Pro';Version='10.0.26100.1';Architecture=9},
        @{Name='Windows 10 Pro';Version='10.0.17763.1';Architecture=9},
        @{Name='Windows Server 2025';Version='10.0.26100.1';Architecture=9},
        @{Name='Windows 11 Pro';Version='unknown';Architecture=9},
        @{Name='Windows 11 Pro';Version='10.0.26100.1';Architecture=''}
    ) { { Get-WinUtilISOImageProfile (New-TestImage -Name $Name -Version $Version -Architecture $Architecture) } | Should -Throw }
    It 'rejects a Server installation type even when renamed as a client edition' {
        $image = New-TestImage
        $image.InstallationType='Server'
        { Get-WinUtilISOImageProfile $image } | Should -Throw '*客户端*'
    }
    It 'reads full metadata for each edition instead of trusting the display-name list' {
        Mock Get-WindowsImage {
            if (-not $Index) { return @([pscustomobject]@{ImageIndex=1;ImageName='Windows 10 Home'},[pscustomobject]@{ImageIndex=6;ImageName='Windows 10 Pro'}) }
            New-TestImage -Index $Index
        }
        $profiles = @(Get-WinUtilISOImageProfiles -ImagePath 'fixture.esd')
        $profiles.Count | Should -Be 2
        $profiles[1].ImageIndex | Should -Be 6
        Should -Invoke Get-WindowsImage -Exactly -Times 1 -ParameterFilter { $Index -eq 6 }
    }
    It 'rejects mixed Windows generations before starting modification' {
        Mock Get-WindowsImage {
            if (-not $Index) { return @([pscustomobject]@{ImageIndex=1},[pscustomobject]@{ImageIndex=2}) }
            if ($Index -eq 1) { New-TestImage } else { New-TestImage -Name 'Windows 11 Pro' -Version '10.0.26100.1' -Index 2 }
        }
        { Get-WinUtilISOImageProfiles -ImagePath 'mixed.wim' } | Should -Throw '*混合*'
    }
    It 'allows same-generation x64 drivers and rejects cross-generation injection' {
        $ten = Get-WinUtilISOImageProfile (New-TestImage)
        { Assert-WinUtilISODriverCompatibility -Profile $ten -HostBuild 19045 -HostArchitecture AMD64 } | Should -Not -Throw
        { Assert-WinUtilISODriverCompatibility -Profile $ten -HostBuild 26100 -HostArchitecture AMD64 } | Should -Throw '*关闭*'
        $eleven = Get-WinUtilISOImageProfile (New-TestImage -Name 'Windows 11 Pro' -Version '10.0.26100.1')
        { Assert-WinUtilISODriverCompatibility -Profile $eleven -HostBuild 26100 -HostArchitecture ARM64 } | Should -Throw '*x64*'
    }
}

Describe 'Selected-edition preparation and failure handling' {
    BeforeEach {
        $id = [guid]::NewGuid().ToString('N')
        $script:source = Join-Path $TestDrive "source-$id"
        $script:destination = Join-Path $TestDrive "output-$id"
        New-Item -ItemType Directory -Path $source,$destination -Force | Out-Null
        Mock robocopy { $global:LASTEXITCODE=1 }
        Mock Export-WindowsImage { [IO.File]::WriteAllText($DestinationImagePath,'fixture WIM') }
    }
    It 'exports the selected <Extension> index to an editable single-edition WIM' -ForEach @(@{Extension='wim'},@{Extension='esd'}) {
        $image = Join-Path $source "install.$Extension"
        $result = Initialize-WinUtilISOContents -SourceRoot $source -SourceImage $image -ImageIndex 6 -ContentsDirectory $destination
        $result | Should -Be (Join-Path $destination 'sources\install.wim')
        Test-Path -LiteralPath $result | Should -BeTrue
        Should -Invoke Export-WindowsImage -Exactly -Times 1 -ParameterFilter { $SourceIndex -eq 6 -and $SourceImagePath -eq $image -and $CheckIntegrity }
    }
    It 'stops before image export when copying setup files fails' {
        Mock robocopy { $global:LASTEXITCODE=8 }
        { Initialize-WinUtilISOContents -SourceRoot $source -SourceImage 'fixture.esd' -ImageIndex 1 -ContentsDirectory $destination } | Should -Throw '*退出码 8*'
        Should -Invoke Export-WindowsImage -Times 0
    }
    It 'does not reuse an existing install image' {
        New-Item -ItemType Directory -Path (Join-Path $destination 'sources') | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'sources\install.wim') -Value 'existing'
        { Initialize-WinUtilISOContents -SourceRoot $source -SourceImage 'fixture.esd' -ImageIndex 1 -ContentsDirectory $destination } | Should -Throw '*旧文件*'
        Should -Invoke robocopy -Times 0
    }
    It 'recognizes robocopy success codes without accepting an error code' {
        foreach ($code in 0,1,3,7) { { Assert-WinUtilISONativeExit -Operation copy -ExitCode $code -Robocopy } | Should -Not -Throw }
        { Assert-WinUtilISONativeExit -Operation copy -ExitCode 8 -Robocopy } | Should -Throw
        { Assert-WinUtilISONativeExit -Operation dism -ExitCode 87 } | Should -Throw
        { Assert-WinUtilISONativeExit -Operation dism -ExitCode 3010 } | Should -Not -Throw
    }
}

Describe 'Windows-specific answer files and offline operations' {
    BeforeEach {
        $script:work = Join-Path $TestDrive ('work-' + [guid]::NewGuid().ToString('N'))
        $script:mount = Join-Path $work 'wim_mount'
        $script:contents = Join-Path $work 'iso_contents'
        New-Item -ItemType Directory -Path $mount,$contents -Force | Out-Null
        $script:tenXml = [IO.File]::ReadAllText((Join-Path $root 'tools/autounattend-win10.xml'))
        Mock Assert-WinUtilISOWorkspace { [pscustomobject]@{State='Preparing';WindowsVersion='Windows10'} }
        Mock reg { throw 'Registry must be mocked for the intended scenario' }
        Mock dism { throw 'DISM must be mocked for the intended scenario' }
        Mock Export-WindowsDriver { throw 'Driver export must be mocked for the intended scenario' }
        Mock Mount-WindowsImage { throw 'Mount must be mocked for the intended scenario' }
    }
    It 'stages the real Windows 10 template despite descriptive comments mentioning bypass' {
        Install-WinUtilISOAnswerFile -ScratchDir $mount -ISOContentsDir $contents -Xml $tenXml -WindowsVersion Windows10
        [IO.File]::ReadAllText((Join-Path $contents 'autounattend.xml')) | Should -Be $tenXml
        Test-Path -LiteralPath (Join-Path $mount 'Windows\Setup\Scripts') | Should -BeFalse
    }
    It 'keeps Windows 10 away from Windows 11 AppX, registry and task mutations' {
        $task = Join-Path $mount 'Windows\System32\Tasks\Microsoft\Windows\UpdateOrchestrator'
        New-Item -ItemType Directory -Path $task -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $task 'fixture') -Value 'preserve'
        Invoke-WinUtilISOScript -ScratchDir $mount -ISOContentsDir $contents -WorkDirectory $work -WindowsVersion Windows10 -AutoUnattendXml $tenXml -Log {param($m)}
        Test-Path -LiteralPath (Join-Path $task 'fixture') | Should -BeTrue
        Should -Invoke reg -Times 0
        Should -Invoke dism -Times 0
        Should -Invoke Export-WindowsDriver -Times 0
        Should -Invoke Mount-WindowsImage -Times 0
    }
    It 'rejects the real Windows 11 answer file when making Windows 10' {
        $eleven = [IO.File]::ReadAllText((Join-Path $root 'tools/autounattend.xml'))
        { Install-WinUtilISOAnswerFile -ScratchDir $mount -ISOContentsDir $contents -Xml $eleven -WindowsVersion Windows10 } | Should -Throw '*Windows 11*'
        Test-Path -LiteralPath (Join-Path $contents 'autounattend.xml') | Should -BeFalse
    }
    It 'rejects answer-file paths escaping the offline setup directory before writing any file' {
        $xml='<unattend xmlns="urn:schemas-microsoft-com:unattend"><Extensions xmlns="https://schneegans.de/windows/unattend-generator/"><File path="C:\Windows\Setup\Scripts\..\..\..\outside.ps1">fixture</File></Extensions></unattend>'
        { Install-WinUtilISOAnswerFile -ScratchDir $mount -ISOContentsDir $contents -Xml $xml -WindowsVersion Windows11 } | Should -Throw '*越界*'
        Test-Path -LiteralPath (Join-Path $mount 'outside.ps1') | Should -BeFalse
    }
    It 'does not ignore failed driver exports or continue with an incomplete image' {
        Mock Export-WindowsDriver { throw 'fixture driver failure' }
        { Invoke-WinUtilISOScript -ScratchDir $mount -ISOContentsDir $contents -WorkDirectory $work -WindowsVersion Windows10 -AutoUnattendXml $tenXml -InjectCurrentSystemDrivers $true -Log {param($m)} } | Should -Throw '*fixture driver failure*'
        Should -Invoke reg -Times 0
    }
    It 'unloads only its own offline hives when a Windows 11 registry write fails' {
        $script:registryCalls = [Collections.Generic.List[object]]::new()
        Mock dism { $global:LASTEXITCODE=0 }
        Mock reg {
            $script:registryCalls.Add(@($args))
            $global:LASTEXITCODE = if ($args[0] -eq 'add') { 5 } else { 0 }
        }
        { Invoke-WinUtilISOScript -ScratchDir $mount -ISOContentsDir $contents -WorkDirectory $work -WindowsVersion Windows11 -AutoUnattendXml $tenXml -Log {param($m)} } | Should -Throw '*退出码 5*'
        $loads = @($registryCalls | Where-Object { $_[0] -eq 'load' })
        $unloads = @($registryCalls | Where-Object { $_[0] -eq 'unload' })
        $loads.Count | Should -Be 4
        $unloads.Count | Should -Be 4
        foreach ($call in $unloads) { $call[1] | Should -Match '^HKLM\\WinUtilISO_[a-f0-9]{32}_'; @($loads | Where-Object { $_[1] -eq $call[1] }).Count | Should -Be 1 }
    }
}

Describe 'Workspace ownership and completion gates' {
    BeforeEach {
        $script:workspace = Join-Path $TestDrive ('WinUtil-Tool-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $workspace | Out-Null
        Mock New-WinUtilToolWorkspace { $workspace }
    }
    It 'records a fresh source/profile and refuses exporting a preparing workspace' {
        $path = New-WinUtilISOWorkspace -SourceISO (Join-Path $TestDrive 'source.iso') -Profile (Get-WinUtilISOImageProfile (New-TestImage))
        $marker = Assert-WinUtilISOWorkspace -Path $path -Root $TestDrive
        $marker.State | Should -Be 'Preparing'
        $marker.WindowsVersion | Should -Be 'Windows10'
        { Assert-WinUtilISOWorkspace -Path $path -Root $TestDrive -Completed } | Should -Throw '*尚未成功完成*'
    }
    It 'rejects sibling directories and mismatched ownership records' {
        $path = New-WinUtilISOWorkspace -SourceISO (Join-Path $TestDrive 'source.iso') -Profile (Get-WinUtilISOImageProfile (New-TestImage))
        { Assert-WinUtilISOWorkspace -Path $TestDrive -Root $TestDrive } | Should -Throw
        $marker = Get-Content (Join-Path $path 'winutil-iso.json') -Raw | ConvertFrom-Json
        $marker.Id = 'different-job'
        $marker | ConvertTo-Json | Set-Content (Join-Path $path 'winutil-iso.json')
        { Assert-WinUtilISOWorkspace -Path $path -Root $TestDrive } | Should -Throw '*不匹配*'
    }
}

Describe 'USB target preflight without writing a device' {
    BeforeEach {
        $script:disk = [pscustomobject]@{Number=8;UniqueId='fixture-id';SerialNumber='fixture-serial';Size=16GB;BusType='USB';IsBoot=$false;IsSystem=$false;IsReadOnly=$false}
    }
    It 'accepts an unchanged writable data disk' { { Assert-WinUtilISOUSBTarget -Expected $disk -Current $disk } | Should -Not -Throw }
    It 'rejects a changed <Property> before erasing anything' -ForEach @(
        @{Property='UniqueId';Value='different-device'}, @{Property='SerialNumber';Value='different-serial'},
        @{Property='Size';Value=8GB}, @{Property='BusType';Value='NVMe'},
        @{Property='IsBoot';Value=$true}, @{Property='IsSystem';Value=$true}, @{Property='IsReadOnly';Value=$true}
    ) {
        $changed = $disk.PSObject.Copy()
        $changed.$Property = $Value
        { Assert-WinUtilISOUSBTarget -Expected $disk -Current $changed } | Should -Throw
    }
    It 'rejects insufficient space before formatting' {
        $directory=Join-Path $TestDrive 'iso'
        New-Item -ItemType Directory -Path (Join-Path $directory 'sources') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $directory 'sources\install.wim') -Value fixture
        { Measure-WinUtilISOUSBContents -ContentsDirectory $directory -DiskSize 32MB } | Should -Throw '*尚未擦除*'
    }
}
