# functions/ 运行时字符串汉化(MessageBox 文案/标题 + 运行时 ToolTip)
# 数据:i18n-functions.json —— [{file, en, zh, kind}](由汉化 Workflow 产出)
# 把代码里的字符串字面量 "en" 精确替换为 "zh",保留 $var / `n / 参数。
# 关键:这是改【代码】,每个文件替换后用 ParseFile 复检语法,出错自动回滚该文件。
$ErrorActionPreference='Stop'
$dir=$PSScriptRoot
$mapFile=Join-Path $dir 'i18n-functions.json'
$enc=[System.Text.UTF8Encoding]::new($false)   # functions 源为 UTF-8 no BOM
if(-not (Test-Path $mapFile)){ Write-Warning "缺少 $mapFile(先跑汉化 Workflow 生成),跳过"; return }
$items=Get-Content $mapFile -Raw|ConvertFrom-Json

$byFile=@{}
foreach($it in $items){ if(-not $byFile.ContainsKey($it.file)){$byFile[$it.file]=@()}; $byFile[$it.file]+=$it }

$totalApplied=0;$totalMiss=0;$rolledBack=@()
foreach($f in $byFile.Keys){
  if(-not (Test-Path $f)){ Write-Warning "文件不存在: $f"; continue }
  $text=[IO.File]::ReadAllText($f,$enc); $orig=$text
  $applied=0
  foreach($it in $byFile[$f]){
    if($it.en -eq $it.zh){ continue }
    $search='"'+$it.en+'"'; $replace='"'+$it.zh+'"'
    if($text.Contains($search)){ $text=$text.Replace($search,$replace);$applied++ }
    else{ $totalMiss++; Write-Warning ("未命中 [{0}] {1}: {2}" -f $it.kind,[IO.Path]::GetFileName($f),($it.en.Substring(0,[math]::Min(45,$it.en.Length)))) }
  }
  if($text -ne $orig){
    $tmp="$f.tmp"
    [IO.File]::WriteAllText($tmp,$text,$enc)
    $errs=$null;$toks=$null
    [System.Management.Automation.Language.Parser]::ParseFile($tmp,[ref]$toks,[ref]$errs)|Out-Null
    if($errs.Count -eq 0){ Move-Item $tmp $f -Force; $totalApplied+=$applied }
    else{ Remove-Item $tmp -Force; $rolledBack+=[IO.Path]::GetFileName($f); Write-Warning "$([IO.Path]::GetFileName($f)) 替换后语法错误 $($errs.Count) 处,已回滚不改" }
  }
}
"functions 汉化: 应用={0} 未命中={1} 语法回滚={2}" -f $totalApplied,$totalMiss,$rolledBack.Count
if($rolledBack.Count){ "回滚文件: $($rolledBack -join ', ')" }
