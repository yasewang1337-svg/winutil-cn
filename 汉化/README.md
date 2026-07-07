# winutil-cn 汉化层

ChrisTitusTech/winutil 的中文化,**作为独立工具收编**(不接 PGOS/intent-kernel 大脑)。
汉化只改用户可见文本,**不碰** 逻辑 / 注册表 / 命令 / `InvokeScript` / 控件 key —— 与上游解耦,便于跟版本。
✅ **已真机验证**:GUI 中文显示正常、winget 安装功能跑通(实测装 Docker)。

## 一键重汉化 + 构建

```powershell
pwsh -File 汉化\run-all.ps1
# 管理员运行(首次启动较慢:winget 初始化 + 加载 ~190 应用,Responding=False 是加载中不是卡死,耐心等):
Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File W:\dev\projects\winutil-cn\winutil.ps1'
```

## 机制(声明=数据,应用=机械门,可复跑)

**翻译数据**(JSON,按 winutil 稳定 key 索引):

| 数据文件 | 内容 | 来源 |
|---|---|---|
| `i18n-borrowed.json`   | tweaks/feature 的 Content/Description | 借自 constansino/WinUtil_CN |
| `i18n-supplement.json` | 上游新增、借用层未覆盖的 tweaks | 本机补翻 |
| `i18n-apps.json`       | applications 191 条软件介绍 | 本机多 agent 并行翻译 |
| `i18n-functions.json`  | 运行时 MessageBox/ToolTip(62 对) | 从 diff 反向重建(权威) |
| `extra-apps.json`      | 专属软件层(winutil 未收录、你要的,如 Docker) | 本机维护 |

**应用脚本**(精确值替换 + 命中校验;改代码的还做 ParseFile 复检 + 出错回滚):

| 脚本 | 作用 |
|---|---|
| `apply-categories.ps1`     | 分类名(保留 `z__`/`__` 排序前缀) |
| `apply-xaml.ps1`           | 界面骨架(Header/Content/Text/ToolTip 字面标签) |
| `apply-i18n.ps1`           | tweaks/feature 内容(合并 borrowed+supplement) |
| `apply-apps.ps1`           | applications 软件介绍(读 i18n-apps) |
| `apply-functions.ps1`      | functions 运行时字符串(ParseFile 复检 + 回滚) |
| `apply-extra-apps.ps1`     | 注入 extra-apps 到 applications.json |
| `extract-borrowed.ps1`     | 从 constansino 产物提取借用层 |
| `extract-functions-i18n.ps1` | 从 diff 重建 functions 权威翻译数据 |
| `build-cn.ps1`             | Compile.ps1 → UTF-8 BOM + 容忍杀毒拦截 |
| `run-all.ps1`              | 串联全流程(6 步) |

> 注:functions 运行时翻译曾由 Workflow 的 agent 直接改文件(非走 apply),故用 `extract-functions-i18n.ps1` 从 diff 反向重建 `i18n-functions.json`,保证可复现。

## 跟上游更新

```powershell
git fetch upstream && git merge upstream/main    # upstream=ChrisTitusTech
pwsh -File 汉化\run-all.ps1
```
各 apply 脚本会报"未命中/缺 key",据此把新增条目补进对应数据文件。

## 汉化覆盖(已真机验证)

- ✅ 界面骨架(选项卡/菜单/按钮/提示)+ 全部分类名
- ✅ tweaks 65 + feature 29 的 Content/Description
- ✅ applications 191 条软件介绍 description(多 agent 翻译)
- ✅ 运行时 MessageBox 弹窗 + ToolTip(62 对)
- ➕ 专属软件:Docker Desktop(extra-apps)

## 来源与许可

- 上游:[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)(MIT)
- 借用层翻译:[constansino/WinUtil_CN](https://github.com/constansino/WinUtil_CN)(仓库未声明许可)

本汉化层沿用上游的 MIT 许可。非官方,运行涉及系统级修改,请先备份。
