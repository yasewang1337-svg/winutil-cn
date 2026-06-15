# applications 软件介绍(description)汉化
# 数据:i18n-apps.json —— {key: 中文description}(由翻译 Workflow 产出)
# 只替换 config/applications.json 的 description 字段值(英文 -> 中文),
# content(产品名)/winget/choco/link/category/key 一律不动。精确值替换,命中必须唯一。
$ErrorActionPreference='Stop'
$dir=$PSScriptRoot
$path=Join-Path $dir '..\config\applications.json'
$mapFile=Join-Path $dir 'i18n-apps.json'
$enc=[System.Text.UTF8Encoding]::new($false)
if(-not (Test-Path $mapFile)){ Write-Warning "缺少 $mapFile(先跑翻译 Workflow 生成),跳过 applications 汉化"; return }
$map = Get-Content $mapFile -Raw | ConvertFrom-Json
$obj = Get-Content $path -Raw | ConvertFrom-Json
$text = [IO.File]::ReadAllText($path,$enc)
$applied=0;$miss=0;$already=0;$nokey=0
foreach($e in $map.PSObject.Properties){
  $k=$e.Name; $zh=$e.Value
  if(-not $obj.PSObject.Properties[$k]){ $nokey++; continue }
  $en=$obj.$k.description
  if([string]::IsNullOrEmpty($en)){ continue }
  if($en -eq $zh){ $already++; continue }
  $search='"description": '+($en|ConvertTo-Json -Compress)
  $replace='"description": '+($zh|ConvertTo-Json -Compress)
  # 相同英文 description(如 java8/21/25 同文案)一次性全替换为同一中文,安全
  if($text.Contains($search)){ $text=$text.Replace($search,$replace);$applied++ }
  else{ $miss++ }
}
[IO.File]::WriteAllText($path,$text,$enc)
"applications: 应用={0} 已中文={1} 未命中={2} 缺key={3}" -f $applied,$already,$miss,$nokey
