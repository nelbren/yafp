# Instructions for agents in YAFP

## Project scope

YAFP implements equivalent prompts for Bash and PowerShell. Before changing
the repository, review `README.md`, `docs/ARCHITECTURE.md`, and the global
documentation base for the current operating system.

The actual implementation takes precedence over outdated documentation. When
a difference is found, correct the documentation as part of the same change.

## Supported platforms

- Bash on Linux, macOS, WSL2, and Git Bash.
- PowerShell 7 on Windows.
- Git as an optional dependency for repository sections.

Do not assume support for zsh, fish, or Windows PowerShell 5.1 without a
specific implementation and tests.

## Prompt invariants

- Prompt rendering must remain fast and must not block on network operations.
- Remote checks must run in the background without interactive credential
  prompts.
- The previous command status and its exit code must be preserved.
- Integration with `PROMPT_COMMAND`, the `DEBUG` trap, and OSC 133 must not
  emit visible sequences or run a command twice.
- Loading YAFP more than once must not accumulate hooks, jobs, or output.
- A repository without an upstream, in detached HEAD, or inside a worktree
  must degrade without visible errors.
- The `default`, `minimal`, and `light` themes must preserve the same semantics
  in Bash and PowerShell, even when their presentation differs.

## Change organization

- Keep configuration, context collection, shell integration, and rendering
  separate.
- Avoid adding external processes to paths that run on every render.
- Do not modularize `yafp-ps1.bash` or `yafp-ps.ps1` without characterization
  tests for the behavior being moved.
- A behavior change must include tests and documentation in the same delivery.
- A theme change must review both the Bash and PowerShell implementations.
- Personal configurations live in `yafp-cfg.bash` and `yafp-cfg.ps1`; only
  their `.example` files are versioned.

## Required validation

On Unix or inside a complete Bash session:

```bash
bash scripts/unix/quality/check.bash
```

On Windows:

```powershell
pwsh -NoProfile -File scripts/windows/quality/check.ps1
```

On PowerShell for Windows, some Bash shims do not initialize Unix tools when
invoked directly. To run Bash validation from PowerShell, use:

```powershell
bash -lc 'cd /c/PATH/YAFP && bash scripts/unix/quality/check.bash'
```

The scripts run the tests and use `shellcheck`, PSScriptAnalyzer, and
`markdownlint` when installed. CI requires the analyzers through
`YAFP_REQUIRE_LINTERS=1`.

## Delivery

- Keep the tree free of temporary files and remote-state caches.
- Do not modify ignored personal configurations.
- Preserve the `Origin-Device` trailer in new commits when the local
  `ai-dev-tools` policy is enabled.
- Report which validations were run and any unavailable tools.

---

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-09-12 17:03:10 🪟 NDEV-DPC-02 |
֎ OpenAI 🤖 Codex 🧠 GPT-5.6 Sol Medium & 👨🏻‍💻 Nelbren ©️ 2026
</div>
