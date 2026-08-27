# AI asset pipeline

- `models.lock.json` pins model identity, checksum, source, license, and approval state.
- `toolchain.lock.json` pins the local image runtime version and safe network defaults.
- `workflows` stores ComfyUI API-format workflows that can be submitted without UI state.
- `prompts` stores reusable art-direction constraints and prompt templates.
- `provenance.schema.json` defines the sidecar record produced for each generation.

Raw outputs are written to `ArtSource/AI/Generated` and ignored by Git. Only human-approved outputs and their sidecars are promoted to `ArtSource/AI/Approved`.
