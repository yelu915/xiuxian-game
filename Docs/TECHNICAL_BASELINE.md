# 技术基线（2026-08-24）

## 已确认事实

- 开发机为 Windows x64，磁盘空间充足。
- 图形硬件包含 NVIDIA GeForce RTX 5080 Laptop GPU 与 AMD Radeon 890M。
- Unity Hub `3.21.0`、Unity CLI `1.0.0-beta.6`、Unity `6000.3.22f1` 和 VS Code `1.134.0` 已安装。
- VS Code 已安装微软官方 Unity 扩展、C# Dev Kit、C# 扩展和 .NET Runtime 扩展。
- Unity 项目启用 Visible Meta Files 与 Force Text 序列化。

## 当前技术选择

- 使用 Unity 6.3 LTS，降低长期维护与包兼容风险。
- 使用 URP，在夸张战斗演出、PC 性能和未来多平台可能性之间保持弹性。
- 输入、寻路、相机与特效分别采用 Input System、AI Navigation、Cinemachine、VFX Graph。
- 使用 Git + Git LFS；Unity YAML 资源使用 UnityYAMLMerge。
- 自有运行时代码、编辑器代码和测试使用独立程序集。
- 首轮产品验证为单机模式；联网、同步和多人架构不进入 V0 与 Prototype 0。
- 本地图片生产以隔离的 ComfyUI Portable + 已锁定 SDXL 模型为基线，运行时与模型权重不提交 Git。
- Git 保存代码、配置、可复现工作流和审核通过的资产；Notion 保存跨职能可读的研究、决策和任务。

## V0 生产工作流基线

- Codex 通过仓库根目录 `AGENTS.md` 获得稳定约束，通过 `.codex/config.toml` 获得安全的项目默认值。
- 每台主机只需要配置 `.env.local` 中的本机路径；该文件不会提交。
- 本地图片必须能追溯到模型 SHA-256、工作流版本、提示词、参数和种子。
- 原始批量生成不进入 Git；明确审核通过的源图进入 `ArtSource/AI/Approved` 并由 Git LFS 管理。
- Notion 连接属于个人/主机授权，不把访问令牌写进仓库。

## 设计假设（待验证）

- 俯视角 3D 战斗能同时承载高机动近战、弹幕与大体量敌群。
- 修仙题材的境界/功法/法宝可映射为 Rogue 局内构筑，但具体成长层级尚未定案。
- 第一版垂直切片应优先验证移动、攻击命中感、镜头冲击、敌群压力与局内三选一成长。

## 暂未定案

- 最终产品是否扩展多人；首轮单机已经确认。
- 长线经济、局外成长与商业化形式。
- 写实、国风动画或其他具体美术风格。
- 最终产品名与世界观设定。

## 已知待办

- 在 Unity Hub 登录并激活 Unity Personal 许可证。
- 如需正式 IL2CPP Windows 包，使用管理员权限为 `6000.3.22f1` 添加 Windows Build Support (IL2CPP)。
- 首次打开工程后提交 Unity 生成的 `Packages/packages-lock.json` 与 `.meta` 文件。
- 为项目选择 Git 远端托管方并设置 `origin`，这是第二台主机真正接入前唯一需要人工选择的仓库项。
