local Passphrase = {}

do
  --- Cached passphrase for the current session.
  --- @type string|nil
  local _cached_passphrase = nil

  --- Retrieve the cached passphrase.
  --- @return string|nil cached_passphrase or nil if unset
  function Passphrase.get()
    return _cached_passphrase
  end

  --- Store a passphrase in cache.
  --- @param secret string|nil passphrase to cache, or nil to clear
  function Passphrase.set(secret)
    _cached_passphrase = secret
  end

  --- Erase the cached passphrase of the session
  function Passphrase.wipeout()
    _cached_passphrase = nil
  end
end

return Passphrase
