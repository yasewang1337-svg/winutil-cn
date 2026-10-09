function Write-Win11ISOLog {
    param([string]$Message)
    $ts = (Get-Date).ToString("HH:mm:ss")
    $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
        $current = $sync["WPFWin11ISOStatusLog"].Text
        if ($current -match '^(Ready\.|请选择|就绪)') {
            $sync["WPFWin11ISOStatusLog"].Text = "[$ts] $Message"
        } else {
            $sync["WPFWin11ISOStatusLog"].Text += "`n[$ts] $Message"
        }
        $sync["WPFWin11ISOStatusLog"].CaretIndex = $sync["WPFWin11ISOStatusLog"].Text.Length
        $sync["WPFWin11ISOStatusLog"].ScrollToEnd()
    })
}

function Invoke-WinUtilISOBrowse {
    if ($sync.ProcessRunning -or $sync['Win11ISOModifying'] -or $sync['Win11ISOExporting'] -or $sync['Win11ISOWritingUSB']) { return }
    if ($sync['Win11ISOCleaning']) { return }
    if ($sync['Win11ISOWorkDir'] -and (Test-Path -LiteralPath $sync['Win11ISOWorkDir'])) {
        [Windows.MessageBox]::Show('请先导出需要保留的成果，再点击“清理并重新开始”，然后选择新的 ISO。', '已有镜像工作目录', 'OK', [Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    Add-Type -AssemblyName System.Windows.Forms

    $dlg = [System.Windows.Forms.OpenFileDialog]::new()
    $dlg.Title            = "选择 Windows 10 / 11 x64 安装 ISO"
    $dlg.Filter           = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
    $dlg.InitialDirectory = [System.Environment]::GetFolderPath("Desktop")

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    if ($sync['Win11ISOOwnsMount'] -and $sync['Win11ISOImagePath']) {
        Dismount-DiskImage -ImagePath $sync['Win11ISOImagePath'] -ErrorAction Stop
    }
    foreach ($key in @('Win11ISOImagePath','Win11ISODriveLetter','Win11ISOWimPath','Win11ISOImageInfo','Win11ISOProfile','Win11ISOContentsDir')) { $sync[$key] = $null }
    $sync['Win11ISOOwnsMount'] = $false

    $isoPath    = $dlg.FileName
    $fileSizeGB = [math]::Round((Get-Item -LiteralPath $isoPath -ErrorAction Stop).Length / 1GB, 2)

    $sync["WPFWin11ISOPath"].Text           = $isoPath
    $sync["WPFWin11ISOFileInfo"].Text       = "File size: $fileSizeGB GB"
    $sync["WPFWin11ISOFileInfo"].Visibility = "Visible"
    $sync["WPFWin11ISOMountSection"].Visibility       = "Visible"
    $sync["WPFWin11ISOVerifyResultPanel"].Visibility  = "Collapsed"
    $sync["WPFWin11ISOModifySection"].Visibility      = "Collapsed"
    $sync["WPFWin11ISOOutputSection"].Visibility      = "Collapsed"

    Write-Win11ISOLog "ISO selected: $isoPath  ($fileSizeGB GB)"
}

function Invoke-WinUtilISOMountAndVerify {
    if ($sync.ProcessRunning -or $sync['Win11ISOModifying'] -or $sync['Win11ISOExporting'] -or $sync['Win11ISOWritingUSB']) { return }
    if ($sync['Win11ISOCleaning']) { return }
    $isoPath = $sync['WPFWin11ISOPath'].Text
    if ([string]::IsNullOrWhiteSpace($isoPath) -or -not (Test-Path -LiteralPath $isoPath -PathType Leaf)) {
        [Windows.MessageBox]::Show('请先选择一个存在的 ISO 文件。', '未选择 ISO', 'OK', [Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    foreach ($key in @('Win11ISOImageInfo','Win11ISOProfile','Win11ISOWimPath','Win11ISODriveLetter')) { $sync[$key] = $null }
    $sync['WPFWin11ISOVerifyResultPanel'].Visibility = 'Collapsed'
    $sync['WPFWin11ISOModifySection'].Visibility = 'Collapsed'
    $mountedHere = $false
    try {
        $ErrorActionPreference = 'Stop'
        $existing = Get-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
        if (-not $existing.Attached) {
            Write-Win11ISOLog "正在挂载 ISO：$isoPath"
            Mount-DiskImage -ImagePath $isoPath -ErrorAction Stop | Out-Null
            $mountedHere = $true
        }
        $drive = $null
        for ($attempt=0; $attempt -lt 40; $attempt++) {
            $drive = Get-DiskImage -ImagePath $isoPath -ErrorAction Stop | Get-Volume -ErrorAction Stop | Where-Object DriveLetter | Select-Object -First 1
            if ($drive) { break }
            Start-Sleep -Milliseconds 250
        }
        if (-not $drive) { throw 'ISO 已挂载，但在 10 秒内未取得可读盘符。' }
        $driveLetter = [string]$drive.DriveLetter + ':\'
        $wimPath = Join-Path $driveLetter 'sources\install.wim'
        $esdPath = Join-Path $driveLetter 'sources\install.esd'
        $activeWim = if (Test-Path -LiteralPath $wimPath) { $wimPath } elseif (Test-Path -LiteralPath $esdPath) { $esdPath } else { throw '未找到 sources\install.wim 或 install.esd。' }
        foreach ($required in @('sources\boot.wim','boot\etfsboot.com','efi\microsoft\boot\efisys.bin','efi\boot\bootx64.efi')) {
            if (-not (Test-Path -LiteralPath (Join-Path $driveLetter $required) -PathType Leaf)) { throw "镜像缺少 x64 安装启动文件：$required" }
        }
        Set-WinUtilProgressBar -Label '读取系统版本与架构…' -Percent 55
        $imageInfo = @(Get-WinUtilISOImageProfiles -ImagePath $activeWim)
        $profile = $imageInfo[0]
        $sync['Win11ISOImageInfo'] = $imageInfo
        $sync['Win11ISOProfile'] = $profile
        $sync['Win11ISOOwnsMount'] = $mountedHere -or ($sync['Win11ISOOwnsMount'] -and $sync['Win11ISOImagePath'] -eq $isoPath)
        $sync['Win11ISODriveLetter'] = $driveLetter
        $sync['Win11ISOWimPath'] = $activeWim
        $sync['Win11ISOImagePath'] = $isoPath
        $sync['WPFWin11ISOMountDriveLetter'].Text = "挂载位置：$driveLetter  |  安装文件：$(Split-Path $activeWim -Leaf)"
        if ($sync['WPFWin11ISOArchLabel']) { $sync['WPFWin11ISOArchLabel'].Text = "$($profile.DisplayName) · x64 · $($profile.Version)" }
        if ($sync['WPFWindowsISOProfileSummary']) {
            $sync['WPFWindowsISOProfileSummary'].Text = if ($profile.WindowsVersion -eq 'Windows10') {
                'Windows 10：保留预装应用和默认系统设置；导出所选版本并加入独立安装应答。不会套用 Windows 11 的硬件检查、任务栏或 ViVeTool 设置。'
            } else { 'Windows 11：导出所选版本，应用现有 WinUtil 定制和安装应答（含预装应用精简、隐私与 OOBE 设置）。' }
        }
        $combo = $sync['WPFWin11ISOEditionComboBox']
        $combo.Items.Clear()
        foreach ($entry in $imageInfo) { $null = $combo.Items.Add("$($entry.ImageIndex): $($entry.ImageName)") }
        $preferred = @($imageInfo | Where-Object { $_.ImageName -match '^Windows (10|11) Pro$' } | Select-Object -First 1)
        $combo.SelectedIndex = if ($preferred.Count) { [array]::IndexOf($imageInfo, $preferred[0]) } else { 0 }
        $sync['WPFWin11ISOVerifyResultPanel'].Visibility = 'Visible'
        $sync['WPFWin11ISOModifySection'].Visibility = 'Visible'
        Write-Win11ISOLog "已识别 $($profile.DisplayName) x64，$($imageInfo.Count) 个可选版本。请确认文件来自微软官方。"
    } catch {
        if ($mountedHere) { try { Dismount-DiskImage -ImagePath $isoPath -ErrorAction Stop } catch {} }
        Write-Win11ISOLog "挂载或校验失败：$_"
        [Windows.MessageBox]::Show("挂载或校验 ISO 失败：`n`n$_", '镜像校验失败', 'OK', [Windows.MessageBoxImage]::Error) | Out-Null
    } finally { Set-WinUtilProgressBar -Label '' -Percent 0 }
}
function Invoke-WinUtilISOModify {
    if ($sync.ProcessRunning -or $sync['Win11ISOModifying'] -or $sync['Win11ISOExporting'] -or $sync['Win11ISOWritingUSB']) { return }
    if ($sync['Win11ISOCleaning']) { return }
    if ($sync['Win11ISOWorkDir'] -and (Test-Path -LiteralPath $sync['Win11ISOWorkDir'])) {
        [Windows.MessageBox]::Show('本次工作目录仍存在。请先点击“清理并重新开始”，避免重复创建大体积工作目录。', '请先清理', 'OK', [Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    $isoPath     = $sync["Win11ISOImagePath"]
    $driveLetter = $sync["Win11ISODriveLetter"]
    $wimPath     = $sync["Win11ISOWimPath"]

    if (-not $isoPath) {
        [System.Windows.MessageBox]::Show(
            "未找到已校验的 ISO。请先完成步骤 1 和 2。",
            "尚未就绪", "OK", [Windows.MessageBoxImage]::Warning)
        return
    }

    $selectedItem     = $sync["WPFWin11ISOEditionComboBox"].SelectedItem
    $selectedWimIndex = 1
    if ($selectedItem -and $selectedItem -match '^(\d+):') {
        $selectedWimIndex = [int]$Matches[1]
    } elseif ($sync["Win11ISOImageInfo"]) {
        $selectedWimIndex = $sync["Win11ISOImageInfo"][0].ImageIndex
    }
    $selectedEditionName = if ($selectedItem) { ($selectedItem -replace '^\d+:\s*', '') } else { "Unknown" }
    Write-Win11ISOLog "Selected edition: $selectedEditionName (Index $selectedWimIndex)"
    try {
        $profile = Get-WinUtilISOImageProfile -Image (Get-WindowsImage -ImagePath $wimPath -Index $selectedWimIndex -ErrorAction Stop)
        $selectedEditionName = $profile.ImageName
        if ($profile.WindowsVersion -ne $sync['Win11ISOProfile'].WindowsVersion) { throw '选择的版本与已校验镜像不一致，请重新校验。' }
        $injectDrivers = $sync['WPFWin11ISOInjectDrivers'].IsChecked -eq $true
        if ($injectDrivers) {
            $hostBuild = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).BuildNumber
            Assert-WinUtilISODriverCompatibility -Profile $profile -HostBuild $hostBuild
        }
        $isWindows10 = $profile.WindowsVersion -eq 'Windows10'
        $autounattendContent = if ($isWindows10) { $WinUtilWindows10AutounattendXml } else { $WinUtilAutounattendXml }
        if ([string]::IsNullOrWhiteSpace($autounattendContent)) {
            $templateName = if ($isWindows10) { 'autounattend-win10.xml' } else { 'autounattend.xml' }
            $toolsXml = Join-Path $PSScriptRoot "..\..\tools\$templateName"
            $autounattendContent = Get-Content -LiteralPath $toolsXml -Raw -Encoding UTF8 -ErrorAction Stop
        }
        if ([string]::IsNullOrWhiteSpace($autounattendContent)) { throw '未找到对应系统的安装应答文件。' }
        $workDir = New-WinUtilISOWorkspace -SourceISO $isoPath -Profile $profile
        $sync['Win11ISOWorkDir'] = $workDir
        $sync['Win11ISOProfile'] = $profile
        $sync['Win11ISOContentsDir'] = $null
    } catch {
        Write-Win11ISOLog "制作前检查失败：$_"
        [Windows.MessageBox]::Show("无法开始制作：`n`n$_", '制作前检查失败', 'OK', [Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    $sync["WPFWin11ISOModifyButton"].IsEnabled = $false
    $sync["Win11ISOModifying"] = $true
    $sync.ProcessRunning = $true

    $runspace = $null
    $script = $null
    try {
        $runspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions  = "ReuseThread"
        $runspace.Open()
        $injectDrivers = $sync["WPFWin11ISOInjectDrivers"].IsChecked -eq $true

        $runspace.SessionStateProxy.SetVariable("sync",                $sync)
        $runspace.SessionStateProxy.SetVariable("isoPath",             $isoPath)
        $runspace.SessionStateProxy.SetVariable("driveLetter",         $driveLetter)
        $runspace.SessionStateProxy.SetVariable("wimPath",             $wimPath)
        $runspace.SessionStateProxy.SetVariable("workDir",             $workDir)
        $runspace.SessionStateProxy.SetVariable("selectedWimIndex",    $selectedWimIndex)
        $runspace.SessionStateProxy.SetVariable("selectedEditionName", $selectedEditionName)
        $runspace.SessionStateProxy.SetVariable("autounattendContent", $autounattendContent)
        $runspace.SessionStateProxy.SetVariable("injectDrivers",       $injectDrivers)
        $runspace.SessionStateProxy.SetVariable('profile', $profile)
        $runspace.SessionStateProxy.SetVariable('ownsSourceMount', [bool]$sync['Win11ISOOwnsMount'])
        $isoHelpers = foreach ($name in @('Assert-WinUtilISONativeExit','Assert-WinUtilISOWorkspace','Set-WinUtilISOWorkspaceState','Install-WinUtilISOAnswerFile','Initialize-WinUtilISOContents')) {
            "function $name {`n$((Get-Command $name -CommandType Function).Definition)`n}"
        }
        $runspace.SessionStateProxy.SetVariable('isoHelpers', ($isoHelpers -join "`n"))

        $isoScriptFuncDef   = "function Invoke-WinUtilISOScript {`n" + ${function:Invoke-WinUtilISOScript}.ToString() + "`n}"
        $win11ISOLogFuncDef = "function Write-Win11ISOLog {`n"       + ${function:Write-Win11ISOLog}.ToString()       + "`n}"
        $runspace.SessionStateProxy.SetVariable("isoScriptFuncDef",   $isoScriptFuncDef)
        $runspace.SessionStateProxy.SetVariable("win11ISOLogFuncDef", $win11ISOLogFuncDef)

        $script = [Management.Automation.PowerShell]::Create()
        $script.Runspace = $runspace
        $script.AddScript({
            . ([scriptblock]::Create($isoScriptFuncDef))
            . ([scriptblock]::Create($win11ISOLogFuncDef))
            . ([scriptblock]::Create($isoHelpers))
            $ErrorActionPreference = 'Stop'

            function Log($msg) {
                $ts = (Get-Date).ToString("HH:mm:ss")
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync["WPFWin11ISOStatusLog"].Text += "`n[$ts] $msg"
                    $sync["WPFWin11ISOStatusLog"].CaretIndex = $sync["WPFWin11ISOStatusLog"].Text.Length
                    $sync["WPFWin11ISOStatusLog"].ScrollToEnd()
                })
                if ($workDir -and (Test-Path -LiteralPath $workDir)) { Add-Content -LiteralPath (Join-Path $workDir "WinUtil_ISO.log") -Value "[$ts] $msg" -Encoding UTF8 }
            }

            function SetProgress($label, $pct) {
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync.progressBarTextBlock.Text    = $label
                    $sync.progressBarTextBlock.ToolTip = $label
                    $sync.ProgressBar.Value            = [Math]::Max($pct, 5)
                })
            }

            function Get-DismImageInfoMap {
                param(
                    [Parameter(Mandatory)][string]$ImagePath,
                    [int]$Index = 1
                )

                $map = @{}
                $lines = & dism /English "/Get-ImageInfo" "/ImageFile:$ImagePath" "/Index:$Index"
                foreach ($line in $lines) {
                    if ($line -match '^\s*([^:]+?)\s*:\s*(.*)$') {
                        $key = $Matches[1].Trim()
                        $val = $Matches[2].Trim()
                        if (-not $map.ContainsKey($key)) {
                            $map[$key] = $val
                        }
                    }
                }
                return $map
            }

            function Invoke-WinUtilWimMetadataHydration {
                param(
                    [Parameter(Mandatory)][string]$ImagePath,
                    [Parameter(Mandatory)][string]$EditionName,
                    [scriptblock]$Logger
                )

                function LogMeta([string]$Message) {
                    if ($Logger) {
                        $null = $Logger.Invoke($Message)
                    }
                }

                $before = Get-DismImageInfoMap -ImagePath $ImagePath -Index 1
                $undefinedBefore = @($before.GetEnumerator() | Where-Object { $_.Value -eq '<undefined>' } | ForEach-Object { $_.Key })

                if ($undefinedBefore.Count -eq 0) {
                    LogMeta "Metadata check: no undefined DISM fields detected."
                    return
                }

                LogMeta "Metadata check: undefined DISM fields detected: $($undefinedBefore -join ', ')"
                LogMeta "Attempting best-effort metadata hydration for install.wim..."

                $setImage = Get-Command Set-WindowsImage -ErrorAction SilentlyContinue
                if (-not $setImage) {
                    LogMeta "Set-WindowsImage is unavailable on this host; cannot write additional WIM metadata fields."
                    return
                }

                $targetName = if ($EditionName -and $EditionName -ne 'Unknown') { $EditionName } else { $before['Name'] }
                if (-not $targetName) { $targetName = 'Windows 11' }

                $targetDescription = if ($before['Description'] -and $before['Description'] -ne '<undefined>') {
                    $before['Description']
                } else {
                    $targetName
                }

                $setArgs = @{
                    ImagePath   = $ImagePath
                    Index       = 1
                    Name        = $targetName
                    Description = $targetDescription
                    ErrorAction = 'Stop'
                }

                try {
                    Set-WindowsImage @setArgs | Out-Null
                    LogMeta "Applied Set-WindowsImage metadata updates (Name/Description)."
                } catch {
                    LogMeta "Warning: Set-WindowsImage metadata update failed: $_"
                }

                $after = Get-DismImageInfoMap -ImagePath $ImagePath -Index 1
                $undefinedAfter = @($after.GetEnumerator() | Where-Object { $_.Value -eq '<undefined>' } | ForEach-Object { $_.Key })
                if ($undefinedAfter.Count -eq 0) {
                    LogMeta "Metadata hydration complete: no undefined DISM fields remain."
                } else {
                    LogMeta "Metadata hydration complete. Remaining undefined DISM fields: $($undefinedAfter -join ', ')"
                    LogMeta "Note: some DISM metadata fields are read-only and come from Microsoft image internals."
                }
            }

            try {
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync["WPFWin11ISOSelectSection"].Visibility = "Collapsed"
                    $sync["WPFWin11ISOMountSection"].Visibility  = "Collapsed"
                    $sync["WPFWin11ISOModifySection"].Visibility = "Collapsed"
                })

                Log "Creating working directory: $workDir"
                $isoContents = Join-Path $workDir "iso_contents"
                $mountDir    = Join-Path $workDir "wim_mount"
                New-Item -ItemType Directory -Path $isoContents, $mountDir -Force
                SetProgress "Copying ISO contents..." 10

                Log "复制安装文件并导出所选版本：$selectedEditionName..."
                $localWim = Initialize-WinUtilISOContents -SourceRoot $driveLetter -SourceImage $wimPath -ImageIndex $selectedWimIndex -ContentsDirectory $isoContents
                Log '所选 WIM / ESD 版本已导出为单版本 install.wim（索引 1）。'
                SetProgress "Mounting install.wim..." 25
                Log "Mounting install.wim (Index 1: $selectedEditionName) at $mountDir..."
                Mount-WindowsImage -ImagePath $localWim -Index 1 -Path $mountDir -CheckIntegrity -ErrorAction Stop
                SetProgress "Modifying install.wim..." 45

                Log "Applying WinUtil modifications to install.wim..."
                Invoke-WinUtilISOScript -ScratchDir $mountDir -ISOContentsDir $isoContents -AutoUnattendXml $autounattendContent -WindowsVersion $profile.WindowsVersion -WorkDirectory $workDir -InjectCurrentSystemDrivers $injectDrivers -Log { param($m) Log $m }

                if ($profile.WindowsVersion -eq 'Windows11') {
                    SetProgress "Cleaning up component store (WinSxS)..." 56
                    Log "Running DISM component store cleanup (/ResetBase)..."
                    & dism /English "/image:$mountDir" /Cleanup-Image /StartComponentCleanup /ResetBase | ForEach-Object { Log $_ }
                    Assert-WinUtilISONativeExit -Operation '清理镜像组件存储' -ExitCode $LASTEXITCODE
                    Log "Component store cleanup complete."
                }

                SetProgress "Saving modified install.wim..." 65
                Log "Dismounting and saving install.wim. This will take several minutes..."
                Dismount-WindowsImage -Path $mountDir -Save -CheckIntegrity -ErrorAction Stop
                Log "install.wim saved."

                SetProgress "Hydrating WIM metadata..." 76
                Invoke-WinUtilWimMetadataHydration -ImagePath $localWim -EditionName $selectedEditionName -Logger ${function:Log}

                SetProgress "Dismounting source ISO..." 80
                Log "Dismounting original ISO..."
                if ($ownsSourceMount) { Dismount-DiskImage -ImagePath $isoPath -ErrorAction Stop }

                Set-WinUtilISOWorkspaceState -Path $workDir -State Completed

                $sync["Win11ISOWorkDir"]     = $workDir
                $sync["Win11ISOContentsDir"] = $isoContents

                SetProgress "Modification complete" 100
                Log "install.wim modification complete. Choose an output option in Step 4."

                $sync["WPFWin11ISOOutputSection"].Dispatcher.Invoke([action]{
                    $sync["WPFWin11ISOOutputSection"].Visibility = "Visible"
                })
            } catch {
                Log "ERROR during modification: $_"

                try {
                    if (Test-Path $mountDir) {
                        $mountedImages = Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $mountDir }
                        if ($mountedImages) {
                            Log "Cleaning up: dismounting install.wim (discarding changes)..."
                            Dismount-WindowsImage -Path $mountDir -Discard
                        }
                    }
                } catch { Log "Warning: could not dismount install.wim during cleanup: $_" }

                try {
                    $mountedISO = Get-DiskImage -ImagePath $isoPath
                    if ($ownsSourceMount -and $mountedISO -and $mountedISO.Attached) {
                        Log "Cleaning up: dismounting source ISO..."
                        Dismount-DiskImage -ImagePath $isoPath
                    }
                } catch { Log "Warning: could not dismount ISO during cleanup: $_" }

                try {
                    Set-WinUtilISOWorkspaceState -Path $workDir -State Failed
                    Log "制作失败，已保留本次工作目录和日志供检查：$workDir。请使用清理并重新开始移除。"
                } catch { Log "Warning: could not update workspace status: $_" }

                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    [System.Windows.MessageBox]::Show(
                        "修改 install.wim 时发生错误:`n`n$_",
                        "修改错误", "OK", [Windows.MessageBoxImage]::Error)
                })
            } finally {
                try {
                    $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                        $sync.progressBarTextBlock.Text    = ""
                        $sync.progressBarTextBlock.ToolTip = ""
                        $sync.ProgressBar.Value            = 0
                        $sync["WPFWin11ISOModifyButton"].IsEnabled = $true
                        if ($sync["WPFWin11ISOOutputSection"].Visibility -ne "Visible") {
                            $sync["WPFWin11ISOSelectSection"].Visibility = "Visible"
                            $sync["WPFWin11ISOMountSection"].Visibility  = "Visible"
                            $sync["WPFWin11ISOModifySection"].Visibility = "Visible"
                        }
                    })
                } finally {
                    $sync['Win11ISOModifying'] = $false
                    $sync.ProcessRunning = $false
                }
            }
        })

        $null = $script.BeginInvoke()
    } catch {
        $startupError = $_
        $sync['Win11ISOModifying'] = $false
        $sync.ProcessRunning = $false
        $sync['WPFWin11ISOModifyButton'].IsEnabled = $true
        if ($script) { try { $script.Dispose() } catch {} }
        if ($runspace) { try { $runspace.Dispose() } catch {} }
        try { Set-WinUtilISOWorkspaceState -Path $workDir -State Failed } catch {}
        Write-Win11ISOLog "无法启动镜像任务：$startupError"
        [Windows.MessageBox]::Show("无法启动镜像任务：`n`n$startupError", '任务未启动', 'OK', [Windows.MessageBoxImage]::Error) | Out-Null
    }
}

function Invoke-WinUtilISOCheckExistingWork {
    # Only this session's verified completed job may expose output actions.
    # Never infer ownership/completion from a similarly named temporary folder.
    if (-not $sync['Win11ISOWorkDir'] -or -not $sync['Win11ISOContentsDir'] -or $sync['Win11ISOModifying']) { return }
    try {
        $null = Assert-WinUtilISOWorkspace -Path $sync['Win11ISOWorkDir'] -Completed
        if (Test-Path -LiteralPath (Join-Path $sync['Win11ISOContentsDir'] 'sources\install.wim')) {
            $sync['WPFWin11ISOOutputSection'].Visibility = 'Visible'
        }
    } catch { Write-Win11ISOLog "本次镜像工作内容尚不能导出：$_" }
}
function Invoke-WinUtilISOCleanAndReset {
    if ($sync.ProcessRunning -or $sync['Win11ISOModifying'] -or $sync['Win11ISOExporting'] -or $sync['Win11ISOWritingUSB'] -or $sync['Win11ISOCleaning']) { return }
    $workDir = $sync["Win11ISOWorkDir"]

    if ($workDir -and (Test-Path $workDir)) {
        $confirm = [System.Windows.MessageBox]::Show(
            "这将删除临时工作目录:`n`n$workDir`n`n并将界面重置回起始状态。`n`n是否继续?",
            "清理并重新开始", "YesNo", [Windows.MessageBoxImage]::Warning)
        if ($confirm -ne "Yes") { return }
    }

    $sync["WPFWin11ISOCleanResetButton"].IsEnabled = $false
    $sync['Win11ISOCleaning'] = $true
    $sync.ProcessRunning = $true

    $runspace = $null
    $script = $null
    try {
        $runspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions  = "ReuseThread"
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable("sync",    $sync)
        $runspace.SessionStateProxy.SetVariable("workDir", $workDir)
        $runspace.SessionStateProxy.SetVariable('sourceISO', $sync['Win11ISOImagePath'])
        $runspace.SessionStateProxy.SetVariable('ownsSourceMount', [bool]$sync['Win11ISOOwnsMount'])
        $cleanupHelpers = foreach ($name in @('Assert-WinUtilISOWorkspace','Remove-WinUtilISOWorkspace')) { "function $name {`n$((Get-Command $name -CommandType Function).Definition)`n}" }
        $runspace.SessionStateProxy.SetVariable('cleanupHelpers', ($cleanupHelpers -join "`n"))

        $script = [Management.Automation.PowerShell]::Create()
        $script.Runspace = $runspace
        $script.AddScript({
            . ([scriptblock]::Create($cleanupHelpers))
            $ErrorActionPreference = 'Stop'
            function Log($msg) {
                $ts = (Get-Date).ToString("HH:mm:ss")
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync["WPFWin11ISOStatusLog"].Text += "`n[$ts] $msg"
                    $sync["WPFWin11ISOStatusLog"].CaretIndex = $sync["WPFWin11ISOStatusLog"].Text.Length
                    $sync["WPFWin11ISOStatusLog"].ScrollToEnd()
                })
                if ($workDir -and (Test-Path -LiteralPath $workDir)) { Add-Content -LiteralPath (Join-Path $workDir "WinUtil_ISO.log") -Value "[$ts] $msg" -Encoding UTF8 }
            }

            function SetProgress($label, $pct) {
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync.progressBarTextBlock.Text    = $label
                    $sync.progressBarTextBlock.ToolTip = $label
                    $sync.ProgressBar.Value            = [Math]::Max($pct, 5)
                })
            }

            try {
                if ($workDir -and (Test-Path -LiteralPath $workDir)) {
                    Log "正在清理本次镜像工作目录：$workDir"
                    SetProgress '卸载本次镜像并清理文件…' 10
                    Remove-WinUtilISOWorkspace -Path $workDir
                }
                if ($ownsSourceMount -and $sourceISO) {
                    $diskImage = Get-DiskImage -ImagePath $sourceISO -ErrorAction Stop
                    if ($diskImage.Attached) { Dismount-DiskImage -ImagePath $sourceISO -ErrorAction Stop }
                }
                SetProgress "Resetting UI..." 95
                Log "Resetting interface..."

                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync["Win11ISOWorkDir"]     = $null
                    $sync["Win11ISOContentsDir"] = $null
                    $sync["Win11ISOImagePath"]   = $null
                    $sync["Win11ISODriveLetter"] = $null
                    $sync["Win11ISOWimPath"]     = $null
                    $sync["Win11ISOImageInfo"]   = $null
                    $sync["Win11ISOUSBDisks"]    = $null
                    $sync['Win11ISOProfile'] = $null
                    $sync['Win11ISOOwnsMount'] = $false

                    $sync["WPFWin11ISOPath"].Text                   = "No ISO selected..."
                    $sync["WPFWin11ISOFileInfo"].Visibility          = "Collapsed"
                    $sync["WPFWin11ISOVerifyResultPanel"].Visibility = "Collapsed"
                    $sync["WPFWin11ISOOptionUSB"].Visibility         = "Collapsed"
                    $sync["WPFWin11ISOOutputSection"].Visibility     = "Collapsed"
                    $sync["WPFWin11ISOModifySection"].Visibility     = "Collapsed"
                    $sync["WPFWin11ISOMountSection"].Visibility      = "Collapsed"
                    $sync["WPFWin11ISOSelectSection"].Visibility     = "Visible"
                    $sync["WPFWin11ISOModifyButton"].IsEnabled       = $true
                    $sync["WPFWin11ISOCleanResetButton"].IsEnabled   = $true

                    $sync.progressBarTextBlock.Text    = ""
                    $sync.progressBarTextBlock.ToolTip = ""
                    $sync.ProgressBar.Value            = 0

                    $sync["WPFWin11ISOStatusLog"].Text   = "请选择 Windows 10 / 11 x64 安装 ISO。"
                })
            } catch {
                Log "ERROR during Clean & Reset: $_"
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync.progressBarTextBlock.Text    = ""
                    $sync.progressBarTextBlock.ToolTip = ""
                    $sync.ProgressBar.Value            = 0
                    $sync["WPFWin11ISOCleanResetButton"].IsEnabled = $true
                })
            } finally {
                try {

                } finally {
                    $sync['Win11ISOCleaning'] = $false
                    $sync.ProcessRunning = $false
                }
            }
        })

        $null = $script.BeginInvoke()
    } catch {
        $startupError = $_
        $sync['Win11ISOCleaning'] = $false
        $sync.ProcessRunning = $false
        $sync['WPFWin11ISOCleanResetButton'].IsEnabled = $true
        if ($script) { try { $script.Dispose() } catch {} }
        if ($runspace) { try { $runspace.Dispose() } catch {} }

        Write-Win11ISOLog "无法启动镜像任务：$startupError"
        [Windows.MessageBox]::Show("无法启动镜像任务：`n`n$startupError", '任务未启动', 'OK', [Windows.MessageBoxImage]::Error) | Out-Null
    }
}

function Invoke-WinUtilISOExport {
    if ($sync.ProcessRunning -or $sync['Win11ISOModifying'] -or $sync['Win11ISOExporting'] -or $sync['Win11ISOWritingUSB'] -or $sync['Win11ISOCleaning']) { return }
    $contentsDir = $sync["Win11ISOContentsDir"]
    try {
        $manifest = Assert-WinUtilISOWorkspace -Path $sync['Win11ISOWorkDir'] -Completed
        if ([IO.Path]::GetFullPath($contentsDir).TrimEnd('\') -ne (Join-Path $sync['Win11ISOWorkDir'] 'iso_contents')) { throw '输出目录与本次工作记录不一致。' }
    } catch {
        [Windows.MessageBox]::Show("当前内容不能导出：`n$_", '尚未完成制作', 'OK', [Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    if (-not $contentsDir -or -not (Test-Path $contentsDir)) {
        [System.Windows.MessageBox]::Show(
            "未找到修改后的 ISO 内容。请先完成步骤 1-3。",
            "尚未就绪", "OK", [Windows.MessageBoxImage]::Warning)
        return
    }

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = [System.Windows.Forms.SaveFileDialog]::new()
    $dlg.Title            = '保存 Windows 安装 ISO'
    $dlg.Filter           = "ISO files (*.iso)|*.iso"
    $prefix = if ($manifest.WindowsVersion -eq 'Windows10') { 'Win10' } else { 'Win11' }
    $dlg.FileName         = "${prefix}_Modified_$(Get-Date -Format 'yyyyMMdd').iso"
    $dlg.InitialDirectory = [System.Environment]::GetFolderPath("Desktop")

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $outputISO = $dlg.FileName
    if ([IO.Path]::GetFullPath($outputISO) -eq $manifest.SourceISO -or [IO.Path]::GetFullPath($outputISO).StartsWith([IO.Path]::GetFullPath($sync['Win11ISOWorkDir']).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {
        [Windows.MessageBox]::Show('请另选输出位置，不能覆盖原始 ISO 或写入本次临时工作目录。', '输出位置无效', 'OK', [Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    # Locate oscdimg.exe (Windows ADK or winget per-user install)
    $oscdimg = Get-ChildItem "C:\Program Files (x86)\Windows Kits" -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
               Select-Object -First 1 -ExpandProperty FullName
    if (-not $oscdimg) {
        $oscdimg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
                   Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $oscdimg) {
        $install = [Windows.MessageBox]::Show('导出 ISO 需要微软 oscdimg 工具。是否通过 WinGet 安装 Microsoft.OSCDIMG？这会在本机安装该工具。', '安装 ISO 制作工具', 'YesNo', [Windows.MessageBoxImage]::Question)
        if ($install -ne 'Yes') { return }
        Write-Win11ISOLog "oscdimg.exe not found. Attempting to install via winget..."
        try {
            # First ensure winget is installed and operational
            Install-WinUtilWinget

            $winget = Get-Command winget
            $result = & $winget install -e --id Microsoft.OSCDIMG --accept-package-agreements --accept-source-agreements
            Assert-WinUtilISONativeExit -Operation '安装 oscdimg' -ExitCode $LASTEXITCODE
            Write-Win11ISOLog "winget output: $result"
            $oscdimg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
                       Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
                       Select-Object -First 1 -ExpandProperty FullName
        } catch {
            Write-Win11ISOLog "winget not available or install failed: $_"
        }

        if (-not $oscdimg) {
            Write-Win11ISOLog "oscdimg.exe still not found after install attempt."
            [System.Windows.MessageBox]::Show(
                "无法自动找到或安装 oscdimg.exe。`n`n请手动安装:`n  winget install -e --id Microsoft.OSCDIMG`n`n或从以下地址安装 Windows ADK:`nhttps://learn.microsoft.com/windows-hardware/get-started/adk-install",
                "未找到 oscdimg", "OK", [Windows.MessageBoxImage]::Warning)
            return
        }
        Write-Win11ISOLog "oscdimg.exe installed successfully."
    }

    $sync["WPFWin11ISOChooseISOButton"].IsEnabled = $false
    $sync['Win11ISOExporting'] = $true
    $sync.ProcessRunning = $true

    $runspace = $null
    $script = $null
    try {
        $runspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions  = "ReuseThread"
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable("sync",        $sync)
        $runspace.SessionStateProxy.SetVariable("contentsDir", $contentsDir)
        $runspace.SessionStateProxy.SetVariable("outputISO",   $outputISO)
        $runspace.SessionStateProxy.SetVariable("oscdimg",     $oscdimg)
        $runspace.SessionStateProxy.SetVariable('workspace', $sync['Win11ISOWorkDir'])
        $runspace.SessionStateProxy.SetVariable('checkWorkspace', "function Assert-WinUtilISOWorkspace {`n$((Get-Command Assert-WinUtilISOWorkspace).Definition)`n}")

        $win11ISOLogFuncDef = "function Write-Win11ISOLog {`n" + ${function:Write-Win11ISOLog}.ToString() + "`n}"
        $runspace.SessionStateProxy.SetVariable("win11ISOLogFuncDef", $win11ISOLogFuncDef)

        $script = [Management.Automation.PowerShell]::Create()
        $script.Runspace = $runspace
        $script.AddScript({
            . ([scriptblock]::Create($win11ISOLogFuncDef))
            . ([scriptblock]::Create($checkWorkspace))

            function SetProgress($label, $pct) {
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    $sync.progressBarTextBlock.Text    = $label
                    $sync.progressBarTextBlock.ToolTip = $label
                    $sync.ProgressBar.Value            = [Math]::Max($pct, 5)
                })
            }

            try {
                $null = Assert-WinUtilISOWorkspace -Path $workspace -Completed
                Write-Win11ISOLog "Exporting to ISO: $outputISO"
                SetProgress "Building ISO..." 10

                $bootData    = "2#p0,e,b`"$contentsDir\boot\etfsboot.com`"#pEF,e,b`"$contentsDir\efi\microsoft\boot\efisys.bin`""
                $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", "-bootdata:$bootData", "-l`"CTOS_MODIFIED`"", "`"$contentsDir`"", "`"$outputISO`"")

                Write-Win11ISOLog "Running oscdimg..."

                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName               = $oscdimg
                $psi.Arguments              = $oscdimgArgs -join " "
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError  = $true
                $psi.UseShellExecute        = $false
                $psi.CreateNoWindow         = $true

                $proc = [System.Diagnostics.Process]::new()
                $proc.StartInfo = $psi
                $proc.Start()
                $stderrTask = $proc.StandardError.ReadToEndAsync()

                # Stream stdout line-by-line as oscdimg runs
                while (-not $proc.StandardOutput.EndOfStream) {
                    $line = $proc.StandardOutput.ReadLine()
                    if ($line.Trim()) { Write-Win11ISOLog $line }
                }

                $proc.WaitForExit()

                # Flush any stderr after process exits
                $stderr = $stderrTask.GetAwaiter().GetResult()
                foreach ($line in ($stderr -split "`r?`n")) {
                    if ($line.Trim()) { Write-Win11ISOLog "[stderr]$line" }
                }

                if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $outputISO -PathType Leaf) -and (Get-Item -LiteralPath $outputISO).Length -gt 0) {
                    SetProgress "ISO exported" 100
                    Write-Win11ISOLog "ISO exported successfully: $outputISO"
                    $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                        [System.Windows.MessageBox]::Show("ISO 导出成功!`n`n$outputISO", "导出完成", "OK", [Windows.MessageBoxImage]::Information)
                    })
                } else {
                    Write-Win11ISOLog "oscdimg exited with code $($proc.ExitCode)."
                    $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                        [System.Windows.MessageBox]::Show(
                            "oscdimg 退出,代码为 $($proc.ExitCode)。`n请查看状态日志了解详情。",
                            "导出错误", "OK", [Windows.MessageBoxImage]::Error)
                    })
                }
            } catch {
                Write-Win11ISOLog "ERROR during ISO export: $_"
                $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                    [System.Windows.MessageBox]::Show("ISO 导出失败:`n`n$_", "错误", "OK", [Windows.MessageBoxImage]::Error)
                })
            } finally {
                try {
                    $sync["WPFWin11ISOStatusLog"].Dispatcher.Invoke([action]{
                        $sync.progressBarTextBlock.Text    = ""
                        $sync.progressBarTextBlock.ToolTip = ""
                        $sync.ProgressBar.Value            = 0
                        $sync["WPFWin11ISOChooseISOButton"].IsEnabled = $true
                    })
                } finally {
                    $sync['Win11ISOExporting'] = $false
                    $sync.ProcessRunning = $false
                }
            }
        })

        $null = $script.BeginInvoke()
    } catch {
        $startupError = $_
        $sync['Win11ISOExporting'] = $false
        $sync.ProcessRunning = $false
        $sync['WPFWin11ISOChooseISOButton'].IsEnabled = $true
        if ($script) { try { $script.Dispose() } catch {} }
        if ($runspace) { try { $runspace.Dispose() } catch {} }

        Write-Win11ISOLog "无法启动镜像任务：$startupError"
        [Windows.MessageBox]::Show("无法启动镜像任务：`n`n$startupError", '任务未启动', 'OK', [Windows.MessageBoxImage]::Error) | Out-Null
    }
}
