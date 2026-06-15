# winutil-cn 界面骨架汉化(xaml/inputXML.xaml)
# 只替换带属性前缀(Header=/Content=/Text=/ToolTip=)的字面英文标签,
# 不碰 Name= / x:Name= / {Binding} / 资源键 / 事件绑定。保留 N/A、100% 等动态/数值占位。
# 最小 diff、可重复、上游 merge 后可重跑(已译条目重跑会提示 0 命中,无害)。
$ErrorActionPreference = 'Stop'
$xaml = Join-Path $PSScriptRoot '..\xaml\inputXML.xaml'
$enc  = [System.Text.UTF8Encoding]::new($false)  # UTF-8 no BOM,与上游一致

$map = [ordered]@{
  # 右键/编辑菜单
  'Header="Cut"'   = 'Header="剪切"'
  'Header="Copy"'  = 'Header="复制"'
  'Header="Paste"' = 'Header="粘贴"'
  # 搜索/主题/字体
  'ToolTip="Press Ctrl-F and type app name to filter application list below. Press Esc to reset the filter"' = 'ToolTip="按 Ctrl-F 输入软件名筛选下方列表,按 Esc 清除筛选"'
  'ToolTip="Change the WinUtil UI Theme"' = 'ToolTip="切换 WinUtil 界面主题"'
  'Header="Auto"'  = 'Header="自动"'
  'Content="Follow the Windows Theme"' = 'Content="跟随 Windows 主题"'
  'Header="Dark"'  = 'Header="深色"'
  'Content="Use Dark Theme"'  = 'Content="使用深色主题"'
  'Header="Light"' = 'Header="浅色"'
  'Content="Use Light Theme"' = 'Content="使用浅色主题"'
  'ToolTip="Adjust Font Scaling for Accessibility"' = 'ToolTip="调整字体缩放以提升可读性"'
  'Text="Font Scaling"' = 'Text="字体缩放"'
  'Text="Small"'   = 'Text="小"'
  'Text="Large"'   = 'Text="大"'
  'Content="Reset"' = 'Content="重置"'
  'Content="Apply"' = 'Content="应用"'
  # 导入/导出/关于 菜单
  'Header="Import"' = 'Header="导入"'
  'Content="Import Configuration from exported file."' = 'Content="从导出的文件导入配置。"'
  'Header="Export"' = 'Header="导出"'
  'Content="Export Selected Elements and copy execution command to clipboard."' = 'Content="导出所选项并将执行命令复制到剪贴板。"'
  'Header="About"'         = 'Header="关于"'
  'Header="Documentation"' = 'Header="文档"'
  'Header="Sponsors"'      = 'Header="赞助者"'
  # 主选项卡
  'Header="Install"' = 'Header="安装"'
  'Header="Tweaks"'  = 'Header="优化"'
  'Header="Config"'  = 'Header="配置"'
  'Header="Updates"' = 'Header="更新"'
  'Header="Win11ISO"' = 'Header="Win11 镜像"'
  # 优化页
  'Content="Recommended Selections:"' = 'Content="推荐方案:"'
  'Content="Run Tweaks"'          = 'Content="运行优化"'
  'Content="Undo Selected Tweaks"' = 'Content="撤销所选优化"'
  # 更新页
  'Content="Default Settings"'   = 'Content="默认设置"'
  'Content="Security Settings"'  = 'Content="安全设置"'
  'Content="Disable All Updates"' = 'Content="禁用所有更新"'
  # Win11 镜像页(MicroWin)
  'Text="No ISO selected..."'    = 'Text="未选择 ISO..."'
  'Content="Browse"'             = 'Content="浏览"'
  'Content="Open Microsoft Download Page"' = 'Content="打开微软下载页面"'
  'Content="Mount &amp; Verify ISO"'       = 'Content="挂载并校验 ISO"'
  'Content="Inject current system drivers"' = 'Content="注入当前系统驱动"'
  'ToolTip="Exports all drivers from this machine and injects them into install.wim and boot.wim. Recommended for systems with unsupported NVMe or network controllers."' = 'ToolTip="从本机导出所有驱动并注入 install.wim 与 boot.wim。适用于 NVMe 或网卡不受支持的系统。"'
  'Content="Run Windows ISO Modification and Creator"' = 'Content="运行 Windows ISO 修改与制作"'
  'Content="Clean &amp; Reset"'  = 'Content="清理并重置"'
  'ToolTip="Delete the temporary working directory and reset the interface back to Step 1"' = 'ToolTip="删除临时工作目录并将界面重置回第 1 步"'
  'Content="Save as an ISO File"' = 'Content="保存为 ISO 文件"'
  'Content="Write Directly to a USB Drive (ERASES DRIVE)"' = 'Content="直接写入 U 盘(会擦除磁盘)"'
  'Content="Refresh"'            = 'Content="刷新"'
  'Content="Erase &amp; Write to USB"' = 'Content="擦除并写入 U 盘"'
  'Text="Ready. Please select a Windows 11 ISO to begin."' = 'Text="就绪。请选择一个 Windows 11 ISO 开始。"'
}

$text = [IO.File]::ReadAllText($xaml, $enc)
$hit = 0; $miss = 0
foreach ($en in $map.Keys) {
  $n = ([regex]::Matches($text, [regex]::Escape($en))).Count
  if ($n -eq 0) { Write-Warning "未命中: $en"; $miss++ } else { $hit += $n }
  $text = $text.Replace($en, $map[$en])
}
[IO.File]::WriteAllText($xaml, $text, $enc)
Write-Output ("xaml 汉化完成:替换 {0} 处,未命中 {1} 条。" -f $hit, $miss)
