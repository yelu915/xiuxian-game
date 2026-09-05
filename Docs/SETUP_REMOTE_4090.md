# 远程 4090 机部署指南（双机协作）

本文档描述如何把一台远程 RTX 4090 Windows 机器接入现有开发环：

```
笔记本（日常开发/Unity 编辑）  --GitHub 仓库 yelu915/xiuxian-game-->  Git
笔记本  --Tailscale 加密内网-->  4090（ComfyUI 素材生产 + Unity 构建/烘焙）
```

> 仓库根目录的一切文件以 Git 为准；`.env.local` 是每台机器各自的本地配置（已被 gitignore）。
> 4090 上无需安装 Unity Hub 依赖的图形桌面即可工作，但建议保留图形会话以便排查。

---

## 〇、最快路径：一键脚本（推荐先试这个）

clone 后直接跑（可自动完成 Git 检测、拉库、LFS、Unity 校验、ComfyUI 产线部署）：
```powershell
cd D:\dev\xiuxian-game
Set-ExecutionPolicy -Scope Process Bypass
.\Tools\Bootstrap-Remote4090.ps1 -InstallComfyUI -DownloadBaseModel
```
需要装 Git 时先加 `-InstallGit`（装完重启 shell 再跑）。脚本结束后仍需按下面小节处理 3 件人工交互项：
Unity Hub 登录激活许可、`tailscale up`、注册 Actions runner。

## 一、4090 机一次性初始化（按顺序执行）

以下小节为逐步手工版本（也可用于排查一键脚本）。在 4090 机上打开 **管理员 PowerShell**，逐节执行。

### 1. 安装 Git for Windows
```powershell
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
# 新开一个 PowerShell 让 PATH 生效，然后：
git --version
git lfs install
```

### 2. 克隆仓库（LFS 大文件一并拉取）
```powershell
mkdir D:\dev; cd D:\dev
git clone https://github.com/yelu915/xiuxian-game.git
cd xiuxian-game
git lfs pull
```
> 若提示需要凭据：用 GitHub 个人访问令牌（PAT，需 `repo` 权限）作密码，或先 `winget install GitHub.cli` 后用 `gh auth login`。

### 3. 安装与项目一致的 Unity 6000.3.22f1
- 方法 A（推荐，图形界面）：装 Unity Hub → 登录 → Installs → Install Editor → Archive 里选 **6000.3.22f1**，勾选 **Windows Build Support (Mono/IL2CPP)**。
- 方法 B（命令行，装到与笔记本一致的位置）：
```powershell
& "$env:LOCALAPPDATA\Programs\Unity Hub\Unity Hub.exe" -- --headless install --version 6000.3.22f1
```
- 完成后确认路径存在，并设置机器级环境变量（以后 Actions 用）：
```powershell
[Environment]::SetEnvironmentVariable('XIANXIA_UNITY_EXE', "$env:LOCALAPPDATA\Unity\Editors\6000.3.22f1\Editor\Unity.exe", 'Machine')
```
- 打开一次项目让许可证激活 / 生成 Library（此后构建会快很多）：
```powershell
& "$env:LOCALAPPDATA\Unity\Editors\6000.3.22f1\Editor\Unity.exe" -batchmode -quit -projectPath D:\dev\xiuxian-game -logFile - | Select-Object -Last 5
```

### 4. 安装 Tailscale 并加入你的网络
```powershell
winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements
tailscale up
```
- 登录你的 Tailscale 账号后，`tailscale ip -4` 会打印 100.x.y.z，记下它（下面称为 `<4090-IP>`）。
- 笔记本上装同样软件并登录同一账号，两台机器即可互通（`ping <4090-IP>`）。

### 5. 部署 AI 素材产线（ComfyUI + 基础模型，哈希锁定）
```powershell
cd D:\dev\xiuxian-game
Set-ExecutionPolicy -Scope Process Bypass
.\Tools\Bootstrap-Workstation.ps1 -InstallComfyUI -DownloadBaseModel
```
该脚本依据 `AI\toolchain.lock.json` / `AI\models.lock.json` 下载官方 ComfyUI Windows 便携包与基础模型并做 SHA256 校验，随后生成本机 `.env.local`。

### 6. 启动 ComfyUI 并开放给 Tailscale 内网
```powershell
cd D:\dev\xiuxian-game
.\Tools\Start-ImageLab.ps1 -ListenAddress <4090-IP>
```
> `-ListenAddress` 必须用 Tailscale IP 而非 `0.0.0.0`，避免暴露到公网物理网卡。默认端口 8190。

### 7. 注册 GitHub Actions 自托管 Runner（做远程构建）
1. 浏览器打开 GitHub 仓库 `yelu915/xiuxian-game` → **Settings → Actions → Runners → New self-hosted runner**，选择 Windows x64，按页面下载并配置。
2. 配置时标签填（务必含 `gpu-4090`）：
   ```
   windows,gpu-4090
   ```
3. 完成后安装为 Windows 服务（脚本会询问），保证开机即跑。

---

## 二、日常使用

### 在笔记本上调用 4090 生图（AI 素材）
```powershell
# 4090 保持 Start-ImageLab 运行；在笔记本的仓库根执行：
.\Tools\Generate-Concept.ps1 -Prompt "你的美术描述" -ApiBaseUrl "http://<4090-IP>:8190"
```
产物 + provenance 落到笔记本的 `ArtSource\AI\Generated`，评审通过后用 `Tools\Approve-GeneratedAsset.ps1` 收编进 LFS。

### 触发 4090 远程出包（三选一）
1. 网页端 GitHub → Actions → Remote Build (4090 self-hosted) → Run workflow；
2. `git push origin main`（代码相关路径变更时自动触发）；
3. 本地跑烘焙任务需先到 Actions 界面手动触发（后续可加 workflow 入口）。

构建产物在 Actions 运行页的 **Artifacts** 下载（`windows-build.zip`）。

### 在 4090 上手动执行同一套任务（排查用）
```powershell
# 出包到 D:\dev\xiuxian-game\Builds\Windows
& "$env:LOCALAPPDATA\Unity\Editors\6000.3.22f1\Editor\Unity.exe" -batchmode -nographics -quit -projectPath D:\dev\xiuxian-game -executeMethod XianxiaRogue.Editor.BuildTools.BuildWindows

# 烘焙 Build Settings 中所有场景（完成后自动退出）
& "$env:LOCALAPPDATA\Unity\Editors\6000.3.22f1\Editor\Unity.exe" -batchmode -nographics -projectPath D:\dev\xiuxian-game -executeMethod XianxiaRogue.Editor.BuildTools.BakeAllEnabledScenes
```

---

## 三、验收清单（全部通过即打通）

| 项目 | 验证方法 |
|---|---|
| 组网 | 笔记本 `ping <4090-IP>` 通 |
| 仓库同步 | 双机 `git status` 与 origin 同步 |
| AI 产线 | 笔记本 `Generate-Concept.ps1` 从 4090 取到图 |
| 远程构建 | Actions 跑通并下载到 windows-build |
| 烘焙 | 4090 手动执行 BakeAllEnabledScenes 无报错 |
