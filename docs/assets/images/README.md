# 图片资源

| 目录 | 用途 |
| --- | --- |
| [branding](branding/) | README 横幅与 yesewang1337 标识，保留 SVG 源文件和 PNG 展示文件 |
| [screenshots](screenshots/) | 当前首页、组合预览，以及仍被用户指南引用的界面截图；`install-pics/` 保留原分组 |
| [archive](archive/) | 暂无当前页面引用的推广素材，保留 SVG 与 PNG |

`archive/ad-slot.svg`、`archive/ad-slot.png` 是保留的推广素材源文件与展示文件。带旧署名且无引用的历史中文界面图已移出当前目录，可从 Git 历史查阅；它们不作为当前功能的验收证据。

README 使用相对于仓库根目录的完整图片路径。例如：

```markdown
![首页](docs/assets/images/screenshots/home-cn.png)
```

Hugo 用户指南沿用 image shortcode，路径相对于 `docs/assets/`，不带扩展名。例如：

```text
{{< image src="images/screenshots/home-cn" alt="WinUtil CN 首页" >}}
```

更新截图时同步检查引用页面和说明。旧指南截图只用于界面定位；按钮和恢复行为以当前文字指南与版本为准。移动图片前还应考虑仓库外部可能存在的直接链接。
