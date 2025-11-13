require('plenary')

local H = require('privymd.core.gpg.inspect_helpers')

describe('GPG inspect', function()
  describe('parse_keyids', function()
    it('should return table ok keys', function()
      local output = {
        '# off=0 ctb=84 tag=1 hlen=2 plen=94',
        ':pubkey enc packet: version 3, algo 18, keyid KEY1',
        'data: [263 bits]',
        ':pubkey enc packet: version 3, algo 18, keyid KEY2',
      }
      local data = table.concat(output, '\n')

      local keys = H.parse_keyids(data)

      assert.is_table(keys)
      assert.is_equal(2, #keys)
      assert.is_equal('KEY1', keys[1])
      assert.is_equal('KEY2', keys[2])
    end)
  end)

  describe('parse_first_uid', function()
    it('should return an uid', function()
      local output = {
        'fpr:::::::::4B23679879F3D61E0:',
        'uid:u::::176057::ED530::one@identity::::::::::0:',
        'uid:u::::6057::9D6F626::two@identity::::::::::0:',
      }
      local data = table.concat(output, '\n')

      local uid = H.parse_first_uid(data)

      assert.is_string(uid)
      assert.is_equal('one@identity', uid)
    end)
  end)
end)
