# :computer: Yet Another Fancy Prompt

[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/) [![made-with-powershell](https://img.shields.io/badge/Made%20with-PowerShell-5391FE.svg?logo=powershell)](https://docs.microsoft.com/powershell/) ![version](https://img.shields.io/badge/version-0.3.1-green) ![themes](https://img.shields.io/badge/themes-8A2BE2?logo=educative)

## :soon: Insert here the most beautiful screenshots

### :apple: macOS

![macOS](images/screenshot_macOS.png)

### :window: [Cygwin](https://www.cygwin.com/)

![Cygwin](images/screenshot_Cygwin.png)

### :window: [Git Bash](https://git-scm.com/download/win)

![GitBash](images/screenshot_GitBash.png)

### :penguin: Linux

![Linux](images/screenshot_Linux.png)

### :window: [PowerShell](https://learn.microsoft.com/es-es/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)

![PowerShell](images/screenshot_PowerShell.png)

---

## :art: Styles

### :bulb: Colors change according to

#### :computer: Server type

- ##### :green_book: **Developer**

- ##### :closed_book: **Production**

#### :bust_in_silhouette: User type

- ##### :necktie: root (**`#`**)

- ##### :tshirt: normal user (**`$`**)

---

## I. :floppy_disk: Acquire

### 👤 Local acquire

#### ⌨ Commands to acquire local

```bash
cd
git clone https://github.com/nelbren/yafp.git
```

#### 👁️ Example of acquire local

![screenshot_macOS_Acquire_Local](images/screenshot_macOS_Acquire_Local.png)

### 🌐 Global acquire

#### ⌨ Commands to acquire globally

```bash
sudo su -
cd /usr/local
git clone https://github.com/nelbren/yafp.git
```

#### 👁️ Example of acquire globally

![screenshot_macOS_Acquire_Global](images/screenshot_macOS_Acquire_Global.png)

## II :gear: Configure

### 👤 Local settings

#### ⌨ Commands to configure locally

```bash
cd ~/yafp
cp yafp-cfg.bash.example yafp-cfg.bash
```

#### 👁️ Example of local configuration

![screenshot_macOS_Configure_Local](images/screenshot_macOS_Configure_Local.png)

### 🌐 Global settings

#### ⌨ Commands to configure globally

```bash
cd /usr/local/yafp
cp yafp-cfg.bash.example yafp-cfg.bash
```

#### 👁️ Example of global configuration

![screenshot_macOS_Configure_Global](images/screenshot_macOS_Configure_Global.png)

## III. :eyes: Preview

### 👤 Local preview

#### ⌨ Commands for local preview

```bash
source ~/yafp/yafp-ps1.bash
```

#### 👁️ Example of local preview

![screenshot_macOS_Preview_Local](images/screenshot_macOS_Preview_Local.png)

### 🌐 Global preview

#### ⌨ Commands for global preview

```bash
source /usr/local/yafp/yafp-ps1.bash
```

#### 👁️ Example of global preview

![screenshot_macOS_Preview_Global](images/screenshot_macOS_Preview_Global.png)

## IV. :heavy_check_mark: Install

### 👤 Local install

#### ⌨ Commands for local install

```bash
echo source ~/yafp/yafp-ps1.bash >> ~/.bash_profile 
```

#### 👁️ Example of local install

![screenshot_macOS_Install_Local](images/screenshot_macOS_Install_Local.png)

### 🌐 Global install

#### ⌨ Commands for global installation

```bash
echo source /usr/local/yafp/yafp-ps1.bash >> ~/.bash_profile 
```

#### 👁️ Example of global installation

![screenshot_macOS_Install_Global](images/screenshot_macOS_Install_Global.png)

## V. Semantic command blocks with OSC 133

YAFP is a Bash/PowerShell prompt project. It does not own the pseudo-terminal,
ANSI parser, terminal renderer, or visible scrollback buffer. For terminals that
understand shell integration markers, the Bash prompt emits OSC 133 sequences so
each command can be identified as a semantic block:

```text
OSC 133 ; A  prompt start
OSC 133 ; B  prompt end / user input start
OSC 133 ; C  command start / output start
OSC 133 ; D  command finished, with exit code
```

This is enabled by default in `yafp-cfg.bash.example`:

```bash
YAFP_OSC133=1
```

Set it to `0` if your terminal does not handle OSC 133 correctly:

```bash
YAFP_OSC133=0
```

YAFP preserves the visible prompt behavior when OSC 133 is disabled. When it is
enabled, OSC markers are wrapped as non-printing prompt sequences, so they should
not appear as visible text or disturb cursor positioning.

### Bash integration details

YAFP emits:

- `OSC 133;A` and `OSC 133;B` inside `PS1`;
- `OSC 133;C` from a Bash `DEBUG` trap when a user command starts;
- `OSC 133;D;<exit_code>` at the beginning of the next `PROMPT_COMMAND`.

Internally, the Bash implementation keeps a lightweight command-block model with
fields for id, command text, exit code, start time, finish time, duration, status,
and approximate history positions. The structure also reserves stdout/stderr
fields for a future terminal-side integration, but Bash alone cannot separate or
capture scrollback output without changing how commands are executed.

### zsh and fish

The current implementation is Bash-only. zsh and fish can use the same OSC 133
protocol, but they need shell-native hooks such as `precmd`/`preexec` in zsh or
fish event handlers. A future YAFP shell module can add those without inventing a
new protocol.

### Current limitations

- YAFP cannot draw selectable visual borders around scrollback blocks because it
  is not the terminal renderer.
- stdout and stderr are not captured separately yet.
- buffer positions are approximate Bash history positions, not terminal cell
  coordinates.
- Advanced actions such as copy command, copy output, or copy whole block belong
  in a terminal UI layer or a future YAFP companion renderer.

### Tests

Run the OSC 133 parser and command-block lifecycle tests with:

```bash
bash tests/osc133_test.bash
```
