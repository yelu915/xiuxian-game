# V0：AI 协作与本地资产生产工作流

## 目标

V0 要证明这套项目可以被持续生产，而不是证明战斗玩法。完成后，一台新 Windows 主机应能从共享 Git 仓库接入，使用相同的 Unity 基线和 AI Coding 规则，运行隔离的本地图片模型，并把重要结论与任务写入共享 Notion。

## 系统边界

| 内容 | 位置 | 是否共享 |
|---|---|---|
| Unity 工程、代码、工作流、提示词模板、文档 | Git | 是 |
| 审核通过的源图和大型游戏资产 | Git LFS | 是 |
| 研究、设计判断、决策、任务与反馈 | Notion | 是 |
| ComfyUI 运行时、模型权重、缓存、原始批量生成 | 每台主机本地 | 否 |
| `.env.local`、账号授权、访问令牌 | 每台主机本地 | 否 |

## 新主机接入

1. 安装 Git、Git LFS、Unity Hub、Unity `6000.3.22f1` 与 VS Code。
2. 克隆仓库，执行 `git lfs pull`。
3. 在仓库根目录运行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\Bootstrap-Workstation.ps1 -InstallComfyUI
   ```

4. 如果主机没有 SDXL Base，再显式运行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\Bootstrap-Workstation.ps1 -DownloadBaseModel
   ```

   模型约 6.5 GB。脚本完成后会核对 `AI/models.lock.json` 中的 SHA-256。

5. 在 Codex 中信任该仓库；登录并连接当前用户自己的 Notion 工作区。
6. 执行 `Tools/Verify-Workflow.ps1 -Deep`。远端仓库、运行时、模型和工具都显示通过后，这台主机才算接入完成。

## 每日工作流

### AI Coding

1. 从清晰的任务或待验证目标开始。
2. Codex 自动读取根目录 `AGENTS.md`，先检查现有实现再修改。
3. 变更完成后运行对应验证；玩法代码还应补充 EditMode/PlayMode 测试。
4. 查看差异，提交小而完整的 Git commit，再推送共享远端。

### 本地图片生成

1. 启动本地服务：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\Start-ImageLab.ps1
   ```

   项目默认只监听本机 `127.0.0.1:8190`，用于与其他 ComfyUI 实例隔离；实际地址由每台主机自己的 `.env.local` 配置。

2. 在另一个终端发起可复现生成：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\Generate-Concept.ps1 `
     -Prompt "full-body xianxia sword cultivator, 45 degree game concept art" `
     -Seed 20260825
   ```

3. 图片和溯源侧车文件写入 `ArtSource/AI/Generated`，默认不进入 Git。
4. 人工审核后运行 `Tools/Approve-GeneratedAsset.ps1`，把选中结果复制到 `ArtSource/AI/Approved`；该目录使用 Git LFS。
5. 生产导入 Unity 前，还要确认构图、可读性、版权/许可、透明通道和技术规格。

## 模型治理

- 默认运行时版本见 `AI/toolchain.lock.json`；新主机安装锁定版本而不是不稳定的“最新版”。
- 默认模型：Stability AI `sd_xl_base_1.0.safetensors`，准确哈希见 `AI/models.lock.json`。
- 同名但哈希不同视为不同模型，不能混用。
- 第三方微调模型在来源和许可被记录前只允许实验，不得进入生产默认工作流。
- 模型权重不进入 Git；模型 URL、许可 URL、哈希和用途进入锁定清单。

## Git 远端

项目负责人已选择 GitHub 仓库 `https://github.com/yelu915/xiuxian-game`。本地 `origin` 已配置，`main` 已于 2026-08-27 完成首次合并推送并设置上游跟踪。远端原有的 `openclaw-xiuxian-game` 网页原型及其历史提交已完整保留；当前 Unity 工程 README 是仓库主入口。

第二台主机仍需从该地址克隆，运行 `git lfs pull` 和 `Tools/Verify-Workflow.ps1 -Deep`，完成最后一项跨机验收。

## V0 通过标准

- 当前主机能通过脚本启动 ComfyUI，并用锁定模型生成一张带溯源记录的图片。
- 仓库不包含模型权重、令牌、本机绝对路径或未审核的批量生成。
- Git LFS 正常，远端设置完成，第二台主机能克隆并通过深度验证。
- Notion 中存在 V0 专题、执行任务和本地文档入口，重要结论能被持续归档。

## 当前验收状态

截至 2026-08-27，当前 Windows 主机已经完成本地闭环：

- ComfyUI Windows Portable `0.33.1` 已安装到仓库外的隔离目录，并通过 `127.0.0.1:8190` 启动。
- NVIDIA GeForce RTX 5080 Laptop GPU、PyTorch `2.13.0+cu130` 已被运行时正确识别。
- 锁定的 SDXL Base 1.0 模型已核对 SHA-256：`31e35c80fc4829d14f90153f4c74cd59c90b779f6afe05a74cd6120b893f7e5b`。
- `AI/workflows/sdxl_concept_v1.json` 已完成一次 512×512、固定种子 `20260827` 的真实生成。
- 测试图片、模型与工作流哈希全部和溯源侧车文件吻合；原始图片与 `.provenance.json` 均被 Git 忽略。

当前 V0 仍未整体完成：共享 Git `origin` 和首次推送已经通过，第二台主机复验仍待执行。

## 官方参考

- Codex `AGENTS.md`：https://learn.chatgpt.com/docs/agent-configuration/agents-md.md
- Codex 本地环境：https://learn.chatgpt.com/docs/environments/local-environment.md
- Codex 项目配置：https://learn.chatgpt.com/docs/config-file/config-basic.md
- ComfyUI Windows Portable：https://docs.comfy.org/installation/comfyui_portable_windows
- ComfyUI 官方仓库：https://github.com/Comfy-Org/ComfyUI
- SDXL Base 1.0 模型卡：https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0
- SDXL 许可：https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md

资料与本机验收核对时间：2026-08-27。
