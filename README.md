# privymd.nvim

Neovim plugin to edit Markdown files containing encrypted GPG blocks.

## Features

* 🔓 Automatic decryption on file open (`decrypt_async`)
* 🔒 Automatic encryption on save (`encrypt_sync`)
* 🧩 Special Markdown code fences: `gpg`
* 📄 Define the GPG recipient in the YAML front‑matter:

````yaml
---
gpg-recipient: your-gpg-key-id
---
````

* 🔐 Passphrase requested only once per session
* 💾 No plaintext ever written to disk

## Dependencies

* Neovim ≥ 0.10
* `gnupg` (`gpg` must be available in your `$PATH`)

## Installation (example with Lazy.nvim)

```lua
return {
  "icarios-dev/privymd.nvim",
  ft = "markdown",
  config = function()
    require("privymd").setup({
      -- optional configuration here
    })
  end,
}
```

## Configuration options

Default values:

```lua
require("privymd").setup({
  ft_pattern = "*.md",
  auto_decrypt = true,  -- automatically decrypt on open
  auto_encrypt = true,  -- automatically encrypt on save
  progress = true,      -- show a progress indicator
})
```

## Available commands

| Command              | Description                                           |
| -------------------- | ----------------------------------------------------- |
| `:PrivyMDShowBlocks` | List all detected GPG blocks                          |
| `:PrivyMDClearPass`  | Forget cached passphrase                              |
| `:PrivyDecrypt`      | Force decryption of current buffer                    |
| `:PrivyEncrypt`      | Force encryption and save immediately                 |
| `:PrivyToggle`       | Toggle plaintext/encrypted in memory (without saving) |

---

## ✅ Highlights

1. **Everything stays in memory** → no temporary plaintext files.
2. **Transparent workflow** → edit Markdown normally.
3. **Secure save** → all GPG blocks are re‑encrypted before writing.
4. **Autonomous plugin** → no manual setup beyond installation.

---

## ⚙️ Usage

Each Markdown file must define a GPG key identifier (`gpg-recipient`) in its *YAML front‑matter*.
Text regions that should be encrypted must be wrapped inside fenced code blocks using the `gpg` language:

``````markdown

Clear text

````gpg
Secret content...

````

Clear text

``````

* On open, blocks are automatically decrypted; on save, they are encrypted again.
* On failure, clear error messages will indicate the cause (`ENOENT`, invalid passphrase, etc.).

---

## 🧭 Compatibility

Tested only on **Linux (Arch)**.
Other Unix‑like systems may work but are not officially supported.

Windows is **not supported**.

---

## 🧪 Code quality & conventions

The project follows a strict philosophy: **no unnecessary warnings** and **no hidden logic**.

### Linting

* Lua code is analyzed using **LuaLS**.
* The repository must stay **diagnostic‑free** (`0 warnings`).
* Any exceptions must be explicitly justified, for example:

```lua
---@diagnostic disable-next-line: missing-fields
handle, spawn_err = uv.spawn("gpg", {
  args = args,
  stdio = stdio,
  env = {},
  verbatim = false,
  detached = false,
  hide = true,
})
```

* Never disable diagnostics globally for a whole file.

### Style

* Indentation: 2 spaces, no tabs.
* Explicit local variables (`local handle; handle, spawn_err = ...`).
* No implicit global variables.
* Consistent naming (`snake_case`).
* Structured logging levels: `trace`, `debug`, `info`, `warn`, `error`.
* Every exception or edge case must include a clear comment.

---

## 📜 License

MIT — © 2025 [icarios-dev](https://github.com/icarios-dev)
