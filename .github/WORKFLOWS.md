# 工作流用途

中文版的正式发布入口是 [release-cn.yaml](workflows/release-cn.yaml)。所有工作流仍保留在 GitHub 要求的位置，通过显示名称与仓库条件区分用途。

| 类别 | 文件 | 触发与作用 |
| --- | --- | --- |
| 正式发布 | [release-cn.yaml](workflows/release-cn.yaml) | main 的相关代码改动或手动触发；测试通过后构建中文 PS1/EXE、分别扫描；未完成扫描则停止，成功时附扫描报告与校验和 |
| 回归 | [unittests.yaml](workflows/unittests.yaml) | main、PR、手动和可复用调用；双 PowerShell 回归及无害夹具启动器测试 |
| 构建检查 | [compile-check.yaml](workflows/compile-check.yaml) | main、PR、手动和可复用调用；中文脚本构建及双版本语法/BOM |
| 仓库整洁 | [remove-winutil.yaml](workflows/remove-winutil.yaml) | push 与 PR；检查生成文件没有入库，仅报告失败，不再自动删文件并提交 |
| MCP 回归 | [mcp-tests.yaml](workflows/mcp-tests.yaml) | MCP 及其数据配置的 main/PR 改动、手动和可复用调用；Windows Node 22 + PowerShell 5.1、Node 24 + PowerShell 7，及 Linux Node 24 协议/执行器夹具测试；干净打包后的离线连接验证 |
| MCP 实际修改验证 | [mcp-integration.yaml](workflows/mcp-integration.yaml) | PR 相关改动或手动；三台 GitHub 托管一次性 Windows 测试机分别验证注册表/服务、DNS、包源/安装的实际修改与恢复，失败证据也保留；禁止在日常电脑或自托管 runner 上运行，见 [测试范围](../mcp/test/integration/README.md) |
| MCP 发布包 | [publish-mcp.yaml](workflows/publish-mcp.yaml) | mcp-v* 标签或手动；先通过 MCP 回归和一次性 Windows 实际修改测试，再构建并测试唯一 tarball。默认只生成安装包；手动明确勾选 publish_npm 才上传 npm，跨 job 验哈希并核对 registry |
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

MCP 与桌面版独立发版。先在 `mcp/package.json` 与 `mcp/package-lock.json` 提交相同版本并合入 main，再推送对应 `mcp-v<版本>` 标签；手动发布只接受 main 或匹配版本的标签，版本输入仅用于校验，不会修改文件。工作流产物 `mcp-npm-release` 保存可用于 GitHub Release 的实际安装包、SHA256、SHA512 integrity、源码提交及版本证据。标签默认只构建，不尝试 npm 上传；npm 授权完成后由维护者手动勾选 `publish_npm`，启用时另有 `mcp-npm-registry-verification` 保存 registry 对照结果。

发布使用 npm [trusted publishing](https://docs.npmjs.com/trusted-publishers/) 的短期 OIDC 凭据，不再读取 `NPM_TOKEN`。包所有者须在 npm 的 Settings → Trusted Publisher 配置 GitHub 用户 `yasewang1337-svg`、仓库 `winutil-cn`、工作流文件名 `publish-mcp.yaml`，环境留空，并允许 `npm publish`；不需要额外授权管理 dist-tags。发布 job 使用 GitHub 托管 runner、Node 24、npm ≥11.5.1 和 `id-token: write`，自动附带来源证明。工作流不会替所有者修改 npm 账号或包权限，未建立信任时上传仍会失败。

补发已经测试并保留的原包时，在 main 手动填写同版本及 `existing_run_id`（最初成功的 `mcp-v<版本>` 标签构建运行 ID），再按需要勾选 `publish_npm`。流程核对原运行所属仓库、工作流、标签、源码提交和成功结果，从该运行下载 `mcp-npm-release`，验证 SHA256/SHA512、原版本证据与离线 MCP 入口，然后上传同一份 tarball；不重新打包。当前源码的包版本及数据必须仍与原包匹配。原构建附件过期、版本或哈希不符都会停止，不会回退为重新构建同版本。留空 `existing_run_id` 时仍执行完整回归与实际修改/恢复测试，再构建新包。

npm 接受上传后可能仍需几分钟处理。上传后的 registry 校验对临时 E404 每 15 秒重试，最多 21 次查询；其他认证错误、无效响应或 integrity 不一致立即失败。超时不自动再次上传，维护者应先检查该版本是否已经可用；已存在且 integrity 相同的版本会跳过重复发布。
