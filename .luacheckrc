-- Cache les résultats pour accélérer les relint
cache = true

-- Langage de base (neovim = LuaJIT)
std = 'luajit'
codes = true

-- Globales connues
read_globals = {
  'vim', -- API Neovim
}

-- Globals définies dans les tests Busted / Plenary
files['tests/**'] = {
  globals = {
    'describe',
    'it',
    'before_each',
    'after_each',
    'pending',
    'assert',
    'clear',
    'print',
  },
  read_globals = {
    'vim',
  },
}

-- Ignore certains avertissements inutiles
ignore = {
  '122', -- assignment to read-only global (souvent faux positif sur vim)
  '212', -- unused argument (souvent dans les callbacks)
}

-- Exclusions
exclude_files = {
  'tests/minimal_init.lua',
}

-- Permet de lire ce fichier comme root
self = false
