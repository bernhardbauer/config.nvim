# nvim config

Personal Neovim configuration, originally based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) but heavily extended over time. Focused on .NET/C#, TypeScript/Angular, and Lua development on macOS.

> [!NOTE]
> Only tested on macOS. YMMV on other platforms.

## Features

- **LSP** via `nvim-lspconfig` + Mason: C#, TypeScript, Angular, Emmet, Lua, Terraform, PKL
- **Completion** via `blink.cmp`: LSP, snippets, buffer, path, with ghost text and signature help
- **Formatting** via `conform.nvim`: `csharpier`, `stylua`, `prettierd`, `terraform fmt`
- **Debugging (DAP)**: deep .NET/C# support with auto-build + env parsing, and JS/TS/Jest debugging
- **Testing**: `neotest` with `neotest-jest`, local Angular `ng test` integration, `neotest-vitest`, and `neotest-dotnet`
- **Task running**: `overseer.nvim` with custom `dotnet run/build/test` templates
- **File explorer + UI**: `snacks.nvim` (explorer, dashboard, lazygit, notifications, indent guides)
- **Fuzzy finding**: Telescope with branch-file search and fzf-native sorter
- **File bookmarks**: `grapple.nvim` (per-git-branch file tagging)
- **AI agent**: `opencode.nvim` connected to Amazon Bedrock / Claude Sonnet
- **Git**: `gitsigns.nvim` + lazygit via snacks
- **UI enhancements**: `noice.nvim` (command line, messages, LSP hover), `which-key.nvim`
- **Navigation**: `other.nvim` (Angular alt-file jump), `sibling-jump.nvim` (treesitter sibling nodes)
- **Editing**: `nvim-surround`, `nvim-autopairs`, `mini.ai` extended text objects
- **npm**: `package-info.nvim` shows dependency versions as virtual text

## Installation

### 1. Homebrew dependencies

```sh
brew install neovim ripgrep fd pkl-lsp prettier prettierd opencode make cmake
```

### 2. dotnet

Install via [the official install scripts](https://github.com/dotnet/install-scripts?tab=readme-ov-file) to support multiple runtimes side by side:

```sh
./dotnet-install.sh --version 10.0.101
./dotnet-install.sh --version 9.0.308
```

Add to `~/.zshrc`:

```sh
export DOTNET_ROOT="/Users/$USER/.dotnet"
export PATH="/Users/$USER/.dotnet:$PATH"
```

### 3. netcoredbg (DAP adapter for .NET, arm Mac)

```sh
cd ~/git
git clone https://github.com/Samsung/netcoredbg.git
cd netcoredbg
rm -rf build src/debug/netcoredbg/bin bin
mkdir build && cd build
CC=clang CXX=clang++ cmake ..
make
make install
```

The config expects the binary at `~/git/netcoredbg/build/src/netcoredbg`.

### 4. Clone and launch

```sh
git clone <your-repo-url> ~/.config/nvim
nvim
```

Lazy.nvim will bootstrap itself and install all plugins on first launch. Use `:Lazy` to check status.

### 5. Mason / DAP post-install

Inside Neovim, install the remaining tools that Mason doesn't handle automatically:

```
:MasonInstall angular-language-server
:MasonInstall typescript-language-server
:DapInstall js
```

### Other notes

- A [Nerd Font](https://www.nerdfonts.com/) is required — set `vim.g.have_nerd_font = true` in `init.lua`
- opencode requires Amazon Bedrock credentials — see `opencode.example.json` for the config format

## Structure

```
~/.config/nvim/
├── init.lua                    # Options, global keymaps, lazy.nvim bootstrap
└── lua/
    ├── plugins/                # Plugin configs (auto-imported by lazy.nvim)
    ├── configs/
    │   ├── bool-toggle.lua     # <C-a> boolean toggle (true/false/TRUE/FALSE)
    │   ├── nvim-close-all.lua  # Close all panels (explorer, DAP UI, etc.)
    │   └── nvim-dap-dotnet.lua # .NET DAP: auto-build, launchSettings.json parsing
    ├── kickstart/
    │   ├── health.lua          # :checkhealth integration
    │   └── plugins/lint.lua    # nvim-lint (markdownlint)
    └── overseer/template/user/
        └── dotnet_run.lua      # Overseer task: dotnet run/build/test
```

## Key Mappings

Leader key: `<Space>`

### General

| Key           | Action                                         |
| ------------- | ---------------------------------------------- |
| `\`           | Toggle file explorer                           |
| `<Esc>`       | Clear search highlight                         |
| `<leader>q`   | Open diagnostic quickfix list                  |
| `grl`         | Show diagnostic in floating window             |
| `<leader>xx`  | Close all panels                               |
| `<C-h/j/k/l>` | Navigate splits                                |
| `<C-a>`       | Toggle boolean under cursor / increment number |

### LSP

| Key          | Action                    |
| ------------ | ------------------------- |
| `grn`        | Rename symbol             |
| `gra`        | Code action               |
| `grr`        | References                |
| `gri`        | Implementation            |
| `grd`        | Definition                |
| `gO`         | Document symbols          |
| `gW`         | Workspace symbols         |
| `grt`        | Type definition           |
| `<leader>xh` | Toggle inlay hints        |
| `gru`        | TS: Remove unused imports |
| `gro`        | TS: Organize imports      |
| `grO`        | TS: Add missing imports   |

### Find (`<leader>f`)

| Key                | Action                               |
| ------------------ | ------------------------------------ |
| `<leader>ff`       | Find files (incl. hidden/gitignored) |
| `<leader>fg`       | Live grep                            |
| `<leader>fw`       | Grep word under cursor               |
| `<leader>fd`       | Find diagnostics                     |
| `<leader>fh`       | Find help tags                       |
| `<leader>fk`       | Find keymaps                         |
| `<leader>fs`       | Find/select Telescope source         |
| `<leader>fb`       | Find files in current git branch     |
| `<leader>fa`       | Find alternative file (Angular)      |
| `<leader><leader>` | Find open buffers                    |
| `<leader>fr`       | Resume last picker                   |
| `<leader>f.`       | Recent files                         |
| `<leader>ft`       | TODOs                                |
| `<leader>fc`       | Clipboard history                    |
| `<leader>fm`       | Macro history                        |
| `<leader>fn`       | Find Neovim config files             |
| `<leader>f/`       | Grep in open files                   |
| `<leader>/`        | Fuzzy search current buffer          |

### Debug (`<leader>d`)

| Key                    | Action                                                              |
| ---------------------- | ------------------------------------------------------------------- |
| `<leader>dd`           | Smart continue (auto-pick config or show picker)                    |
| `<leader>da`           | Continue / run with args                                            |
| `<leader>db`           | Toggle breakpoint                                                   |
| `<leader>dB`           | Conditional breakpoint                                              |
| `<leader>dC`           | Run to cursor                                                       |
| `<leader>dg`           | Go to line (no execute)                                             |
| `<leader>dj`           | Down stack frame                                                    |
| `<leader>dk`           | Up stack frame                                                      |
| `<leader>dl`           | Run last                                                            |
| `<leader>dP`           | Pause                                                               |
| `<leader>ds`           | Show session                                                        |
| `<leader>du`           | Toggle DAP UI                                                       |
| `<leader>de`           | Inspect variable (hover)                                            |
| `<leader>dt`           | Terminate session                                                   |
| `<leader>dx`           | Clear all breakpoints                                               |
| `<Up/Down/Right/Left>` | Continue / Step over / Step into / Step out _(active session only)_ |

### Test (`<leader>t`)

| Key          | Action              |
| ------------ | ------------------- |
| `<leader>tt` | Run nearest test    |
| `<leader>tf` | Run file            |
| `<leader>tA` | Run all tests       |
| `<leader>tl` | Run last            |
| `<leader>td` | Debug nearest test  |
| `<leader>ts` | Toggle summary      |
| `<leader>to` | Show output         |
| `<leader>tO` | Toggle output panel |
| `<leader>tS` | Stop test run       |
| `<leader>tw` | Watch toggle        |

### Run / Tasks (`<leader>r`)

| Key           | Action                  |
| ------------- | ----------------------- |
| `<leader>rr`  | Run task                |
| `<leader>rv`  | Toggle task list        |
| `<leader>rt`  | Task action             |
| `<leader>rs`  | Shell                   |
| `<leader>rnu` | npm: Update dependency  |
| `<leader>rnd` | npm: Delete dependency  |
| `<leader>rnc` | npm: Change dep version |

### Git (`<leader>h` / `<leader>g`)

| Key          | Action                     |
| ------------ | -------------------------- |
| `<leader>gg` | Open lazygit               |
| `]c` / `[c`  | Next / prev hunk           |
| `<leader>hs` | Stage hunk                 |
| `<leader>hr` | Reset hunk                 |
| `<leader>hS` | Stage entire buffer        |
| `<leader>hR` | Reset entire buffer        |
| `<leader>hu` | Undo stage hunk            |
| `<leader>hp` | Preview hunk               |
| `<leader>hb` | Blame line                 |
| `<leader>hB` | Full buffer blame          |
| `<leader>hd` | Diff against index         |
| `<leader>hD` | Diff against last commit   |
| `<leader>xb` | Toggle inline blame        |
| `<leader>xD` | Toggle show deleted inline |

### File Marks / Grapple (`<leader>m`)

| Key         | Action                     |
| ----------- | -------------------------- |
| `<leader>m` | Toggle tag on current file |
| `<leader>M` | Open tags window           |
| `<leader>n` | Next tag                   |
| `<leader>p` | Previous tag               |

### AI (`<leader>c`)

| Key          | Action                         |
| ------------ | ------------------------------ |
| `<leader>cc` | Ask opencode about selection   |
| `<leader>cx` | Execute opencode action        |
| `<C-,>`      | Toggle opencode panel          |
| `go`         | Add range to opencode          |
| `goo`        | Add current line to opencode   |
| `<leader>ca` | Send file to opencode (picker) |

### Navigation

| Key     | Action                                 |
| ------- | -------------------------------------- |
| `<C-j>` | Jump to next sibling node (treesitter) |
| `<C-k>` | Jump to prev sibling node (treesitter) |

### Surround (`nvim-surround`)

| Key  | Action                         |
| ---- | ------------------------------ |
| `ys` | Add surrounding (e.g. `ysiw"`) |
| `cs` | Change surrounding             |
| `ds` | Delete surrounding             |

### Other

| Key          | Action               |
| ------------ | -------------------- |
| `<leader>pp` | Format buffer        |
| `<leader>xn` | Notification history |

## Notable Behaviours

### Boolean Toggle (`<C-a>`)

`<C-a>` toggles `true`↔`false`, `True`↔`False`, `TRUE`↔`FALSE` under the cursor. Falls back to the standard number increment when no boolean is found.

### DAP — Smart Continue

`<leader>dd` checks if a session is already active (resumes it), otherwise filters available launch configs by a `condition()` function and auto-starts if exactly one matches — no picker unless ambiguous.

### DAP — Dynamic Arrow Keys

Arrow keys are only mapped during an active debug session and are automatically removed when the session terminates.

### DAP — .NET Auto-Build

Before launching a .NET debug session, the config walks up the directory tree to find the nearest `.csproj`, runs `dotnet build --configuration Debug`, and reads `Properties/launchSettings.json` to extract environment variables, `ASPNETCORE_URLS`, and command-line args automatically.

### Neotest — JS/TS Config Discovery

A custom config-dir traversal walks up from the active file to find the nearest Jest or Vitest/Vite config, which keeps `Run Current File` working in monorepos and plain Vitest workspaces.

### Neotest — Angular Workspace Support

Angular projects that use the `@angular/build:unit-test` builder with the Vitest runner are executed through `ng test` instead of raw `vitest`, so file and nearest-test runs use the Angular workspace configuration from `angular.json`.
