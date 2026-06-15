# 从 git diff 重建 functions 运行时翻译的【权威】数据 -> i18n-functions.json
# 背景:运行时汉化是 Workflow 的 agent 直接改了 functions/*.ps1(非走 apply),
#   故 i18n-functions.json 需从已落地的 diff 反向提取,才完整可复现(上游 merge 后用 apply-functions 重汉化)。
# 仅在 functions 仍有未提交 diff 时有效;提交后改用 git log 对比。
$ErrorActionPreference='Stop'
$r=Split-Path $PSScriptRoot -Parent
$files = git -C $r diff --name-only -- functions/
$items=@()
foreach($rel in $files){
  $diff = git -C $r diff -U0 -- $rel
  $olds=@();$news=@()
  foreach($line in $diff){
    if($line.StartsWith('-') -and -not $line.StartsWith('---')){ $olds += $line.Substring(1) }
    elseif($line.StartsWith('+') -and -not $line.StartsWith('+++')){ $news += $line.Substring(1) }
  }
  $n=[math]::Min($olds.Count,$news.Count)
  for($i=0;$i -lt $n;$i++){
    $oStr=[regex]::Matches($olds[$i],'"((?:[^"\\]|\\.)*)"')
    $nStr=[regex]::Matches($news[$i],'"((?:[^"\\]|\\.)*)"')
    $m=[math]::Min($oStr.Count,$nStr.Count)
    for($j=0;$j -lt $m;$j++){
      $en=$oStr[$j].Groups[1].Value; $zh=$nStr[$j].Groups[1].Value
      if($en -ne $zh -and $zh -match '\p{IsCJKUnifiedIdeographs}'){
        $items += [pscustomobject]@{ file=('W:/dev/projects/winutil-cn/'+($rel -replace '\\','/')); en=$en; zh=$zh; kind='runtime' }
      }
    }
  }
}
$enc=[System.Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'i18n-functions.json'),($items|ConvertTo-Json -Depth 4),$enc)
"从 diff 提取 $($items.Count) 对英文->中文 -> i18n-functions.json"
