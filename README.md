# XianxiaRogue

暂定代号：`XianxiaRogue`。

这是一个使用 Unity 制作的俯视角修仙动作探索项目。首轮已确认以单机方式验证；设计方向是 Rogue 局内成长、夸张敌群与强视觉演出。“类似《哈迪斯》的视角与表现方式”目前只作为体验参考，不代表美术或玩法已经定案。

当前 V0 不是战斗 DEMO，而是生产工作流基线：让 AI Coding、本地图片生成、Git 跨主机协作和 Notion 文档沉淀先完整跑通。通过 V0 后，再进入 Prototype 0 战斗手感样片。

当前主机已经完成 AI Coding 配置、本地 SDXL 真实出图和溯源校验，共享 GitHub 远端已经建立；剩余 V0 验收项是第二台主机复验。

## 技术基线

- Unity `6000.3.22f1`（Unity 6.3 LTS）
- Universal Render Pipeline `17.0.4`
- Input System `1.14.2`
- AI Navigation `2.0.9`
- Cinemachine `3.1.7`
- Visual Effect Graph `17.0.4`
- Windows 桌面为首轮原型目标

## 打开项目

1. 启动 Unity Hub。
2. 选择“添加/从磁盘添加项目”。
3. 选择本目录 `Game`。
4. 使用 Unity `6000.3.22f1` 打开。

首次打开会解析新增包并生成本机缓存。Unity 账号与 Personal 许可证激活必须由账号持有人在 Hub 中完成。

## 新主机接入

1. 克隆仓库并拉取 Git LFS 文件。
2. 在 PowerShell 中运行 `Tools/Bootstrap-Workstation.ps1`；需要安装独立的本地图片运行时，再加参数 `-InstallComfyUI`。
3. 把 `.env.example` 复制为 `.env.local`，或让引导脚本生成；只填写本机路径，不提交该文件。
4. 运行 `Tools/Verify-Workflow.ps1 -Deep`。
5. 在 Codex 中信任该仓库，使根目录的 `AGENTS.md` 与 `.codex/config.toml` 生效；Notion 登录授权仍需每台主机分别完成。

详细说明见 `Docs/WORKFLOW_V0.md`。

## 目录约定

- `Assets/_Game`：项目自有内容。
- `Assets/Settings`：URP 与渲染设置。
- `Assets/Scenes`：模板场景；后续原型场景迁入 `_Game`。
- `Assets/ThirdParty`：未来引入的第三方资源，禁止与自有代码混放。
- `Docs`：技术基线、决策与验证记录。
- `AI`：模型清单、提示词规范与可复现工作流。
- `ArtSource/AI/Generated`：本机临时生成目录，不进入 Git。
- `ArtSource/AI/Approved`：审核通过、带溯源信息的共享源图，使用 Git LFS。

## 设计文档

- `Docs/GAME_DESIGN_FRAMEWORK.md`：产品定位、三层循环、首轮战斗、掉落、洞府与 DEMO 推进框架。
- `Docs/TECHNICAL_BASELINE.md`：Unity、渲染、包、目录与版本控制基线。
- `Docs/WORKFLOW_V0.md`：AI Coding、本地生图、跨主机与共享文档的 V0 工作方式。
- `Docs/NOTION_SYNC.md`：本地文档与 Notion 的分工及归档入口。

## 历史原型

- `index.html`：GitHub 远端原有的 `openclaw-xiuxian-game` 单页网页原型，合并时原样保留，作为早期方向参考；它不是当前 Unity 工程的运行入口或技术基线。

## 本地验证

在 PowerShell 中运行 `Tools/Verify-Environment.ps1` 检查 Unity 开发环境；运行 `Tools/Verify-Workflow.ps1 -Deep` 检查完整 V0 工作流。

当前 Unity 编辑器已经包含 Windows Mono 构建支持。Windows IL2CPP 安装器需要一次管理员确认，暂不阻塞编辑器运行、脚本编译与原型开发。
