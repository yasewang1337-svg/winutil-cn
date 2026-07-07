---
toc: true
---

## 贡献代码

### 动手之前

- 每个 Pull Request 只聚焦于单个功能或修复。
- 避免不必要的格式改动，或与本次改动无关的大段编辑。
- 在 PR 描述中说明你改了什么、为什么这么改。

---

## 基础 Git 工作流

### 1. Fork 本仓库

打开 GitHub 上的 ChrisTitusTech/winutil 仓库，点击右上角的 Fork 按钮。

<img width="171" height="50" alt="{650A4723-F38A-44A4-9820-D232BC87C8A0}" src="https://github.com/user-attachments/assets/a214f27c-2fee-444a-920f-d87b14f5896f" />

---

### 2. 克隆你的 Fork

```bash
git clone https://github.com/YOUR_USERNAME/winutil.git
cd winutil
```

---

### 3. 创建分支

永远不要直接在 `main` 分支上工作。

创建一个与你的改动相关的分支：

```bash
git checkout -b feature-name
```

示例：

```bash
git checkout -b add-firefox-tweak
```

---

### 4. 修改代码

用你顺手的文本编辑器打开项目，进行修改。

改动要小而聚焦。

---

### 5. 测试你的改动

以管理员身份打开 PowerShell。

进入项目文件夹：

```powershell
cd path\to\winutil
```

运行：

```powershell
.\Compile.ps1 -Run
```

确认：

- WinUtil 能正常启动
- 你的功能能正常工作
- 没有弄坏其他东西

如果哪里出错，先修好再提交。

---

### 6. 检查你的改动

看看改了哪些内容：

```bash
git status
```

查看差异：

```bash
git diff
```

确认你没有不小心改到无关的文件。

---

### 7. 提交你的改动

暂存文件：

```bash
git add .
```

提交：

```bash
git commit -m "Add feature description"
```

示例：

```bash
git commit -m "Add Firefox package tweak"
```

---

### 8. 推送你的分支

```bash
git push origin branch-name
```

示例：

```bash
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
