# 图片资源

| 目录 | 用途 |
| --- | --- |
| [branding](branding/) | README 横幅与 Holha1337 标识，保留 SVG 源文件和 PNG 展示文件 |
| [screenshots](screenshots/) | 当前首页、组合预览，以及仍被用户指南引用的界面截图；`install-pics/` 保留原分组 |
| [archive](archive/) | 暂无当前页面引用的旧推广图和旧中文预览，保留历史用途 |

`archive/ad-slot.svg`、`archive/ad-slot.png` 是旧推广素材的源文件与展示文件；`archive/preview-cn.png` 是旧版中文界面预览。它们不作为当前功能的验收证据，也不与新版截图混放。

README 使用相对于仓库根目录的完整图片路径。例如：

```markdown
![首页](docs/assets/images/screenshots/home-cn.png)
```

Hugo 用户指南沿用 image shortcode，路径相对于 `docs/assets/`，不带扩展名。例如：

```text
{{< image src="images/screenshots/home-cn" alt="WinUtil CN 首页" >}}
```

更新截图时同步检查引用页面和说明。旧指南截图只用于界面定位；按钮和恢复行为以当前文字指南与版本为准。移动图片前还应考虑仓库外部可能存在的直接链接。
