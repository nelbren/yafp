# Instructions for agents in YAFP

## Project scope

YAFP implements equivalent prompts for Bash, zsh, and PowerShell. Before changing
the repository, review `README.md`, `docs/ARCHITECTURE.md`, and the global
documentation base for the current operating system.

The actual implementation takes precedence over outdated documentation. When
a difference is found, correct the documentation as part of the same change.

## Supported platforms

- Bash on Linux, macOS, WSL2, and Git Bash.
- zsh 5.9 or later on Linux and macOS.
- PowerShell 7 on Windows.
- Git as an optional dependency for repository sections.

Do not assume support for fish or Windows PowerShell 5.1 without a
specific implementation and tests.

## Prompt invariants

- Prompt rendering must remain fast and must not block on network operations.
- Remote checks must run in the background without interactive credential
  prompts.
- The previous command status and its exit code must be preserved.
- Integration with `PROMPT_COMMAND`, the `DEBUG` trap, zsh hooks, and OSC 133
  must not emit visible sequences or run a command twice.
- Loading YAFP more than once must not accumulate hooks, jobs, or output.
- A repository without an upstream, in detached HEAD, or inside a worktree
  must degrade without visible errors.
- The `default`, `minimal`, and `light` themes must preserve the same semantics
  in Bash, zsh, and PowerShell, even when their presentation differs.

## Change organization

- Keep configuration, context collection, shell integration, and rendering
  separate.
- Avoid adding external processes to paths that run on every render.
- Do not modularize `yafp-ps1.bash` or `yafp-ps.ps1` without characterization
  tests for the behavior being moved.
- A behavior change must include tests and documentation in the same delivery.
- A theme change must review the Bash, zsh, and PowerShell implementations.
- Personal configurations live in `yafp-cfg.bash`, `yafp-cfg.zsh`, and
  `yafp-cfg.ps1`; only their `.example` files are versioned.

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

## Commit messages and versioning

Every commit must advance the YAFP version. Read `YAFP_VERSION` from
`yafp-ps1.bash` at `HEAD` and choose the highest level required by the
changes included in the commit.

- **Major** (`X.Y.Z → (X+1).0.0`) for changes that break compatibility
  with existing commands, configuration, or supported shell behavior.
- **Minor** (`X.Y.Z → X.(Y+1).0`) for backward-compatible features.
- **Patch** (`X.Y.Z → X.Y.(Z+1)`) for fixes, documentation, tests,
  refactoring, or maintenance without a new feature or breaking change.

Whenever proposing a commit message, include the suggested numeric version
alongside it and briefly explain the level chosen. A message-only request
requires only the proposal.

When creating the commit, stage the same version in the Bash and zsh
`YAFP_VERSION` declarations, the PowerShell version header in `yafp-ps.ps1`,
and the version badge in `README.md`. Before committing, verify that all four
staged values match the proposed version.

## Delivery

- Keep the tree free of temporary files and remote-state caches.
- Do not modify ignored personal configurations.
- Preserve the `Origin-Device` trailer in new commits when the local
  `ai-dev-tools` policy is enabled.
- Report which validations were run and any unavailable tools.

---

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-11-03 20:54:35 🍎 MBP02 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 Not exposed & 👨🏻‍💻 Nelbren ©️ 2026
</div>
