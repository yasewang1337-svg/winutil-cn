# winutil-cn 一键汉化 + 构建
# 上游(ChrisTitusTech/winutil)更新并 merge 后,重跑本脚本即可重新生成汉化版 winutil.ps1。
# 顺序:分类名 -> 界面骨架 -> 内容(tweaks/feature) -> 编译(+UTF-8 BOM,火绒容错)
# 已是中文的条目会被自动跳过(英文 search 命中 0),幂等可重跑。
$ErrorActionPreference = 'Stop'
$d = $PSScriptRoot
Write-Output "[1/4] 分类名汉化..."; & "$d\apply-categories.ps1"
Write-Output "[2/4] 界面骨架汉化..."; & "$d\apply-xaml.ps1"
Write-Output "[3/5] 内容(tweaks/feature)汉化..."; & "$d\apply-i18n.ps1"
Write-Output "[4/5] 软件介绍(applications)汉化..."; & "$d\apply-apps.ps1"
Write-Output "[5/5] 编译构建..."; & "$d\build-cn.ps1"
Write-Output "`n完成。管理员运行:  .\winutil.ps1"
