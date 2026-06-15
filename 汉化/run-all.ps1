# winutil-cn 一键汉化 + 构建
# 上游(ChrisTitusTech/winutil)更新并 merge 后,重跑本脚本即可重新生成汉化版 winutil.ps1。
# 顺序:分类名 -> 界面骨架 -> 内容(tweaks/feature) -> 软件介绍(applications) -> 运行时(MessageBox/ToolTip) -> 编译
# 已是中文的条目会被自动跳过(英文 search 命中 0),幂等可重跑。
$ErrorActionPreference = 'Stop'
$d = $PSScriptRoot
Write-Output "[1/6] 分类名汉化...";                  & "$d\apply-categories.ps1"
Write-Output "[2/6] 界面骨架汉化...";                & "$d\apply-xaml.ps1"
Write-Output "[3/6] 内容(tweaks/feature)汉化...";    & "$d\apply-i18n.ps1"
Write-Output "[4/6] 软件介绍(applications)汉化...";   & "$d\apply-apps.ps1"
Write-Output "[5/6] 运行时(MessageBox/ToolTip)汉化..."; & "$d\apply-functions.ps1"
Write-Output "[6/6] 编译构建...";                    & "$d\build-cn.ps1"
Write-Output "`n完成。管理员运行:  .\winutil.ps1"
