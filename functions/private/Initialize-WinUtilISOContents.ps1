function Initialize-WinUtilISOContents {
    <# .SYNOPSIS Copies setup files and converts the selected WIM/ESD edition to a writable single-index WIM. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$SourceImage,
        [Parameter(Mandatory)][int]$ImageIndex, [Parameter(Mandatory)][string]$ContentsDirectory)
    if (Test-Path -LiteralPath (Join-Path $ContentsDirectory 'sources\install.wim')) { throw '目标目录已有安装镜像，拒绝混用旧文件。' }
    & robocopy $SourceRoot $ContentsDirectory /E /XF install.wim install.esd install*.swm /XJ /R:2 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    Assert-WinUtilISONativeExit -Operation '复制 ISO 文件' -ExitCode $LASTEXITCODE -Robocopy
    $target = Join-Path $ContentsDirectory 'sources\install.wim'
    $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force -ErrorAction Stop
    Export-WindowsImage -SourceImagePath $SourceImage -SourceIndex $ImageIndex -DestinationImagePath $target -CompressionType Maximum -CheckIntegrity -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw '导出后没有生成 install.wim。' }
    Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $false -ErrorAction Stop
    return $target
}
