# 仓库目录与维护入口

普通使用从根目录 [README](../README.md) 和[快速上手](content/userguide/getting-started/_index.md)开始。本文帮助维护者区分运行源码、构建工具、文档与历史材料。

| 位置 | 职责 | 维护约定 |
| --- | --- | --- |
| [Compile.ps1](../Compile.ps1) | 把函数、配置、XAML 和启动脚本编译为单文件脚本 | 只放当前编译入口；发布方法见[维护说明](MAINTENANCE.md) |
| [functions](../functions/README.md) | 软件管理、设置与恢复、界面、修复和镜像函数 | public/private 保留路径，以领域索引查找；本目录的 `.ps1` 会进入编译结果 |
| [config](../config/) | 运行时软件、设置、方案、主题等配置 | 编译器扫描顶层 JSON；示例、归档和测试数据不要混入 |
| [scripts](../scripts/) | 参数、提权、主窗口初始化与事件注册 | 影响用户实际启动入口，修改后同时检查 EXE 与脚本方式 |
| [xaml](../xaml/) | 主窗口结构、资源与样式 | 动态控件还需联动 functions 和 config |
| [汉化](../汉化/README.md) | 翻译数据、中文软件层及本地化构建 | 日常构建与提取维护工具以该目录说明为准 |
| [pester](../pester/) | 回归测试 | 可执行测试用 `*.Tests.ps1`；独立子进程场景放 `fixtures/`，不编译进应用 |
| [tools](../tools/) | 构建检查、预览、生成器和启动器 | 当前 EXE 工具在 [launcher](../tools/launcher/README.md)；旧上游工具文本在 [legacy](../tools/legacy/README.md) |
| [lint](../lint/README.md) | 按需使用的 PSScriptAnalyzer 设置 | `settings.psd1` 是配置，不是执行脚本；不代表已接入全仓库 lint 门禁 |
| [mcp](../mcp/README.md) | 独立的 Node.js MCP 包与数据生成 | 保留自己的 package.json 和 lockfile，不与 PowerShell 编译输出混放 |
| [packaging/winget](../packaging/winget/README.md) | WinGet 分发清单历史 | 现有清单按版本归档；本地文件不代表外部仓库审核或上架状态 |
| [.github](../.github/) | GitHub 工作流、Issue 模板和仓库协作规则 | 工作流保留 GitHub 要求的位置；以显示名称、触发条件与说明区分用途 |
| [docs](README.md) | 用户指南、开发参考、图片和站点来源材料 | 当前中文说明入口为仓库 Markdown；站点配置身份与构建方式见该目录说明 |
| [WORKSTATE.md](../WORKSTATE.md) | 当前任务状态、交付证据和后续事项 | 用于恢复工作，不替代用户指南或运行配置 |

## 文档与图片

- [content/userguide](content/userguide/) 面向使用者；[content/dev](content/dev/) 面向维护者，生成参考与手写说明要按各页面标注区分。
- [assets/images/branding](assets/images/branding/) 保存横幅、标识的 SVG 源文件与 PNG 展示文件。
- [assets/images/screenshots](assets/images/screenshots/) 保存当前预览和仍被指南引用的截图；[archive](assets/images/archive/) 保存暂不引用的旧素材。
- 图片引用方式与旧素材用途见[图片资源说明](assets/images/README.md)。移动前检查 README、Hugo image shortcode 和可能的外部直接链接。

## 生成结果与临时文件

根目录的 `winutil.ps1`、`winutil-cn.ps1`、`WinUtil-CN.exe` 是本地生成的启动产物，已被 Git 忽略；它们与受跟踪的 `Compile.ps1` 用途不同。

`.artifacts/` 用于本地工具、验证日志和隔离副本，不是发布源码。MCP 生成数据、node_modules、启动器 bin/obj 也按现有忽略规则管理。不要为了目录整齐把这些结果搬进 `config/` 或 `functions/`。

构建链路的目录变化必须同时核对编译、本地化、测试、启动器、工作流与文档。当前整理保留运行源码路径，优先用职责索引和明确的历史目录减少误用。
