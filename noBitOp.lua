	-- Pure Lua without BitOp library (just in case)

local bitwises = {_TYPE='module', _NAME='bitwises.numberlua', _VERSION='0.3.20111129'}

local floor = math.floor

local MOD = 2^32
local MODM = MOD-1

local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k); t[k] = v
    return v
  end
  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t[am][bm]*p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a+b)*p
    return res
  end
  return bitop
end

local function make_bitop(t)
  local op1 = make_bitop_uncached(t,2^1)
  local op2 = memoize(function(a)
    return memoize(function(b)
      return op1(a, b)
    end)
  end)
  return make_bitop_uncached(op2, 2^(t.n or 1))
end

-- ok?  probably not if running on a 32-bit int Lua number type platform
function bitwises.tobit(x)
  return x % 2^32
end

bitwises.bxor = make_bitop {[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4}
local bxor = bitwises.bxor

function bitwises.bnot(a)   return MODM - a end
local bnot = bitwises.bnot

function bitwises.band(a,b) return ((a+b) - bxor(a,b))/2 end
local band = bitwises.band

function bitwises.bor(a,b)  return MODM - band(MODM - a, MODM - b) end
local bor = bitwises.bor

local lshift, rshift -- forward declare

function bitwises.rshift(a,disp) -- Lua5.2 insipred
  if disp < 0 then return lshift(a,-disp) end
  return floor(a % 2^32 / 2^disp)
end
rshift = bitwises.rshift

function bitwises.lshift(a,disp) -- Lua5.2 inspired
  if disp < 0 then return rshift(a,-disp) end 
  return (a * 2^disp) % 2^32
end
lshift = bitwises.lshift

function bitwises.tohex(x, n) -- BitOp style
  n = n or 8
  local up
  if n <= 0 then
    if n == 0 then return '' end
    up = true
    n = - n
  end
  x = band(x, 16^n-1)
  return ('%0'..n..(up and 'X' or 'x')):format(x)
end
local tohex = bitwises.tohex

function bitwises.extract(n, field, width) -- Lua5.2 inspired
  width = width or 1
  return band(rshift(n, field), 2^width-1)
end
local extract = bitwises.extract

function bitwises.replace(n, v, field, width) -- Lua5.2 inspired
  width = width or 1
  local mask1 = 2^width-1
  v = band(v, mask1) -- required by spec?
  local mask = bnot(lshift(mask1, field))
  return band(n, mask) + lshift(v, field)
end
local replace = bitwises.replace

function bitwises.bswap(x)  -- BitOp style
  local a = band(x, 0xff); x = rshift(x, 8)
  local b = band(x, 0xff); x = rshift(x, 8)
  local c = band(x, 0xff); x = rshift(x, 8)
  local d = band(x, 0xff)
  return lshift(lshift(lshift(a, 8) + b, 8) + c, 8) + d
end
local bswap = bitwises.bswap

function bitwises.rrotate(x, disp)  -- Lua5.2 inspired
  disp = disp % 32
  local low = band(x, 2^disp-1)
  return rshift(x, disp) + lshift(low, 32-disp)
end
local rrotate = bitwises.rrotate

function bitwises.lrotate(x, disp)  -- Lua5.2 inspired
  return rrotate(x, -disp)
end
local lrotate = bitwises.lrotate

bitwises.rol = bitwises.lrotate  -- LuaOp inspired
bitwises.ror = bitwises.rrotate  -- LuaOp insipred


function bitwises.arshift(x, disp) -- Lua5.2 inspired
  local z = rshift(x, disp)
  if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
  return z
end
local arshift = bitwises.arshift

function bitwises.btest(x, y) -- Lua5.2 inspired
  return band(x, y) ~= 0
end

--
-- Start Lua 5.2 "bit32" compat section.
--

bitwises.bit32 = {} -- Lua 5.2 'bit32' compatibility


local function bit32_bnot(x)
  return (-1 - x) % MOD
end
bitwises.bit32.bnot = bit32_bnot

local function bit32_bxor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = bxor(a, b)
    if c then
      z = bxor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end
bitwises.bit32.bxor = bit32_bxor

local function bit32_band(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = ((a+b) - bxor(a,b)) / 2
    if c then
      z = band(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return MODM
  end
end
bitwises.bit32.band = bit32_band

local function bit32_bor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = MODM - band(MODM - a, MODM - b)
    if c then
      z = bor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end
bitwises.bit32.bor = bit32_bor

function bitwises.bit32.btest(...)
  return bit32_band(...) ~= 0
end

function bitwises.bit32.lrotate(x, disp)
  return lrotate(x % MOD, disp)
end

function bitwises.bit32.rrotate(x, disp)
  return rrotate(x % MOD, disp)
end

function bitwises.bit32.lshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return lshift(x % MOD, disp)
end

function bitwises.bit32.rshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return rshift(x % MOD, disp)
end

function bitwises.bit32.arshift(x,disp)
  x = x % MOD
  if disp >= 0 then
    if disp > 31 then
      return (x >= 0x80000000) and MODM or 0
    else
      local z = rshift(x, disp)
      if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
      return z
    end
  else
    return lshift(x, -disp)
  end
end

function bitwises.bit32.extract(x, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  return extract(x, field, ...)
end

function bitwises.bit32.replace(x, v, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  v = v % MOD
  return replace(x, v, field, ...)
end


--
-- Start LuaBitOp "bit" compat section.
--

 bitwises.bitwises = {} -- LuaBitOp "bit" compatibility

 function bitwises.bitwises.tobit(x)
  x = x % MOD
  if x >= 0x80000000 then x = x - MOD end
  return x
end
local bit_tobit = bitwises.bitwises.tobit

function bitwises.bitwises.tohex(x, ...)
  return tohex(x % MOD, ...)
end

function bitwises.bitwises.bnot(x)
  return bit_tobit(bnot(x % MOD))
end

local function bit_bor(a, b, c, ...)
  if c then
    return bit_bor(bit_bor(a, b), c, ...)
  elseif b then
    return bit_tobit(bor(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end
bitwises.bitwises.bor = bit_bor

local function bit_band(a, b, c, ...)
  if c then
    return bit_band(bit_band(a, b), c, ...)
  elseif b then
    return bit_tobit(band(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end
bitwises.bitwises.band = bit_band

local function bit_bxor(a, b, c, ...)
  if c then
    return bit_bxor(bit_bxor(a, b), c, ...)
  elseif b then
    return bit_tobit(bxor(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end
bitwises.bitwises.bxor = bit_bxor

function bitwises.bitwises.lshift(x, n)
  return bit_tobit(lshift(x % MOD, n % 32))
end

function bitwises.bitwises.rshift(x, n)
  return bit_tobit(rshift(x % MOD, n % 32))
end

function bitwises.bitwises.arshift(x, n)
  return bit_tobit(arshift(x % MOD, n % 32))
end

function bitwises.bitwises.rol(x, n)
  return bit_tobit(lrotate(x % MOD, n % 32))
end

function bitwises.bitwises.ror(x, n)
  return bit_tobit(rrotate(x % MOD, n % 32))
end

function bitwises.bitwises.bswap(x)
  return bit_tobit(bswap(x % MOD))
end

