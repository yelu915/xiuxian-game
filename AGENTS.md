# XianxiaRogue repository instructions

## Product phase

- The confirmed first phase is single-player.
- V0 is the reproducible production workflow: AI-assisted coding, local image generation, cross-machine Git usage, and Notion knowledge/task capture.
- Do not expand into multiplayer, market/economy, open world, or large content production unless the user explicitly changes scope.
- Prototype 0 combat work begins after the V0 workflow checks pass.

## Repository rules

- Unity version is pinned by `ProjectSettings/ProjectVersion.txt`; do not upgrade it implicitly.
- Put project-owned runtime content under `Assets/_Game` and third-party content under `Assets/ThirdParty`.
- Preserve Unity `.meta` files and use text serialization. Never hand-edit generated `Library`, `Temp`, `Logs`, `Obj`, or IDE project files.
- Run `Tools/Verify-Environment.ps1` after Unity/package changes and `Tools/Verify-Workflow.ps1` after workflow/tooling changes.
- Keep code, small configuration, documentation, workflows, prompt templates, and provenance records in Git.
- Keep secrets, machine paths, local runtimes, model weights, caches, and raw AI generations out of Git.
- Store approved large binary assets through Git LFS.

## AI-generated art

- The default approved checkpoint is the exact SDXL Base entry in `AI/models.lock.json`.
- Do not use a model whose source or license is unresolved for production assets.
- Every approved generation must retain model hash, workflow hash, prompt, negative prompt, seed, settings, time, and source filename.
- Raw outputs belong in `ArtSource/AI/Generated`; only explicit human approval promotes a file to `ArtSource/AI/Approved`.
- Treat generated images as source material requiring art direction and review, not automatically final game assets.

## Documentation and Notion

- Code-adjacent truth lives in versioned Markdown under `Docs`.
- Reusable research, decisions, milestones, and actionable work also belong in the shared Notion workspace.
- Distinguish facts, analysis, design hypotheses, confirmed decisions, items to validate, and rejected options.
- Never store Notion tokens or other credentials in this repository. Connector authentication is per user and per workstation.
- Do not silently mark design hypotheses as confirmed or overwrite an existing confirmed decision.

## Change discipline

- Prefer small, reviewable changes and preserve unrelated user work.
- Add or update tests when runtime behavior changes.
- Document new tools, external dependencies, model licenses, and workstation prerequisites before making them part of the baseline.
