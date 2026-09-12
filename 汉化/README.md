# 汉化层：日常构建与翻译维护

日常生成中文版时运行 `run-all.ps1`。它在临时目录复制构建输入，在副本中应用翻译、合并额外软件并编译；检查通过后，才原子替换仓库根目录的 `winutil.ps1`。源 `config/`、`functions/`、`xaml/` 和翻译数据不会被日常构建改写。构建失败时保留上一次成功产物，错误不会被当作成功忽略。

```powershell
# 在仓库根目录执行；也可以从其他目录使用脚本的完整路径。
pwsh -NoProfile -File .\汉化\run-all.ps1
# Windows PowerShell 5.1 也支持：
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\汉化\run-all.ps1
```

输出仍是根目录的 `winutil.ps1`，与现有发布、测试和启动器调用兼容。此步骤只生成文件，不运行 WinUtil，也不安装软件或修改系统。EXE 打包另见 [启动器说明](../tools/launcher/README.md)。

## 文件职责

| 入口或数据 | 用途 |
| --- | --- |
| `run-all.ps1` | 日常入口：临时副本内依次运行六个 `apply-*`，再调用 `build-cn.ps1` |
| `build-cn.ps1` | 直接调用当前目录对应仓库的 `Compile.ps1`，不主动应用翻译；日常优先使用 `run-all.ps1` |
| `apply-*.ps1` | 维护入口：**直接运行会修改源码**，应在可审查的工作分支执行 |
| `maintenance/extract-functions-i18n.ps1` | 从显式指定的 Git 差异提取运行时双引号字符串，合并到已有映射 |
| `maintenance/extract-borrowed.ps1` | 从显式指定的中文编译脚本读取 tweaks / feature 文本，合并借用层 |
| 顶层两个 `extract-*.ps1` | 兼容旧位置的薄入口，参数和行为与 maintenance 中的实现相同 |
| `i18n-functions.json` | `file + en` 标识的运行时翻译；路径相对于仓库、必须位于 `functions/` |
| `i18n-borrowed.json`、`i18n-supplement.json` | 按稳定控件编号组织的设置及功能文本； supplement 覆盖同字段的 borrowed |
| `i18n-apps.json` | 软件介绍翻译 |
| `extra-apps.json` | 构建时额外合并的软件目录条目 |

## 维护运行时翻译

先整理只包含文本替换的差异，再明确选择输入方式。没有参数或没有中文替换时，提取器报错并保留原表；不会用空结果覆盖翻译。单次少量差异只新增或更新对应 `file + en`，其他记录保留。

```powershell
# 比较已知基线与当前工作树（可包含已暂存和未暂存的修改）。
pwsh -File .\汉化\maintenance\extract-functions-i18n.ps1 -BaseRef HEAD

# 比较两个已有版本；把示例引用替换成要核对的实际提交/标签。
pwsh -File .\汉化\maintenance\extract-functions-i18n.ps1 -BaseRef <旧版本> -TargetRef <新版本>

# 或读取 UTF-8 git diff 文件。保留默认 a/、b/ 路径前缀。
pwsh -File .\汉化\maintenance\extract-functions-i18n.ps1 -DiffPath .\translations.diff
```

默认仓库是脚本所在仓库，可用 `-RepositoryRoot` 指向另一个源码副本；默认输出为该仓库的 `汉化/i18n-functions.json`，也可显式指定 `-OutputPath`。不接受机器绝对路径写入翻译条目，也不允许路径越出 `functions/`。

显式提供的相对输入、输出和仓库路径按 PowerShell 当前目录解析；仅接受文件系统路径。切换目录后使用 `-RepositoryRoot .` 可选择当前工作副本。

提取仅处理同一差异块内可逐行配对的双引号字符串。增删行数或字符串数量不一致会失败，避免将结构修改误配成翻译；单引号和 here-string 需要人工整理。完全相同的重复翻译会合并；同一输入中一个英文对应不同中文会失败。现有映射与新映射会分别校验，JSON 重复字段、无效条目或路径都不能发布。输出先写同目录临时文件、重新读取校验，再原子替换。

## 维护借用层

```powershell
pwsh -File .\汉化\maintenance\extract-borrowed.ps1 -SourcePath .\reference\winutil.zh_CN.ps1
```

输入文件由维护者自行提供，脚本只读取其中 `$sync.configs.tweaks` / `$sync.configs.feature` 的 JSON here-string，不执行参考脚本。仅提取含中文的 `Content` / `Description`，按分组、控件编号和字段合并已有翻译；没有中文命中、无效 JSON、重复配置段或无效编号时保留原文件。`-OutputPath` 可指定另一个现有目录下的输出文件。

借用层的历史来源为 [constansino/WinUtil_CN](https://github.com/constansino/WinUtil_CN)，上游为 [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)。引入新翻译时应保留其来源及相应许可信息；提取工具本身不能代替来源核对。

## 直接修改源文件时

维护者明确需要将翻译写回源码时，才直接运行对应的 `apply-*`：分类、XAML、设置文本、软件介绍、额外软件、运行时字符串。完成后检查 `git diff` 并运行相关测试。`apply-functions.ps1` 会校验修改后的 PowerShell 语法，语法失败的文件保留原内容；其他未命中和已删除控件会报告，不能把“流程结束”理解为新增上游内容已全部汉化。

上游同步应先在工作分支审查代码差异，补齐数据，再用 `run-all.ps1` 构建和验证。它不会自动合并上游，也不会提交提取出的翻译。
