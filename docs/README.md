# 文档目录

使用工具从[快速上手](content/userguide/getting-started/_index.md)开始；维护项目从[仓库结构](REPOSITORY.md)和[维护说明](MAINTENANCE.md)开始。当前正式入口是 GitHub 中的 Markdown 指南，并未部署独立中文站点。

| 位置 | 用途 | 编辑方式 |
| --- | --- | --- |
| content/userguide | 当前中文使用指南 | 人工维护，与实际界面、操作结果和支持范围一起更新 |
| content/dev/architecture.md | 架构参考 | 人工维护 |
| content/dev/tweaks、content/dev/features | 从当前配置及函数生成的项目参考 | 修改配置/路由后运行生成器；_index.md 为手写导航 |
| assets/images/branding | 项目标识与仓库横幅 | 保留 SVG 源文件与 PNG 展示文件 |
| assets/images/screenshots | 当前或仍被引用的界面截图 | 改名时同步 README 与 image shortcode |
| assets/images/archive | 未被当前文档引用的历史图片 | 保留来源，不作为当前界面的证据 |
| hugo.toml、layouts、static、go.mod/go.sum | Hugo 本地预览配置与资源 | 当前为中文预览配置，baseURL 为相对根路径 |
| MAINTENANCE.md | 构建、测试、发布及上游迁移边界 | 维护者更新 |

## 刷新开发参考

从仓库根目录执行：

```powershell
pwsh -NoProfile -File tools/devdocs-generator.ps1
```

生成器使用 `tools/devdocs-routes.json` 中的稳定项目 ID 和路径映射，保留既有页面 URL；只读取 config，不写回运行时链接。生成失败保留已有页面，手写导航和映射之外的页面不被清理。细节见[生成器说明](../tools/devdocs-generator.md)。

## 预览与站点状态

在安装 Hugo 和 Go 的开发环境中，从 docs 目录运行 `hugo server` 可预览。仓库仍保留上游 Hugo workflow 用于对照，但其 job 已限制为上游仓库，中文版不会自动部署。

上游域名的旧 CNAME 已归档为 `tools/legacy/upstream-docs-CNAME.txt`，不会随中文站点静态目录发布。未来上线中文站点时，应另行确定域名、baseURL 和部署权限。当前没有为用户创建或修改任何托管站点。

## 来源

站点结构源自 ChrisTitusTech/winutil；中文维护与正式发布由本仓库提供。仓库已记录的历史交付见根目录 [WORKSTATE.md](../WORKSTATE.md) 及 Git 历史。
