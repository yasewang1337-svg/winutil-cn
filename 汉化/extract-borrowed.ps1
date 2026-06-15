# 从 constansino/WinUtil_CN 编译产物提取 tweaks/feature 的中文翻译,固化为 i18n-borrowed.json
# 来源: constansino/WinUtil_CN  winutil.zh_CN.ps1 (同步上游 26.04.21, 汉化日期 2026-05-10, GPL-3.0)
# 仅提取【含中文】的 Content/Description,按 winutil 稳定 key(如 WPFTweaksActivity)索引。
# 用法: pwsh -File 汉化\extract-borrowed.ps1 <winutil.zh_CN.ps1 路径>
$ErrorActionPreference='Stop'
$src = if($args[0]){$args[0]}else{'W:\temp\winutil-cn-ref\winutil.zh_CN.ps1'}
if(-not (Test-Path $src)){ throw "找不到汉化版产物: $src" }
$out = Join-Path $PSScriptRoot 'i18n-borrowed.json'
$raw = [IO.File]::ReadAllText($src)
$pat = "(?s)\`$sync\.configs\.(tweaks|feature) = @'\r?\n(.*?)\r?\n'@"
$result = [ordered]@{}
foreach($m in [regex]::Matches($raw,$pat)){
  $section=$m.Groups[1].Value
  $obj = $m.Groups[2].Value | ConvertFrom-Json
  $result[$section]=[ordered]@{}
  foreach($p in $obj.PSObject.Properties){
    $v=$p.Value; $entry=[ordered]@{}
    if($v.PSObject.Properties['Content'] -and $v.Content -match '\p{IsCJKUnifiedIdeographs}'){ $entry['Content']=$v.Content }
    if($v.PSObject.Properties['Description'] -and $v.Description -match '\p{IsCJKUnifiedIdeographs}'){ $entry['Description']=$v.Description }
    if($entry.Count){ $result[$section][$p.Name]=$entry }
  }
}
$json = $result | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($out, $json, [Text.UTF8Encoding]::new($false))
"borrowed:  tweaks=$($result.tweaks.Count)  feature=$($result.feature.Count)  -> $out"
