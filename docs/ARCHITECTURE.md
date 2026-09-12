# YAFP architecture

## Purpose

This document describes YAFP's current boundaries and the invariants that must
be preserved when changing or modularizing the project.

## Components

<!-- markdownlint-disable MD013 -->

| Component                     | Responsibility                                         |
| ----------------------------- | ------------------------------------------------------ |
| `yafp-ps1.bash`               | Bash prompt core, context, hooks, and rendering        |
| `yafp-ps.ps1`                 | PowerShell prompt core, context, jobs, and rendering   |
| `themes/*.bash`               | Bash-specific presentation for each theme              |
| `themes/*.ps1`                | PowerShell-specific presentation for each theme        |
| `yafp-cfg.bash.example`       | Bash configuration template                            |
| `yafp-cfg.ps1.example`        | PowerShell configuration template                      |
| `tests/`                      | Logic and integration tests                            |
| `scripts/*/quality/`          | Reproducible validation entry points                   |
| `.github/workflows/ci.yml`    | Automated Linux, macOS, and Windows matrix             |

<!-- markdownlint-enable MD013 -->

## Bash loading flow

1. `yafp-ps1.bash` calculates the root from its own location.
2. It loads the personal `yafp-cfg.bash` configuration.
3. It initializes variables and selects the requested theme, falling back to
   `default`.
4. It builds the theme and registers `PROMPT_COMMAND` and the `DEBUG` trap,
   except in tests using `YAFP_NO_INSTALL_HOOKS=1`.
5. Each prompt collects general, Git, virtual-environment, and previous-command
   context before rendering `PS1`.

The OSC 133 integration uses the `DEBUG` trap to mark the beginning of a
command and `PROMPT_COMMAND` to close the block with its exit code.

## PowerShell loading flow

1. `yafp-ps.ps1` calculates the root from `$MyInvocation`.
2. It loads `yafp-cfg.ps1` when present and applies defaults to the remaining
   options.
3. It imports the requested theme, falling back to `default`.
4. The global `prompt` function captures `$?` and `$LASTEXITCODE` first.
5. It collects context, renders the theme, and restores `$LASTEXITCODE`.

## Git context and remote status

Local context is collected during rendering. Remote queries never run in the
foreground:

- Bash starts a background worker and stores the result inside the actual Git
  directory.
- PowerShell uses a background job and the same conceptual cache format.
- A lock prevents concurrent workers and is removed when it becomes stale.
- The cache is invalidated by its interval, a reference change, or a local
  commit change.
- A successful `push`, `fetch`, or `pull` requests an immediate refresh.

Shared states are checking, refreshing, current, ahead, behind, diverged, and
error.

## Silent prompt degradation

YAFP runs after every command and is part of the basic console interaction. By
design, a failure in optional information—such as history, the remote cache,
or a network job—must not prevent the prompt from rendering or write messages
that mix with user output. In those cases, the application continues with a
fallback value or an error remote state.

Deliberately empty `catch` blocks that implement this policy are exempted from
`PSAvoidUsingEmptyCatchBlock` through a function-scoped
`SuppressMessageAttribute` with a specific `Justification`. The rule is not
excluded globally: failures outside this expected degradation must be handled
normally. The exceptions can be audited with:

```powershell
$settings = './.PSScriptAnalyzerSettings.psd1'
Invoke-ScriptAnalyzer -Path . -Recurse -Settings $settings `
    -SuppressedOnly
```

## Theme contract

Themes receive precomputed context and must not perform Git or network queries.
Each implementation must represent, when applicable:

- user, host, and directory;
- branch and Git changes;
- remote status;
- virtual environment;
- previous command status;
- development metrics.

Adding a theme requires Bash and PowerShell implementations, safe fallback,
and loading tests.

## Integration boundaries

YAFP controls the prompt and its hooks, but not the terminal emulator, ANSI
parser, or scrollback. OSC 133 provides semantic markers; it cannot capture or
draw output blocks by itself.

## Modularization strategy

Future separation must follow verifiable boundaries:

1. Pure utilities and measurement.
2. General context and command status.
3. Local and remote Git context.
4. Shell-specific hook integration.
5. Rendering and themes.

Before moving each boundary, create characterization tests, measure rendering
cost, and compare observable output. Modularization must not add external
processes during every prompt.

## Validation

The canonical entry points are:

```bash
bash scripts/unix/quality/check.bash
```

```powershell
pwsh -NoProfile -File scripts/windows/quality/check.ps1
```

CI runs these same entry points. The `YAFP_REQUIRE_LINTERS=1` variable turns a
missing optional analyzer into an error.

---

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-09-12 17:03:10 🪟 NDEV-DPC-02 |
֎ OpenAI 🤖 Codex 🧠 GPT-5.6 Sol Medium & 👨🏻‍💻 Nelbren ©️ 2026
</div>
