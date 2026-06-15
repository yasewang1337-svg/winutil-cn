# 把"专属软件层" extra-apps.json 注入 config/applications.json
# - 已存在的 key 自动跳过(幂等);注入到首个条目前,保持 4 空格缩进格式
# - 注入后校验 JSON 有效性才写回
# 上游更新后重跑即可重新注入你的软件。
$ErrorActionPreference='Stop'
$dir=$PSScriptRoot
$appsPath=Join-Path $dir '..\config\applications.json'
$extraPath=Join-Path $dir 'extra-apps.json'
$enc=[System.Text.UTF8Encoding]::new($false)
if(-not(Test-Path $extraPath)){ Write-Warning "无 extra-apps.json,跳过"; return }
$extra=Get-Content $extraPath -Raw|ConvertFrom-Json
$text=[IO.File]::ReadAllText($appsPath,$enc)
$appsObj=$text|ConvertFrom-Json
$order='category','choco','content','description','link','winget','foss'
$firstKey=$appsObj.PSObject.Properties.Name | Select-Object -First 1
$anchor='"'+$firstKey+'": {'
$blocks=@();$skip=0
foreach($e in $extra.PSObject.Properties){
  if($e.Name -eq '_meta'){ continue }
  if($appsObj.PSObject.Properties[$e.Name]){ $skip++; continue }
  $lines=foreach($p in $order){ if($e.Value.PSObject.Properties[$p]){ '        "'+$p+'": '+($e.Value.$p|ConvertTo-Json -Compress) } }
  $blocks += '"'+$e.Name+'": {'+"`r`n"+($lines -join ",`r`n")+"`r`n    }"
}
if($blocks.Count){
  $inject=(($blocks|ForEach-Object{$_+','}) -join "`r`n    ")+"`r`n    "
  $text=$text.Replace($anchor, $inject+$anchor)
  $null=$text|ConvertFrom-Json
  [IO.File]::WriteAllText($appsPath,$text,$enc)
}
"extra-apps 注入: 新增={0} 跳过(已存在)={1}" -f $blocks.Count,$skip
