# 工作流用途

中文版的正式发布入口是 [release-cn.yaml](workflows/release-cn.yaml)。所有工作流仍保留在 GitHub 要求的位置，通过显示名称与仓库条件区分用途。

| 类别 | 文件 | 触发与作用 |
| --- | --- | --- |
| 正式发布 | [release-cn.yaml](workflows/release-cn.yaml) | main 的相关代码改动或手动触发；测试通过后构建中文 PS1/EXE、分别扫描；未完成扫描则停止，成功时附扫描报告与校验和 |
| 回归 | [unittests.yaml](workflows/unittests.yaml) | main、PR、手动和可复用调用；双 PowerShell 回归及无害夹具启动器测试 |
| 构建检查 | [compile-check.yaml](workflows/compile-check.yaml) | main、PR、手动和可复用调用；中文脚本构建及双版本语法/BOM |
| 仓库整洁 | [remove-winutil.yaml](workflows/remove-winutil.yaml) | push 与 PR；检查生成文件没有入库，仅报告失败，不再自动删文件并提交 |
| MCP 回归 | [mcp-tests.yaml](workflows/mcp-tests.yaml) | MCP 及其数据配置的 main/PR 改动、手动和可复用调用；Windows Node 22 + PowerShell 5.1、Node 24 + PowerShell 7，及 Linux Node 24 协议/执行器夹具测试；干净打包后的离线连接验证 |
| MCP 发布 | [publish-mcp.yaml](workflows/publish-mcp.yaml) | mcp-v* 标签或手动；先通过 MCP 回归，严格核对标签/package/lock 版本；构建并测试唯一 tarball，跨 job 验哈希后发布同一包并核对 npm registry |
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

MCP 与桌面版独立发版。先在 `mcp/package.json` 与 `mcp/package-lock.json` 提交相同版本并合入 main，再推送对应 `mcp-v<版本>` 标签；手动发布只接受 main 或匹配版本的标签，版本输入仅用于校验，不会修改文件。工作流产物 `mcp-npm-release` 保存实际发布包、SHA256、SHA512 integrity、源码提交及版本证据；`mcp-npm-registry-verification` 保存 registry 对照结果。

当前发布沿用 `NPM_TOKEN` secret。npm 已停用旧式 classic/Automation token，需由包所有者维护有发布权限的 granular token，并按包策略启用发布用 bypass 2FA；token 失效或缺失会明确失败。也可由所有者在 npm 配置 [trusted publishing](https://docs.npmjs.com/trusted-publishers/)，配置完成后再调整工作流；不能把 GitHub OIDC 权限本身当作 npm 已授权。详见 [npm 发布双因素认证要求](https://docs.npmjs.com/requiring-2fa-for-package-publishing-and-settings-modification/)。
