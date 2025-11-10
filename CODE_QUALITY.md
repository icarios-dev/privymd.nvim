# Code Quality Guidelines

This document defines the quality standards and conventions used in
**PrivyMD** development. The goal is to maintain clean, testable, and
consistent code across the entire project.

---

## 1. Objectives

- Write **clean, self-explanatory, and maintainable** code
- Ensure **strong test coverage** for all core features
- Follow consistent **style and formatting** rules
- Keep functions **small, pure, and predictable** whenever possible
- Prioritize **clarity over cleverness**

---

## 2. Code Style

- **Language:** Lua (Neovim ≥ 0.10)
- **Formatter:** [StyLua](https://github.com/JohnnyMorganz/StyLua)
- **Linter:** [Selene](https://kampfkarren.github.io/selene/)

### General conventions
- Use **English** for code comments, docstrings, and commit messages
- Use **2 spaces** for indentation (handled by StyLua)
- Always type functions using **EmmyLua annotations**
- Avoid deep nesting — prefer early returns
- Never use global variables; all modules must return a local `M` table
- Keep logging meaningful (`trace`, `debug`, `info`, `warn`, `error` levels)

---

## 3. Commit Conventions

Follow the [Conventional Commits](https://www.conventionalcommits.org/) format:
`<type>(<scope>): <short summary>`

**Examples:**
- feat(encrypt): add progress indicator during block encryption
- fix(hooks): preserve buffer modified flag after decryption
- refactor(gpg): move GPG check to helpers
- test(frontmatter): add coverage for missing key detection

---

## 4. Testing

- Test framework: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Tests are organized in:
  - `tests/unit/` → isolated module tests
  - `tests/integration/` → realistic multi-module scenarios
- All modules are tested except `utils/` (to be covered later).
- Use mocks for external dependencies (`vim.fn`, `vim.api`, GPG I/O).

**Goal:** maintain **complete coverage** for all core features,
particularly `gpg`, `block`, and `encrypt` modules.

---

## 5. Documentation

- Use **EmmyLua** annotations for all public functions and exported types.
- Keep inline comments concise and in English.
- _README.md_ should describe usage, not implementation details.
- Developer notes, design decisions, and technical conventions live here.

---

## 6. Future Improvements

- Integrate **code coverage reporting** –
  [luacov](https://keplerproject.github.io/luacov)
- Introduce a **review checklist** to enforce development discipline
  (readability, test impact, performance)

---

Following these guidelines ensures that PrivyMD remains a **clean,
robust, and enjoyable codebase** to work with.
