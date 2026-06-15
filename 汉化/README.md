# winutil-cn 汉化层

ChrisTitusTech/winutil 的中文化,**作为独立工具收编**(不接 PGOS/intent-kernel 大脑)。
汉化只改用户可见文本,**不碰** 逻辑 / 注册表 / 命令 / `InvokeScript` / 控件 key —— 与上游解耦,便于跟版本。

## 一键重汉化

```powershell
pwsh -File 汉化\run-all.ps1
# 然后管理员运行:
Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File W:\dev\projects\winutil-cn\winutil.ps1'
```

## 机制(声明=数据,应用=机械门,可复跑)

| 文件 | 作用 |
|---|---|
| `apply-categories.ps1` | 分类名汉化(精确替换 `config/*.json` 的 category 值,保留 `z__`/`__` 排序前缀) |
| `apply-xaml.ps1` | 界面骨架汉化(`xaml/inputXML.xaml` 的 Header/Content/Text/ToolTip 字面标签) |
| `i18n-borrowed.json` | **借用层**:从 constansino/WinUtil_CN 提取的 tweaks/feature 中文(按稳定 key 索引) |
| `i18n-supplement.json` | **补翻层**:上游新增、借用层未覆盖的条目(本机翻译) |
| `apply-i18n.ps1` | 内容汉化:合并两层,按 key 把 tweaks/feature 的 Content/Description 英文值精确替换为中文 |
| `extract-borrowed.ps1` | 从汉化版编译产物重新提取借用层(换参考版本时用) |
| `build-cn.ps1` | 调用上游 `Compile.ps1` 生成 `winutil.ps1`,转 UTF-8 BOM(兼容 PS5.1 中文),容忍安全软件拦截 |
| `run-all.ps1` | 串联以上全流程 |

## 跟上游更新

```powershell
git remote add upstream https://github.com/ChrisTitusTech/winutil.git   # 首次
git fetch upstream && git merge upstream/main                            # 拉最新英文源
pwsh -File 汉化\run-all.ps1                                              # 重汉化
```
`apply-i18n.ps1` 会报告"未命中/缺 key",据此把新增条目补进 `i18n-supplement.json`。

## 汉化覆盖

- ✅ 界面骨架(选项卡/菜单/按钮/提示)、全部分类名
- ✅ tweaks 65 项 + feature 29 项的 Content/Description(系统优化/功能项)
- ⬜ applications 软件介绍 description(保留英文,与上游汉化社区惯例一致;content 已是产品名)

## 来源与许可

- 上游:[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)(GPL-3.0)
- 借用层翻译:[constansino/WinUtil_CN](https://github.com/constansino/WinUtil_CN)(GPL-3.0,同步上游 26.04.21 / 汉化 2026-05-10)

本汉化层同为 GPL-3.0。非官方,运行涉及系统级修改,请先备份。
