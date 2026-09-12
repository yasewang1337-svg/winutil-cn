## 贡献代码

### 动手之前

- 每个 Pull Request 只聚焦于单个功能或修复。
- 避免不必要的格式改动，或与本次改动无关的大段编辑。
- 在 PR 描述中说明你改了什么、为什么这么改。

---

## 基础 Git 工作流

### 1. Fork 本仓库

打开 [WinUtil CN 仓库](https://github.com/yasewang1337-svg/winutil-cn)，点击右上角的 Fork 按钮。中文版的翻译与功能改进请提交到本仓库。

<img width="171" height="50" alt="{650A4723-F38A-44A4-9820-D232BC87C8A0}" src="https://github.com/user-attachments/assets/a214f27c-2fee-444a-920f-d87b14f5896f" />

---

### 2. 克隆你的 Fork

```powershell
git clone https://github.com/YOUR_USERNAME/winutil-cn.git
cd winutil-cn
```

---

### 3. 创建分支

永远不要直接在 `main` 分支上工作。

创建一个与你的改动相关的分支：

```powershell
git checkout -b feature-name
```

示例：

```powershell
git checkout -b add-firefox-tweak
```

---

### 4. 修改代码

用你顺手的文本编辑器打开项目，进行修改。

改动要小而聚焦。

---

### 5. 测试你的改动

使用 PowerShell 7（`pwsh`）构建中文版。仅构建和隔离测试无需启动应用或修改系统。

进入项目文件夹：

```powershell
cd path\to\winutil-cn
```

运行：

```powershell
pwsh -File 汉化\run-all.ps1
pwsh -File tools\Test-Build.ps1
powershell -NoProfile -File tools\Test-Build.ps1
```

功能变更需按影响运行回归测试（Pester 5.7.1），参见 `tools/Invoke-Tests.ps1`。界面与行为变更还应在合适的测试环境中确认：

- WinUtil 能正常启动
- 你的功能能正常工作
- 没有弄坏其他东西

如果哪里出错，先修好再提交。

---

### 6. 检查你的改动

看看改了哪些内容：

```powershell
git status
```

查看差异：

```powershell
git diff
```

确认你没有不小心改到无关的文件。

---

### 7. 提交你的改动

暂存文件：

```powershell
git add .
```

提交：

```powershell
git commit -m "Add feature description"
```

示例：

```powershell
git commit -m "Add Firefox package tweak"
```

---

### 8. 推送你的分支

```powershell
git push origin branch-name
```

示例：

```powershell
git push origin add-firefox-tweak
```

---

### 9. 发起 Pull Request

打开 GitHub 上你的 Fork。

GitHub 会显示一个创建 Pull Request 的按钮。
<img width="1009" height="71" alt="{C8C6A3CC-79D4-44FD-A54C-4C5717F12730}" src="https://github.com/user-attachments/assets/0419d193-d4e7-47c0-87cf-b986742201a0" />

提交之前：

- 说明你改了什么
- 说明你为什么改
- 确认没有把无关文件一起提交进来

提交之后，维护者会审阅你的 PR。
