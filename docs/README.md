# 中文文档网站

正式入口：[WinUtil CN 中文网站](https://yasewang1337-svg.github.io/winutil-cn/)。网站与仓库文档使用同一份源码，用户从[快速上手](content/userguide/getting-started/_index.md)开始，MCP 用户从[接入指南](content/mcp/_index.md)开始。维护项目请先读[仓库结构](REPOSITORY.md)与[维护说明](MAINTENANCE.md)。

## 发布与预览

站点部署到本仓库的 GitHub Pages，正式地址为 `https://yasewang1337-svg.github.io/winutil-cn/`，保留 `/winutil-cn/` 子路径。GitHub Pages 采用 GitHub Actions 构建产物，工作流与检查入口见[工作流说明](../.github/workflows/README.md)。只有完成构建和链接验证的站点产物才用于部署；分支预览检查不会发布。

安装与工作流一致的 Hugo 和 Go 后，在 `docs` 目录执行 `hugo server` 预览。生产构建使用 `hugo --environment production --minify`；本地预览服务器的地址可能不同于正式域名。主题版本固定在 `go.mod` / `go.sum`，不要在发布时临时跟随主题主分支。

导航、资源、canonical 和 sitemap 都需保留项目子路径。`robots.txt` 由 Hugo 生成，并指向正式站点的 sitemap；项目站位于域名子路径，不能代替 `github.io` 域名根路径的抓取规则。上线不代表搜索引擎或 AI 已收录、引用或推荐。

首页及帮助页使用当前软件截图、实际支持范围和本仓库反馈入口；不添加虚构用户数、评分或推荐背书。网页没有接入第三方统计或追踪脚本。

## 文件位置

| 位置 | 用途 |
| --- | --- |
| `content/_index.md`、`layouts/shortcodes/product-home.html` | 产品首页：下载、上手、MCP 与来源说明 |
| `content/userguide` | 当前中文使用指南，与实际界面和支持范围一起更新 |
| `content/mcp` | npm 安装、查询、写操作边界与恢复指南；随 MCP 版本同步 |
| `content/faq.md`、`content/KnownIssues.md` | 当前常见问题及已知边界 |
| `content/dev/architecture.md` | 架构参考 |
| `content/dev/tweaks`、`content/dev/features` | 配置与函数生成的项目参考；`_index.md` 为手写导航 |
| `assets/css/custom.css` | 首页响应式样式与中文阅读字体 |
| `assets/js/core/search-input.js` | 补齐搜索框粘贴、触屏及中文输入提交；复用固定主题的搜索索引与键盘导航 |
| `assets/images/screenshots` | 实际软件截图；改名时同步 README、首页及 image shortcode |
| `assets/images/branding`、`assets/images/archive` | 项目素材与仍需保留的历史图片；不把历史图作为当前界面证据 |
| `hugo.toml`、`layouts`、`static`、`go.mod` / `go.sum` | Hugo 配置、模板、站点资源与固定主题依赖 |
| `MAINTENANCE.md`、`SECURITY.md` | 维护流程与发布安全说明 |

站点导航和 favicon 复用 `tools/launcher/icon.svg` / `icon.ico` 的桌面图标。图标更新时同步 `static/favicon.svg` / `favicon.ico`；旧上游素材保留在资源目录，但不用于当前导航和网页图标。

## 刷新开发参考

从仓库根目录执行：

```powershell
pwsh -NoProfile -File tools/devdocs-generator.ps1
```

生成器使用 `tools/devdocs-routes.json` 中的稳定项目 ID 和路径映射，保留既有页面 URL；只读取 config，不写回运行时链接。生成失败保留已有页面，手写导航和映射之外的页面不被清理。细节见[生成器说明](../tools/devdocs-generator.md)。开发参考中的配置示例保留真实源码内容，不应把代码块内的上游 `link` 字段当成网站导航。

## 来源

站点结构源自 ChrisTitusTech/winutil，主题为 Hextra；中文维护和发布由本仓库负责。旧上游域名的 CNAME 已归档为 `tools/legacy/upstream-docs-CNAME.txt`，不会随中文站点发布。版本交付记录见根目录 [WORKSTATE.md](../WORKSTATE.md) 及 Git 历史。
