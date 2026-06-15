# winutil-cn 分类名汉化
# 只替换 config/*.json 里 category/Category 字段的【值】,保留排序前缀(z__ / ____ / __)。
# 不碰 key / registry / InvokeScript / winget / choco / link。最小 diff、可重复、上游 merge 后可重跑。
$ErrorActionPreference = 'Stop'
$cfg = Join-Path $PSScriptRoot '..\config'
$enc = [System.Text.UTF8Encoding]::new($false)  # UTF-8 no BOM,与上游一致

$files = [ordered]@{
  'applications.json' = [ordered]@{
    '"category": "Browsers"'         = '"category": "浏览器"'
    '"category": "Communications"'   = '"category": "通讯"'
    '"category": "Development"'       = '"category": "开发工具"'
    '"category": "Games"'            = '"category": "游戏"'
    '"category": "Microsoft Tools"'  = '"category": "微软工具"'
    '"category": "Multimedia Tools"' = '"category": "多媒体工具"'
    '"category": "Pro Tools"'        = '"category": "专业工具"'
    '"category": "Selfhosted Tools"' = '"category": "自托管工具"'
    '"category": "Utilities"'        = '"category": "实用工具"'
  }
  'tweaks.json' = [ordered]@{
    '"category": "Customize Preferences"'               = '"category": "自定义偏好"'
    '"category": "Essential Tweaks"'                    = '"category": "必备优化"'
    '"category": "Performance Plans - NOT FOR LAPTOPS"' = '"category": "性能计划 - 不适用于笔记本"'
    '"category": "z__Advanced Tweaks - CAUTION"'        = '"category": "z__高级优化 - 谨慎"'
  }
  'feature.json' = [ordered]@{
    '"category": "Features"'                              = '"category": "功能"'
    '"category": "Fixes"'                                 = '"category": "修复"'
    '"category": "Legacy Windows Panels"'                 = '"category": "传统 Windows 面板"'
    '"category": "Powershell Profile Powershell 7+ Only"' = '"category": "PowerShell 配置文件(仅 7+)"'
    '"category": "Remote Access"'                         = '"category": "远程访问"'
  }
  # appnavigation.json 由 汉化/ 下的完整中文文件维护(Content+Description+Category 全译),此处不重复。
}

foreach ($f in $files.Keys) {
  $path = Join-Path $cfg $f
  $text = [IO.File]::ReadAllText($path, $enc)
  foreach ($en in $files[$f].Keys) {
    $n = ([regex]::Matches($text, [regex]::Escape($en))).Count
    if ($n -eq 0) { Write-Warning "未命中: $f  <- $en" }
    $text = $text.Replace($en, $files[$f][$en])
    "{0,-20} {1,3}x  {2}" -f $f, $n, ($en -replace '^"[^"]+": ', '')
  }
  [IO.File]::WriteAllText($path, $text, $enc)
}
Write-Output "`n分类汉化完成。"
