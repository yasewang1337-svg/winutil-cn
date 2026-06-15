# winutil-cn 内容汉化(tweaks/feature 的 Content/Description)
# 数据来源两层(按 winutil 稳定 key 索引):
#   i18n-borrowed.json   —— 借自 constansino/WinUtil_CN(GPL-3.0),复用其已翻条目
#   i18n-supplement.json —— 本机补翻:上游新增、借用层未覆盖的条目
# 应用方式:对 config/tweaks.json、config/feature.json 做【精确值替换】(英文值 -> 中文值),
#   用 ConvertTo-Json 编码两端以匹配文件中的转义形式,保留原格式;只动 Content/Description,
#   不碰 key / category / registry / InvokeScript / UndoScript。命中必须唯一,否则跳过防误伤。
# 可复跑:上游更新后重跑 build,再跑本脚本即可;已是中文的条目自动跳过。
$ErrorActionPreference = 'Stop'
$dir  = $PSScriptRoot
$cfg  = Join-Path $dir '..\config'
$enc  = [System.Text.UTF8Encoding]::new($false)

# 合并两层映射 -> $map[section][key] = @{ Content=..; Description=.. }
$map = @{ tweaks = @{}; feature = @{} }
foreach ($f in 'i18n-borrowed.json','i18n-supplement.json') {
    $p = Join-Path $dir $f
    if (-not (Test-Path $p)) { continue }
    $src = Get-Content $p -Raw | ConvertFrom-Json
    foreach ($sec in 'tweaks','feature') {
        if (-not $src.PSObject.Properties[$sec]) { continue }
        foreach ($e in $src.$sec.PSObject.Properties) {
            if (-not $map[$sec].ContainsKey($e.Name)) { $map[$sec][$e.Name] = @{} }
            foreach ($fld in 'Content','Description') {
                if ($e.Value.PSObject.Properties[$fld]) { $map[$sec][$e.Name][$fld] = $e.Value.$fld }
            }
        }
    }
}

foreach ($sec in 'tweaks','feature') {
    $path  = Join-Path $cfg "$sec.json"
    $obj   = Get-Content $path -Raw | ConvertFrom-Json
    $text  = [IO.File]::ReadAllText($path, $enc)
    $applied = 0; $miss = 0; $multi = 0; $alreadyCN = 0; $noKey = 0
    foreach ($k in $map[$sec].Keys) {
        if (-not $obj.PSObject.Properties[$k]) { $noKey++; continue }   # 我的版本无此 key(上游已删/改名)
        $en = $obj.$k
        foreach ($fld in 'Content','Description') {
            if (-not $map[$sec][$k].ContainsKey($fld)) { continue }
            if (-not $en.PSObject.Properties[$fld]) { continue }
            $enVal = $en.$fld; $zhVal = $map[$sec][$k][$fld]
            if ([string]::IsNullOrEmpty($enVal)) { continue }
            if ($enVal -eq $zhVal) { $alreadyCN++; continue }
            $search  = '"' + $fld + '": ' + ($enVal | ConvertTo-Json -Compress)
            $replace = '"' + $fld + '": ' + ($zhVal | ConvertTo-Json -Compress)
            $n = ([regex]::Matches($text, [regex]::Escape($search))).Count
            if     ($n -eq 1) { $text = $text.Replace($search, $replace); $applied++ }
            elseif ($n -eq 0) { $miss++ }
            else              { Write-Warning "$sec.$k.$fld 命中 $n 次,跳过"; $multi++ }
        }
    }
    [IO.File]::WriteAllText($path, $text, $enc)
    "{0,-8} 应用={1,3} 已中文={2,3} 未命中={3,2} 多命中={4} 缺key={5}" -f $sec, $applied, $alreadyCN, $miss, $multi, $noKey
}
Write-Output "内容汉化完成。"
