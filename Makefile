# Dossiers
SRC_DIR = lua
TEST_DIR = tests

# Commandes
LUA_CHECK = luacheck
SELENE = selene
NEOVIM = nvim

# Fichiers
MINIMAL_INIT = $(TEST_DIR)/minimal_init.lua

all: help

.PHONY: lint
lint: selene

.PHONY: luacheck
luacheck:
	@echo "Running Luacheck linter …"
	@$(LUA_CHECK) $(SRC_DIR) $(TEST_DIR)

.PHONY: selene
selene:
	@echo "Running Selene linter …"
	@$(SELENE) $(SRC_DIR) $(TEST_DIR)

.PHONY: test
test:
	@echo "🧪 Running tests with Plenary…"
	@$(NEOVIM) --headless -c "lua require('plenary.test_harness').test_directory('$(TEST_DIR)', { minimal_init = '$(MINIMAL_INIT)' })" +qa

.PHONY: test-unit
test-unit:
	@echo "🧪 Running unit tests with Plenary…"
	@$(NEOVIM) --headless -c "lua require('plenary.test_harness').test_directory('$(TEST_DIR)/unit', { minimal_init = '$(MINIMAL_INIT)' })" +qa

.PHONY: test-integration
test-integration:
	@echo "🧪 Running integration tests with Plenary…"
	@$(NEOVIM) --headless -c "lua require('plenary.test_harness').test_directory('$(TEST_DIR)/integration', { minimal_init = '$(MINIMAL_INIT)', sequential=true })" +qa


.PHONY: fmt
fmt:
	@echo "🎨 Formatting Lua files..."
	@stylua $(SRC_DIR) $(TEST_DIR)

.PHONY: help
help:
	@echo ""
	@echo "=== PrivyMD.nvim Makefile ==="
	@echo ""
	@echo "make lint   → run Luacheck linter"
	@echo "make test   → run Plenary test suite"
	@echo "make fmt    → format Lua code with StyLua"
	@echo ""
