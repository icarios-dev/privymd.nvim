--- @module 'privymd.core.passphrase'
--- Centralized in-memory cache for the user's GPG passphrase.
---
--- This module isolates the cached passphrase in a private scope,
--- providing controlled access through explicit getters and setters.
--- It ensures that sensitive data cannot be accessed or modified
--- outside the defined API surface.
---
--- ⚠️ **Security note**:
--- Clearing the cached passphrase with `Passphrase.wipeout()` only
--- removes it from PrivyMD’s in-memory cache. It does *not* revoke
--- or lock any GPG agent session that may still hold the decrypted key.
--- In other words, wiping the passphrase here does **not** guarantee
--- that access to encrypted data is fully blocked if your GPG agent
--- keeps the key unlocked.
---
--- Usage example:
--- ```lua
--- local Passphrase = require('privymd.core.passphrase')
---
--- -- Store a passphrase for the current session
--- Passphrase.set('top-secret')
---
--- -- Retrieve it later
--- local value = Passphrase.get()
--- print(value) --> "top-secret"
---
--- -- Wipe the cached value when done
--- Passphrase.wipeout()
--- ```
---
--- The passphrase remains available only in memory for the lifetime
--- of the current Neovim session and is never written to disk.

local Passphrase = {}

do
  --- Cached passphrase for the current session (private scope).
  --- @type string|nil
  local _cached_passphrase = nil

  --- Retrieve the cached passphrase.
  ---
  --- @return string|nil cached_passphrase Returns the cached value,
  --- or `nil` if no passphrase has been stored.
  function Passphrase.get()
    return _cached_passphrase
  end

  --- Store a passphrase in cache.
  ---
  --- @param secret string|nil The passphrase to cache.
  --- Pass `nil` to clear the stored value.
  function Passphrase.set(secret)
    _cached_passphrase = secret
  end

  --- Erase the cached passphrase of the current session.
  --- Equivalent to calling `Passphrase.set(nil)`.
  function Passphrase.wipeout()
    _cached_passphrase = nil
  end
end

return Passphrase
