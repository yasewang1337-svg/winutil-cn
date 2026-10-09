function Install-WinUtilISOAnswerFile {
    <# .SYNOPSIS Stages answer-file content only beneath the mounted image and ISO roots. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScratchDir, [Parameter(Mandatory)][string]$ISOContentsDir,
        [Parameter(Mandatory)][string]$Xml, [Parameter(Mandatory)][ValidateSet('Windows10','Windows11')][string]$WindowsVersion)
    $document = [xml]::new()
    $document.XmlResolver = $null
    $document.LoadXml($Xml)
    if ($document.DocumentElement.LocalName -ne 'unattend' -or $document.DocumentElement.NamespaceURI -ne 'urn:schemas-microsoft-com:unattend') { throw '安装应答文件格式无效。' }
    $namespaces = [Xml.XmlNamespaceManager]::new($document.NameTable)
    $namespaces.AddNamespace('u','urn:schemas-microsoft-com:unattend')
    $namespaces.AddNamespace('sg','https://schneegans.de/windows/unattend-generator/')
    foreach ($component in $document.SelectNodes('//u:component', $namespaces)) {
        if ($component.GetAttribute('processorArchitecture') -ne 'amd64') { throw '安装应答文件架构必须为 amd64。' }
    }
    if ($WindowsVersion -eq 'Windows10' -and ($document.SelectNodes('//sg:File',$namespaces).Count -gt 0 -or
        $document.DocumentElement.InnerText -match '(?i)Bypass|ViVeTool|TaskbarAl|ConfigureStartPins|LabConfig')) {
        throw 'Windows 10 应答文件包含 Windows 11 专用或外部脚本配置，已中止。'
    }
    $root = [IO.Path]::GetFullPath($ScratchDir).TrimEnd('\') + '\'
    $staged = @()
    foreach ($file in $document.SelectNodes('//sg:File', $namespaces)) {
        $path = $file.GetAttribute('path')
        if ($path -notmatch '^C:\\Windows\\Setup\\Scripts\\[^:]+$') { throw "应答文件路径不在 Windows Setup Scripts 中：$path" }
        $target = [IO.Path]::GetFullPath((Join-Path $root $path.Substring(3)))
        $allowed = Join-Path $root 'Windows\Setup\Scripts\'
        if (-not $target.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw '应答文件路径越界。' }
        $staged += [pscustomobject]@{Path=$target; Content=$file.InnerText.Trim()}
    }
    foreach ($file in $staged) {
        $null = New-Item -ItemType Directory -Path (Split-Path $file.Path -Parent) -Force -ErrorAction Stop
        $encoding = if ([IO.Path]::GetExtension($file.Path) -in @('.reg','.vbs','.js')) { [Text.UnicodeEncoding]::new($false,$true) } else { [Text.UTF8Encoding]::new($true) }
        [IO.File]::WriteAllText($file.Path, $file.Content, $encoding)
    }
    [IO.File]::WriteAllText((Join-Path $ISOContentsDir 'autounattend.xml'), $Xml, [Text.UTF8Encoding]::new($true))
}
