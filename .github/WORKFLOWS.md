# 工作流用途

中文版的正式发布入口是 [release-cn.yaml](workflows/release-cn.yaml)。所有工作流仍保留在 GitHub 要求的位置，通过显示名称与仓库条件区分用途。

| 类别 | 文件 | 触发与作用 |
| --- | --- | --- |
| 正式发布 | [release-cn.yaml](workflows/release-cn.yaml) | main 的相关代码改动或手动触发；测试通过后构建中文 PS1/EXE、分别扫描；未完成扫描则停止，成功时附扫描报告与校验和 |
| 回归 | [unittests.yaml](workflows/unittests.yaml) | main、PR、手动和可复用调用；双 PowerShell 回归及无害夹具启动器测试 |
| 构建检查 | [compile-check.yaml](workflows/compile-check.yaml) | main、PR、手动和可复用调用；中文脚本构建及双版本语法/BOM |
| 仓库整洁 | [remove-winutil.yaml](workflows/remove-winutil.yaml) | push 与 PR；检查生成文件没有入库，仅报告失败，不再自动删文件并提交 |
| MCP 发布 | [publish-mcp.yaml](workflows/publish-mcp.yaml) | mcp-v* 标签或手动；单独构建发布 Node 包，需要 NPM_TOKEN |
| PR 标签 | [label-pr.yaml](workflows/label-pr.yaml) | 读取 PR 中选中的变更类型并添加标签 |
| Issue 管理 | [issue-slash-commands.yaml](workflows/issue-slash-commands.yaml) | 仅仓库所有者评论中的管理命令生效 |
| Issue 活跃状态 | [close-old-issues.yaml](workflows/close-old-issues.yaml) | 每日或手动；90 天无活动标记，标记后 365 天无活动关闭；Keep Issue Open 豁免，PR 不处理 |
| 上游保留 | [pre-release.yaml](workflows/pre-release.yaml) | 旧预发布、签名相关配置及草稿说明链；仅 ChrisTitusTech/winutil 可运行，中文分支不使用 |
| 上游保留 | [docs.yaml](workflows/docs.yaml) | 上游 Hugo Pages；中文分支不部署网站 |
| 上游保留 | [sponsors.yaml](workflows/sponsors.yaml) | 上游赞助名单更新；定时及手动均限制为上游仓库 |
| 上游保留 | [auto-merge-docs.yaml](workflows/auto-merge-docs.yaml) | 上游 docs-update 自动合并；中文文档按普通 PR 检查合并 |
| 上游保留 | [close-discussion-on-pr.yaml](workflows/close-discussion-on-pr.yaml) | 上游 Discussions 关闭流程；中文仓库不运行 |

[release-drafter.yml](release-drafter.yml) 只服务旧上游预发布入口。保留这些文件便于比较上游历史，不表示已完成上游迁移；不要绕过中文版发布的测试门禁启用旧发布入口。

令牌值保存在 GitHub Secrets 或本机凭据存储中，文档只记录用途，不保存凭据。未来需要中文网站时，应单独配置实际站点地址和部署流程。
