local util = require('rapid.util')

describe('util test case', function()
  it('util.has_file', function()
    local str = {
      "lession2.c:8:3: warning: 'strcpy' will always overflow; destination buffer has size 4, but the source string has length 16 (including NUL byte) [-Wfortify-source]",
      '  strcpy(num, "bbbbbbbbbbbb\x0F\x10\x40\x00");',
      '  ^',
      "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_string.h:84:3: note: expanded from macro 'strcpy'",
      '               __builtin___strcpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))',
      '                ^',
      '1 warning generated.',
    }
    local result = util.has_file(str, 0)
    assert.same({
      {
        file = {
          ecol = 10,
          line = 1,
          scol = 1,
        },
        targetPos = {
          ecol = 14,
          line = 1,
          scol = 12,
        },
      },
      {
        file = {
          ecol = 80,
          line = 4,
          scol = 1,
        },
        targetPos = {
          ecol = 85,
          line = 4,
          scol = 82,
        },
      },
    }, result)
  end)
end)
