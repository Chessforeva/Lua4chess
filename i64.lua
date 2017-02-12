
-- Emulates 64bit bitwise operations. Slow.

require "bit"

function i64(v)
 local o = {}; o.l = v; o.h = 0; return o;
end -- constructor +assign 32-bit value

function i64_ax(h,l)
 local o = {}; o.l = l; o.h = h; return o;
end -- +assign 64-bit v.as 2 regs

-- unsigned [0..0xFFFFFFFF]
function i64u(x)
 return bit.band( ( bit.lshift(bit.rshift(x,1),1) + bit.band(x,1) ), 0xFFFFFFFF);
end

function i64_clone(x)
 local o = {}; o.l = x.l; o.h = x.h; return o;
end -- +assign regs

-- Type conversions


function i64_toInt(a)
  return (a.l + (a.h * (0x100000000)));
end -- supports value=2^53 or even less (better not to use)

function i64i(a)
 return a.l;
end -- simply return lowest reg.

function i64_toString(a)
  local s1=string.format("%x",a.l);
  local s2=string.format("%x",a.h);
  local s3="0000000000000000";
  s3=string.sub(s3,1,16-string.len(s1))..s1;
  s3=string.sub(s3,1,8-string.len(s2))..s2..string.sub(s3,9);
  return "0x"..string.upper(s3);
end

-- Bitwise operators (the main functionality)

function i64_and(a,b)
 local o = {}; o.l = i64u( bit.band(a.l, b.l) ); o.h = i64u( bit.band(a.h, b.h) ); return o;
end

function i64_or(a,b)
 local o = {}; o.l = i64u( bit.bor(a.l, b.l) ); o.h = i64u( bit.bor(a.h, b.h) ); return o;
end

function i64_xor(a,b)
 local o = {}; o.l = i64u( bit.bxor(a.l, b.l) ); o.h = i64u( bit.bxor(a.h, b.h) ); return o;
end

function i64_not(a)
 local o = {}; o.l = i64u( bit.bnot(a.l) ); o.h = i64u( bit.bnot(a.h) ); return o;
end

function i64_neg(a)
 return i64_inc( i64_not(a) );
end  -- negative is inverted and incremented by +1

-- Simple Math-functions

-- just to add, not rounded for overflows
function i64_inc(a)
 local o = {};
 o.l = i64u(a.l+1);
 if( o.l==0 ) then
   o.h = i64u(a.h+1);
 else
   o.h = i64u(a.h);
 end
 return o;
end


-- Bit-shifting

function i64_lshift(a,n)
 local o = {};
 if(n==0) then
   o.l=a.l; o.h=a.h;
 else
   if(n<32) then
     o.l= i64u( bit.lshift( a.l, n) ); o.h=i64u( bit.lshift( a.h, n) )+ bit.rshift(a.l, (32-n));
   else
     o.l=0; o.h=i64u( bit.lshift( a.l, (n-32)));
   end
  end
  return o;
end

function i64_rshift(a,n)
 local o = {};
 if(n==0) then
   o.l=a.l; o.h=a.h;
 else
   if(n<32) then
     o.l= bit.rshift(a.l, n)+i64u( bit.lshift(a.h, (32-n))); o.h=bit.rshift(a.h, n);
   else
     o.l=bit.rshift(a.h, (n-32)); o.h=0;
   end
  end
  return o;
end

function i64_unsigned(a)
  local s1=string.format("%x",a.l);
  local s2=string.format("%x",a.h);
  return i64_ax(tonumber("0x"..s2),tonumber("0x"..s1));
end

function i64s(s) -- from string in hex format
 local a=1;
 local r=0;
 if(string.sub(s,1,2)=="0x") then
   a = a + 2;
 end
 local b=string.len(s)-a+1;
 if(b<9) then
   r=i64( tonumber( "0x" .. string.sub(s,a) ) );
 else
   local q1=string.sub(s,a,a+b-9);
   local q2=string.sub(s,a+b-8);
   r=i64_ax( tonumber("0x" .. q1), tonumber("0x" .. q2) );
 end
 return r;
end

-- Comparisons

function i64_eq(a,b)
 return ((a.h == b.h) and (a.l == b.l));
end

function i64_ne(a,b)
 return ((a.h ~= b.h) or (a.l ~= b.l));
end

function i64_gt(a,b)
 return ((a.h > b.h) or ((a.h == b.h) and (a.l >  b.l)));
end

function i64_ge(a,b)
 return ((a.h > b.h) or ((a.h == b.h) and (a.l >= b.l)));
end

function i64_lt(a,b)
 return ((a.h < b.h) or ((a.h == b.h) and (a.l <  b.l)));
end

function i64_le(a,b)
 return ((a.h < b.h) or ((a.h == b.h) and (a.l <= b.l)));
end

function i64_is0(a,b)
 return ((a.l == 0) and (a.h == 0));
end

function i64_nz(a,b)
 return ((a.l ~= 0) or (a.h ~= 0));
end
