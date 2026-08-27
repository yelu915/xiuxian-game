# Codex project configuration

`AGENTS.md` contains the durable project instructions. This folder contains only safe defaults that can be shared across machines.

After cloning, trust the repository in Codex so the project configuration is loaded. Keep account-specific settings, credentials, provider keys, and Notion authentication in the user's local Codex/ChatGPT configuration rather than this repository.

Codex desktop can generate shared local-environment setup scripts and actions in this folder. Until that UI configuration is committed, use the repository-owned PowerShell commands:

- `Tools/Bootstrap-Workstation.ps1`
- `Tools/Verify-Workflow.ps1`
- `Tools/Start-ImageLab.ps1`
- `Tools/Generate-Concept.ps1`
