--=========================================
-- It is not lua-appropriate Chess engine!
--=========================================
-- This "porting fun" is based on OliThink.
-- Very experimental lua mix, emulated, slow, do not use for projects!
-- It's for fun only. Able to checkmate by the way :)
--
-- Requires library for bitwise operations http://bitop.luajit.org/
-- Emulates 64bit numbers
--  Generates rays_mem.txt on first run with pre-calculated numbers
--
-- LuaJIT

require "bit"

-- this loads and executes other .lua file
function dofile (filename)
  local f = assert(loadfile(filename))
  return f()
end
dofile( "i64.lua" );	-- int 64

--
-- Chess Engine
--
      g_sd = 4;		-- depth to think :)))) LOL
      g_tm = 8;		-- seconds to think

      g_VER = "OliThink 5.3.0 Java port to Lua";

      g_movemade = "";
      g_pgn = "";
      g_ex = 0;

      g_PAWN = 1;
      g_KNIGHT = 2;
      g_KING = 3;
      g_ENP = 4;
      g_BISHOP = 5;
      g_ROOK = 6;
      g_QUEEN = 7;

      g_HEUR = 9900000;
      g_pval = { 0, 100, 290, 0, 100, 310, 500, 950 };

      g_cag_p_val = { 0, g_HEUR+1, g_HEUR+2, 0, g_HEUR+1, g_HEUR+2, g_HEUR+3, g_HEUR+4 };

      g_pawnrun = { 0, 0, 1, 8, 16, 32, 64, 128 };

      g_HSIZEB = 0x200000;
      g_HMASKB = g_HSIZEB-1;
      g_HINVB =  i64_or(i64_ax(0xFFFFFFFF,0), i64_and(i64_ax(0,0xFFFFFFFF), i64_not( i64(g_HMASKB) )));

      g_HSIZEP = 0x400000;
      g_HMASKP = g_HSIZEP-1;
      g_HINVP =  i64_or(i64_ax(0xFFFFFFFF,0), i64_and(i64_ax(0,0xFFFFFFFF), i64_not( i64(g_HMASKP) )));

      g_hashDB = {};	--[0 for x in range(g_HSIZEB)]
      g_hashDP = {};	--[0 for x in range(g_HSIZEP)]
      g_hashb = i64(0);
      g_hstack = {};	--[0 for x in range(0x800)]
      g_mstack = {};	--[0 for x in range(0x800)]
      g_hc = 0;

      g_hashxor = {};	--[0 for x in range(0x4096)]
      g_rays = {};	--[0 for x in range(0x10000)]
      g_pmoves = {};	--[0 for x in range(64)- for x in range(2)]
      g_pcaps = {};	--[0 for x in range(192)- for x in range(2)]
      g_nmoves = {};	--[0 for x in range(64)]
      g_kmoves = {};	--[0 for x in range(64)]
      g_knight = { -17,-10,6,15,17,10,-6,-15 };

      g_king = { -9,-1,7,8,9,1,-7,-8 };

      g_BITi = {};	--[0 for x in range(64)]
      g_LSB = {};	--[0 for x in range(0x10000)]
      g_BITC = {};	--[0 for x in range(0x10000)]
      g_crevoke = {};	--[0x3FF for x in range(64)]
      g_nmobil = {};	--[0 for x in range(64)]
      g_kmobil = {};	--[0 for x in range(64)]
      g_pawnprg = {};	--[0 for x in range(64)- for x in range(2)]
      g_pawnfree = {};	--[0 for x in range(64)- for x in range(2)]
      g_pawnfile = {};	--[0 for x in range(64)- for x in range(2)]
      g_pawnhelp = {};	--[0 for x in range(64)- for x in range(2)]
      g_movelist = {};	--[0 for x in range(256)- for x in range(64)]
      g_movenum = {};	--[0 for x in range(64)]
      g_p_v = {};	--[0 for x in range(64)- for x in range(64)]
      g_pvlength = {};	--[0 for x in range(64)]
      g_kvalue = {};	--[0 for x in range(64)]
      g_iter = 0;
      g_pieceChar = {"*", "P", "N", "K", ".", "B", "R", "Q"};
      g_starttime = 0;
      g_sabort = false;

      g_count = 0;
      g_flags = 0;
      g_mat_ = 0;
      g_onmove = 0;
      g_engine = -1;
      g_kingpos = {};	--[0 for x in range(2)]
      g_pieceb = {};	--[0 for x in range(8)]
      g_colorb = {};	--[0 for x in range(2)]
      g_irbuf = "";

      g_sfen = "rnbqkbnr/pppppppp/////PPPPPPPP/RNBQKBNR w KQkq - 0 1";

      g_r_x = 30903;
      g_r_y = 30903;
      g_r_z = 30903;
      g_r_w = 30903;
      g_r_carry = 0;

      g_bmask45 = {};	--[0 for x in range(64)]
      g_bmask135 = {};	--[0 for x in range(64)]
      g_killer = {};	--[0 for x in range(128)]
      g_history = {};	--[0 for x in range(0x1000)]

      g_eval1 = 0;

      g_nds = 0;
      g_nodes = 0;

      g_Nonevar = { 13, 43, 149, 519, 1809, 6311, 22027 };

      g_mps = 0;
      g_base = 5;
      g_inc = 0;
      g_post_ = true;

      g_0=i64(0);
      g_gameover = "";

      function woutput(txt) -- messages on screen
        print(txt)
      end

      function iif(ask, ontrue, onfalse)
        if( ask ) then
      	  return ontrue;
        end
        return onfalse;
      end


      function ISRANK(c)
        return (c >= "1"  and  c <= "8");
      end

      function ISFILE(c)
        return (c >= "a"  and  c <= "h");
      end

      function FROM(x)
        return bit.band( x, 63 );
      end

      function TO(x)
        return bit.band( bit.rshift(x, 6), 63 );
      end

      function PROM(x)
        return bit.band( bit.rshift(x, 12), 7 );
      end

      function PIECE(x)
        return bit.band( bit.rshift(x, 15), 7 );
      end

      function ONMV(x)
        return bit.band( bit.rshift(x, 18), 1 );
      end

      function CAP(x)
        return bit.band( bit.rshift(x, 19), 7 );
      end

      function _TO(x)
        return bit.lshift(x,6);
      end

      function _PROM(x)
        return bit.lshift(x, 12);
      end

      function _PIECE(x)
        return bit.lshift(x, 15);
      end

      function _ONMV(x)
        return bit.lshift(x, 18);
      end

      function _CAP(x)
        return bit.lshift(x, 19);
      end

      function PREMOVE(f, p, c)
        return bit.bor( bit.bor(f, _ONMV(c)), _PIECE(p) );
      end

      function RATT1(f)
        return g_rays[1+ bit.bor( bit.lshift(f,7), key000(BOARD(), f)) ];
      end

      function RATT2(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key090(BOARD(), f)), 0x2000 ) ];
      end

      function BATT3(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key045(BOARD(), f)), 0x4000 ) ];
      end

      function BATT4(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key135(BOARD(), f)), 0x6000 ) ];
      end

      function RXRAY1(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key000(BOARD(), f)), 0x8000 ) ];
      end

      function RXRAY2(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key090(BOARD(), f)), 0xA000 ) ];
      end

      function BXRAY3(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key045(BOARD(), f)), 0xC000 ) ];
      end

      function BXRAY4(f)
        return g_rays[1+ bit.bor( bit.bor( bit.lshift(f,7), key135(BOARD(), f)), 0xE000 ) ];
      end

      function ROCC1(f)
        return i64_and(RATT1(f), BOARD());
      end

      function ROCC2(f)
        return i64_and(RATT2(f), BOARD());
      end

      function BOCC3(f)
        return i64_and(BATT3(f), BOARD());
      end

      function BOCC4(f)
        return i64_and(BATT4(f), BOARD());
      end

      function RMOVE1(f)
        return i64_and(RATT1(f), i64_not(BOARD()));
      end

      function RMOVE2(f)
        return i64_and(RATT2(f), i64_not(BOARD()));
      end

      function BMOVE3(f)
        return i64_and(BATT3(f), i64_not(BOARD()));
      end

      function BMOVE4(f)
        return i64_and(BATT4(f), i64_not(BOARD()));
      end

      function RCAP1(f,c)
        return i64_and(RATT1(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function RCAP2(f,c)
        return i64_and(RATT2(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function BCAP3(f,c)
        return i64_and(BATT3(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function BCAP4(f,c)
        return i64_and(BATT4(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function ROCC(f)
        return i64_or(ROCC1(f), ROCC2(f));
      end

      function BOCC(f)
        return i64_or(BOCC3(f), BOCC4(f));
      end

      function RMOVE(f)
        return i64_or(RMOVE1(f), RMOVE2(f));
      end

      function BMOVE(f)
        return i64_or(BMOVE3(f), BMOVE4(f));
      end

      function RCAP(f,c)
        return i64_and(ROCC(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function BCAP(f,c)
        return i64_and(BOCC(f), g_colorb[1+bit.bxor(c,1)]);
      end

      function SHORTMOVE(x)
        return i64_and( x, i64_xor(x, BOARD()));
      end

      function SHORTOCC(x)
        return i64_and( x, BOARD());
      end

      function SHORTCAP(x,c)
        return i64_and(x, g_colorb[1+bit.bxor(c,1)]);
      end

      function NMOVE(x)
        return (SHORTMOVE(g_nmoves[1+x]));
      end

      function KMOVE(x)
        return (SHORTMOVE(g_kmoves[1+x]));
      end

      function PMOVE(x,c)
        return i64_and( g_pmoves[1+c][1+x], i64_not(BOARD()));
      end

      function NOCC(x)
        return (SHORTOCC(g_nmoves[1+x]));
      end

      function KOCC(x)
        return (SHORTOCC(g_kmoves[1+x]));
      end

      function POCC(x,c)
        return i64_and(g_pcaps[1+c][1+x], BOARD());
      end

      function NCAP(x,c)
        return (SHORTCAP(g_nmoves[1+x], c));
      end

      function KCAP(x,c)
        return (SHORTCAP(g_kmoves[1+x], c));
      end

      function PCAP(x,c)
        return i64_and(g_pcaps[1+c][1+x], g_colorb[1+bit.bxor(c,1)]);
      end

      function PCA3(x,c)
        local b=i64_and( g_BITi[1+g_ENPASS()], iif(c==1, i64_ax(0,0xFF0000), i64_ax(0xFF00,0)) );
        return  i64_and( g_pcaps[1+c][1+bit.bor(x,64)], i64_or(g_colorb[1+bit.bxor(c,1)], b ));
      end

      function PCA4(x,c)
        local b=i64_and( g_BITi[1+g_ENPASS()], iif(c==1, i64_ax(0,0xFF0000), i64_ax(0xFF00,0)) );
        return  i64_and( g_pcaps[1+c][1+bit.bor(x,128)], i64_or(g_colorb[1+bit.bxor(c,1)], b ));
      end

      function RANK(x,y)
        return ( bit.band(x,0x38) == y );
      end

      function TEST(f,b)
        return i64_nz( i64_and( g_BITi[1+f], b) );
      end

      function g_ENPASS()
        return bit.band(g_flags, 63);
      end

      function CASTLE()
        return bit.band(g_flags, 960);
      end

      function COUNT()
        return bit.band(g_count, 0x3FF);
      end

      function BOARD()
        return i64_or(g_colorb[1+0], g_colorb[1+1]);
      end

      function RQU()
        return i64_or(g_pieceb[1+g_QUEEN], g_pieceb[1+g_ROOK]);
      end

      function BQU()
        return i64_or(g_pieceb[1+g_QUEEN], g_pieceb[1+g_BISHOP]);
      end

      function getLowestBit(bb)
        return i64_and( bb, i64_neg(bb) );
      end

      function _getpiece(s,c)

        local i=0, p;
        while(i<8) do
          p = g_pieceChar[1+i];
          if (p == s) then

            c[1+0] = 0;
            return i;

          else

            if (p == string.upper(s)) then

              c[1+0] = 1;
              return i;

            end

          end
          i = i+1;

        end

        return 0;
      end

      function parseInt(s)

        if((string.len(s)==0) or string.find("0123456789-.", string.sub(s,1,1))==nil ) then

          return 0;

        else

          return tonumber(s);

        end
      end

      function nextToken(str,tok)

        local j = 0;
        local s = str;
        local r = "";
        while(j<=tok) do

          i = string.find(s," ")
          if(i==nil) then

            r = s; break;
          end

          r = string.sub(s,1,i-1);
          s = string.sub(s,i+1);
          j = j+1;

        end
        return r;
      end

      function printboard()

        local b = "";
        local s = "";
        local i = 0;
        local k = 0;
        local c = "";
        while(i<64) do
          c = ".";
          k = 0;
          while(k<8) do
            if( i64_nz( i64_and( g_pieceb[1+k], g_BITi[1+i] ) ) ) then
              c = g_pieceChar[1+k];
              if( i64_is0( i64_and( g_colorb[1+0] , g_BITi[1+i] ) ) ) then
                c = string.lower(c);
              end
            end
            k = k+1;
          end

          s = s..c;

          i = i+1;
          if( i % 8 == 0 ) then
            b = s .. "\n" .. b;
            s = "";
          end

        end

        print(b);
      end


      function _parse_fen(fen)

        local col = 0;
        local row = 7;
        local s = "";
        local s2 = "";
        local p = 0;
        local cp = {0};
        local t = 0;
        local bo = i64(0);
        local i = 0;
        local j = 0;

        i = 0;
        while(i < 8 ) do
          g_pieceb[1+i] = i64(0);
          i = i+1;
        end

        i = 0;
        while(i < 2 ) do
          g_colorb[1+i] = i64(0);
          g_kingpos[1+i] = -1;
          i = i+1;
        end

        i = 0;
        while(i < 64) do
          g_p_v[1+i] = {};
          g_movelist[1+i] = {};

          j = 0;
          while(j < 256) do
            g_p_v[1+i][1+j] = 0;
            g_movelist[1+i][1+j] = 0;
            j = j+1;
          end

          g_movenum[1+i] = 0;
          g_pvlength[1+i] = 0;
          g_kvalue[1+i] = 0;

          g_crevoke[1+i] = 0x3FF;

          i = i+1;
        end

        g_hashDB = {};
        g_hashb = i64(0);
        g_mstack = {};

        g_mat_ = 0;

        local pos = nextToken(fen,0);
        local mv = string.sub(nextToken(fen,1),1,1);
        local cas = nextToken(fen,2);
        local enps = nextToken(fen,3);
        local halfm = parseInt(nextToken(fen,4));
        local fullm = parseInt(nextToken(fen,5));

        i = 0;
        while(i < string.len(pos)) do

          s = string.sub(pos,1+i,1+i);
          if (s == "/") then

            row = row - 1;
            col = 0;

          else

            if (s >= "1"  and  s <= "8") then

              col = col + (string.byte(s,1) - string.byte("0",1));

            else

              p = _getpiece(s, cp);

              c = cp[1+0];

              if (p == g_KING) then

                g_kingpos[1+c] = (row*8) + col;

              else

                g_mat_ = g_mat_ + iif(c == 1, -g_pval[1+p], g_pval[1+p]);
              end

              t = bit.bor(col, bit.lshift(row, 3));
              t = bit.bor(t, bit.lshift(i, 6));
              t = bit.bor(t, iif(c == 1, 512, 0));

              bo = g_BITi[1+(row*8) + col];

              g_hashb = i64_xor( g_hashb, g_hashxor[1+t] );

              g_pieceb[1+p] = i64_or( g_pieceb[1+p], bo );
              g_colorb[1+c] = i64_or( g_colorb[1+c], bo );
              col = col+1;

            end
          end

          i = i+1;
        end

        g_onmove = iif( mv == "b", 1, 0 );

        g_flags = 0;
        i = 0;
        while(i < string.len(cas)) do

          s = string.sub(cas,1+i,1+i);
          if (s == "K") then
            g_flags = bit.bor( g_flags, g_BITi[1+6].l );
          end
          if (s == "k") then
            g_flags = bit.bor( g_flags, g_BITi[1+7].l );
          end
          if (s == "Q") then
            g_flags = bit.bor( g_flags, g_BITi[1+8].l );
          end
          if (s == "q") then
            g_flags = bit.bor( g_flags, g_BITi[1+9].l );
          end

          i = i+1;
        end

        s = string.sub(enps,1,1);
        s2 = string.sub(enps,2,2);
        if (s >= "a"  and  s <= "h"  and  s2 >= "1"  and  s2 <= "8") then

          t=(8*(string.byte(s2,1) - string.byte("1",1)));
          t=t+(string.byte(s,1) - string.byte("a",1));
          g_flags = bit.bor( g_flags, t );

        end

        g_count = ((fullm - 1)*2) + g_onmove + bit.lshift(halfm, 10);

        i = 0;
        while( i < COUNT() ) do

          g_hstack[1+i] = i64(0);
          i = i+1;
        end
      end

      function _startpos()

        _parse_fen(g_sfen);

        g_engine = 1;
      end

      function LOW16(x)
        return bit.band(x, 0xFFFF);
      end


      function _rand_32()

        g_r_x = i64u((g_r_x*69069) + 1);
        g_r_y = bit.bxor( g_r_y, bit.lshift(g_r_y, 13) );
        g_r_y = bit.bxor( g_r_y, bit.rshift(g_r_y, 17) );
        g_r_y = bit.bxor( g_r_y, bit.lshift(g_r_y, 5) );
        g_r_y = i64u(g_r_y);

        local t = i64u( bit.lshift(g_r_w,1) ) + g_r_z + g_r_carry;
        g_r_carry = i64u( bit.rshift( bit.rshift(g_r_z ,2) + bit.rshift(g_r_w, 3) + bit.rshift(g_r_carry, 2), 30 ) );
        g_r_z = g_r_w;
        g_r_w = i64u(t);
        return i64u(g_r_x + g_r_y + g_r_w);
      end

      function _rand_64()
        return i64_ax( _rand_32(), _rand_32() );
      end


      function getg_LSB(bm)

        local n = bm.l;

        if (n ~= 0) then

          if (LOW16(n) ~= 0) then

            return g_LSB[1+LOW16(n)];

          else

            return bit.bor(16, g_LSB[1+LOW16( bit.rshift(n,16) )]);
          end

        else

          n = bm.h;
          if (LOW16(n) ~= 0) then

            return bit.bor(32, g_LSB[1+LOW16(n)]);

          else

            return bit.bor(48, g_LSB[1+LOW16( bit.rshift(n,16) )]);
          end
        end
      end


      function _slow_g_LSB(b)

        local k = -1;
        local b1 = b;

        while ( b1 ~= 0 ) do

          k = k+1;
          if ( bit.band(b1,1) ~=0 ) then
            break;
          end

          b1 = bit.rshift(b1, 1);

        end
        return k;
      end

      function _g_BITCnt(b)

        local c = 0;
        local b1 = b;

        while ( b1 ~= 0 ) do

          b1 = bit.band( b1, b1-1 );
          c = c+1;
        end
        return c;
      end


      function g_BITCnt(n)
        local t = g_BITC[1+LOW16(n.l)] + g_BITC[1+LOW16( bit.rshift(n.l,16) )];
        return t+( g_BITC[1+LOW16(n.h)] + g_BITC[1+LOW16( bit.rshift(n.h,16) )] );
      end

      function identPiece(f)

        if (TEST(f, g_pieceb[1+g_PAWN])) then
          return g_PAWN;
        end
        if (TEST(f, g_pieceb[1+g_KNIGHT])) then
          return g_KNIGHT;
        end
        if (TEST(f, g_pieceb[1+g_BISHOP])) then
          return g_BISHOP;
        end
        if (TEST(f, g_pieceb[1+g_ROOK])) then
          return g_ROOK;
        end
        if (TEST(f, g_pieceb[1+g_QUEEN])) then
          return g_QUEEN;
        end
        if (TEST(f, g_pieceb[1+g_KING])) then
          return g_KING;
        end
        return g_ENP;
      end

      function key000(b,f)
        local a = i64_rshift( b, bit.band(f, 56) );
        return bit.band( a.l , 0x7E);
      end

      function key090(b,f)
        local a = i64_rshift( b, bit.band(f,7) );
        local L = a.l;
        local H = bit.lshift( a.h, 1 );
        L = bit.bor(bit.band(L, 0x1010101) , bit.band( H, 0x2020202));
        L = bit.bor(bit.band(L, 0x303) , bit.band(bit.rshift(L, 14), 0xC0C));
        return bit.bor(bit.band(L, 0xE) , bit.band(bit.rshift(L, 4), 0x70));
      end

      function keyDiag(b)
        local L = bit.bor(b.l , b.h);
        L = bit.bor(L, bit.rshift(L,16));
        L = bit.bor(L, bit.rshift(L,8));
        return bit.band(L, 0x7E);
      end

      function key045(b,f)
        return keyDiag( i64_and(b, g_bmask45[1+f]) );
      end

      function key135(b,f)
        return keyDiag( i64_and(b, g_bmask135[1+f]) );
      end

      function DUALATT(x,y,c)
        return (battacked(x, c)  or  battacked(y, c));
      end

      function battacked(f,c)

        if ( i64_nz( i64_and(PCAP(f, c) , g_pieceb[1+g_PAWN]) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(NCAP(f, c) , g_pieceb[1+g_KNIGHT]) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(KCAP(f, c) , g_pieceb[1+g_KING]) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(RCAP1(f, c) , RQU()) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(RCAP2(f, c) , RQU()) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(BCAP3(f, c) , BQU()) ) ) then
          return true;
        end
        if ( i64_nz( i64_and(BCAP4(f, c) , BQU()) ) ) then
          return true;
        end
        return false;
      end

      function reach(f,c)
        local t = i64_and( NCAP(f, c) , g_pieceb[1+g_KNIGHT] );
        t = i64_or( t, i64_and( RCAP1(f, c) , RQU()) );
        t = i64_or( t, i64_and( RCAP2(f, c) , RQU()) );
        t = i64_or( t, i64_and( BCAP3(f, c) , BQU()) );
        return i64_or( t, i64_and( BCAP4(f, c) , BQU()) );
      end

      function  attacked(f,c)
        return i64_or( i64_and(PCAP(f, c) , g_pieceb[1+g_PAWN] ) , reach(f, c) );
      end

      function _init_pawns(moves,caps,freep,filep,helpp,c)

        local rank = 0;
        local file = 0;
        local jrank = 0;
        local jfile = 0;
        local dfile = 0;
        local m = 0;
        local n = 0;
        local j = 0;
        local i = -1;

        while(i < 63) do

          i = i+1;

          moves[1+i] = i64(0);
          caps[1+i] = i64(0);
          freep[1+i] = i64(0);
          filep[1+i] = i64(0);
          helpp[1+i] = i64(0);


          rank = math.floor(i/8);
          file = bit.band( i, 7 );
          m = i + iif(c == 1, -8, 8);
          g_pawnprg[1+c][1+i] = g_pawnrun[1+ iif(c == 1, 7-rank, rank ) ];

          j = -1;
          while(j < 63) do

            j = j+1;

            jrank = math.floor(j/8);
            jfile = bit.band( j, 7 );
            dfile = (jfile - file)*(jfile - file);

            if (dfile <= 1) then

             if ((c == 1  and  jrank < rank)  or  (c == 0  and  jrank > rank)) then

              --The not touched half of the pawn

              if (dfile == 0) then
                filep[1+i] = i64_or( filep[1+i], g_BITi[1+j] );
              end

              freep[1+i] = i64_or( freep[1+i], g_BITi[1+j] );

             else

              if ((dfile ~= 0)  and ((jrank - rank)*(jrank - rank) <= 1)) then
                helpp[1+i] = i64_or( helpp[1+i], g_BITi[1+j] );
              end

             end

            end

          end

          if (m >= 0  and  m <= 63) then

           moves[1+i] = i64_or( moves[1+i], g_BITi[1+m] );

           if (file > 0) then

            m = i + iif(c == 1, -9, 7);
            if (m >= 0  and  m <= 63) then

             caps[1+i] = i64_or( caps[1+i], g_BITi[1+m] );

             n = i + (64*(2 - c));
             caps[1+n] = i64_or( caps[1+n], g_BITi[1+m] );

            end

           end

           if ((m >= 0  and  m <= 63) and (file < 7)) then

            m = i + iif(c == 1, -7, 9);
            if (m >= 0  and  m <= 63) then

             caps[1+i] = i64_or( caps[1+i], g_BITi[1+m] );

             n = i + (64*(c + 1));
             caps[1+n] = i64_or( caps[1+n], g_BITi[1+m] );

            end

           end

          end

        end

      end

      function _init_shorts(moves,m)


        local j = 0;
        local i = 0;
        local n = 0;
        local q = 0;

        while( i < 64 ) do

          j = 0;
          while( j < 8 ) do

            n = i + m[1+j];
            if (n < 64  and  n >= 0) then

              q=(bit.band(n,7)-bit.band(i,7));

              if((q*q) <= 4) then

                moves[1+i] = i64_or( moves[1+i], g_BITi[1+n] );
              end

            end

            j = j+1;
          end

          i = i+1;
        end
      end

      function _occ_free_board(bc,dl,fr)

        local fr1 = i64_clone(fr);
        local perm = i64_clone(fr);
        local i = 0;
        local low = i64(0);
        local nlow = i64(0);

        while( i < bc ) do

          low = getLowestBit(fr1);
	  local l1 = i64_toString(low)

          nlow = i64_not(low);
          local n1 = i64_toString(nlow)

	  fr1 = i64_and( fr1, nlow );

	  local fr9 = i64_toString(fr1)


          if (not TEST(i, dl)) then
            perm = i64_and( perm, nlow );
		local p9 = i64_toString(perm)
          end

          i = i+1;
        end

        return perm;
      end

      function _init_g_rays1()

        local f = 0;
        local mmask=i64(0);
        local bc=0;
        local iperm=i64(0);
        local board=i64(0);
        local move=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local index=i64(0);
        local k = 0;
        local i = 0;

        while( f < 64 ) do

          mmask = i64_or( _rook0(f, g_0, 0) , g_BITi[1+f] );
          bc = g_BITCnt(mmask);
          iperm = bit.lshift( 1, bc );

          i = 0;
          while( i < iperm  ) do

            board = _occ_free_board(bc, i64(i), mmask);
            move = _rook0(f, board, 1);
            occ = _rook0(f, board, 2);
            xray = _rook0(f, board, 3);
            index = key000(board, f);
            k = bit.lshift(f,7) + index;
            g_rays[1+k] = i64_or( occ , move );
            g_rays[1+k + 0x8000] = xray;

            i = i+1;

          end

          f = f+1;
        end
      end

      function _init_g_rays2()

        local f = 0;
        local mmask=i64(0);
        local bc=0;
        local iperm=0;
        local board=i64(0);
        local move=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local index=i64(0);
        local k = 0;
        local i = 0;

        while( f < 64 ) do

          mmask = i64_or( _rook90(f, g_0, 0) , g_BITi[1+f] );
          bc = g_BITCnt(mmask);
          iperm = bit.lshift( 1, bc );

          i = 0;
          while( i < iperm ) do

            board = _occ_free_board(bc, i64(i), mmask);
            move = _rook90(f, board, 1);
            occ = _rook90(f, board, 2);
            xray = _rook90(f, board, 3);
            index = key090(board, f);
            k = bit.lshift(f,7) + index + 0x2000;
            g_rays[1+k] = i64_or( occ , move );
            g_rays[1+k + 0x8000] = xray;
            i = i+1;
          end

          f = f+1;
        end
      end

      function _init_g_rays3()

        local f = 0;
        local mmask=i64(0);
        local bc=0;
        local iperm=0;
        local board=i64(0);
        local move=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local index=i64(0);
        local k = 0;
        local i = 0;

        while( f < 64 ) do

          mmask = i64_or( _bishop45(f, g_0, 0) , g_BITi[1+f] );
          bc = g_BITCnt(mmask);
          iperm = bit.lshift( 1, bc );

          i = 0;
          while( i < iperm ) do

            board = _occ_free_board(bc, i64(i), mmask);
            move = _bishop45(f, board, 1);
            occ = _bishop45(f, board, 2);
            xray = _bishop45(f, board, 3);
            index = key045(board, f);
            k = bit.lshift(f,7) + index + 0x4000;
            g_rays[1+k] = i64_or( occ , move );
            g_rays[1+k + 0x8000] = xray;
            i = i+1;
          end

          f = f+1;
        end
      end

      function _init_g_rays4()

        local f = 0;
        local mmask=i64(0);
        local bc=0;
        local iperm=0;
        local board=i64(0);
        local move=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local index=i64(0);
        local k = 0;
        local i = 0;

        while( f < 64 ) do

          mmask = i64_or( _bishop135(f, g_0, 0) , g_BITi[1+f] );
          bc = g_BITCnt(mmask);
          iperm = bit.lshift( 1, bc );

          i = 0;
          while( i < iperm ) do

            board = _occ_free_board(bc, i64(i), mmask);
            move = _bishop135(f, board, 1);
            occ = _bishop135(f, board, 2);
            xray = _bishop135(f, board, 3);
            index = key135(board, f);
            k = bit.lshift(f,7) + index + 0x6000;
            g_rays[1+k] = i64_or( occ , move );
            g_rays[1+k + 0x8000] = xray;

            i = i+1;
          end

          f = f+1;
        end
      end

      function _rook0(f, board, t)

        local fr=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local b = 0;
        local i = f+1;

        while( (i < 64)  and  (i%8 ~= 0) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i+1;
        end

        b = 0;
        i = f-1;
        while( (i >= 0)  and  (i%8 ~= 7) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i-1;
        end

        return iif( (t < 2), fr, iif(t == 2, occ, xray) );
      end

      function _rook90(f,board,t)

        local fr=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local b = 0;
        local i = f-8;

        while( i >= 0 ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i-8;
        end

        b = 0;
        i = f+8;
        while( i < 64 ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i+8;
        end

        return iif( (t < 2), fr, iif(t == 2, occ, xray) );
      end

      function _bishop45(f,board,t)

        local fr=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local b = 0;
        local i = f+9;

        while( (i < 64)  and  (i%8 ~= 0) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i+9;
        end

        b = 0;
        i = f-9;
        while( (i >= 0)  and  (i%8 ~= 7) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i-9;
        end

        return iif( (t < 2), fr, iif(t == 2, occ, xray) );
      end

      function _bishop135(f,board,t)

        local fr=i64(0);
        local occ=i64(0);
        local xray=i64(0);
        local b = 0;
        local i = f-7;

        while( (i >= 0)  and  (i%8 ~= 0) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i-7;
        end

        b = 0;
        i = f+7;
        while( (i < 64)  and  (i%8 ~= 7) ) do

          if (TEST(i, board)) then

            if (b ~= 0) then

              xray = i64_or( xray, g_BITi[1+i] );
              break;

            else

              occ = i64_or( occ, g_BITi[1+i] );
              b = 1;

            end
          end

          if (b == 0) then
            fr = i64_or( fr, g_BITi[1+i] );
          end

          i = i+7;
        end

        return iif( (t < 2), fr, iif(t == 2, occ, xray) );
      end

      function displaym(m)
        print(mvstr(m,false));
      end

      function piece_S(p)
        return iif(p==g_PAWN, "", g_pieceChar[1+p]);
      end

      function mvstr(m,l)
        local s = "";
        local p = 0;
        local c = "";
        if(l) then
          s = s..piece_S(PIECE(m));
        end
        s = s..string.char(string.byte("a",1) + (FROM(m) % 8));
        s = s..string.char(string.byte("1",1) + math.floor(FROM(m)/8));
        if(l) then
          s = s..iif(CAP(m)>0,"x","-");
        end
        s = s..string.char(string.byte("a",1) + (TO(m) % 8));
        s = s..string.char(string.byte("1",1) + math.floor(TO(m)/8));
        if(PROM(m) ~= 0) then
          if(l) then
            s = s.."="..piece_S(PROM(m));
          else
            s = s..string.lower( piece_S(PROM(m)) );
          end
        end
        return s;
      end

      function errprint(s)
        print("error: "..s);
      end

      function displaypv()

        local s = "";
        local i = 0;

        while( i < g_pvlength[1+0] ) do
          s = s..mvstr(g_p_v[1+0][1+i]).." ";
          i = i+1;
        end

        print(s);
      end

      function ig_sdraw(hp,nrep)

        local c = 0;
        local n = 0;
        local i = 0;

        if (g_count > 0xFFF) then

          --fifty > 3
          --100 plies

          if (g_count >= (0x400)*100) then
            return 2;
          end

          i = COUNT();
          n = i - bit.rshift(g_count, 10);
          i = i - 2;
          while (i >= n) do

            c = c+1;
            if ( (i>0) and i64_eq( g_hstack[1+i], hp) and (c == nrep)) then
              return 1;
            end

            i = i-1;
          end

        else
          if ( i64_is0( i64_or(g_pieceb[1+g_PAWN] , RQU()) ) ) then

            --Check for mating material
            if ( (g_BITCnt(g_colorb[1+0]) <= 2)  and  (g_BITCnt(g_colorb[1+1]) <= 2) ) then
              return 3;
            end
          end
        end

        return 0;
      end

      function pinnedPieces(f,oc)

        local b=i64(0);
        local pin=i64(0);
        local t = 0;

        b = i64_and( i64_and( i64_or(RXRAY1(f) , RXRAY2(f)) , g_colorb[1+oc]) , RQU() );
        while ( i64_nz( b ) ) do

          t = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+t] );
          pin = i64_or( pin, i64_and( RCAP(t, oc) , ROCC(f) ) );

        end

        b = i64_and( i64_and( i64_or(BXRAY3(f) , BXRAY4(f)) , g_colorb[1+oc]) , BQU() );

        while ( i64_nz( b ) ) do

          t = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+t] );
          pin = i64_or( pin, i64_and( BCAP(t, oc) , BOCC(f) ) );

        end

        return pin;
      end

      function getDir(f,t)

        if ( bit.band( bit.bxor(f,t), 56) == 0) then
          return 8;
        end

        if ( bit.band( bit.bxor(f,t), 7) == 0) then
          return 16;
        end

        return iif(((f - t) % 7) ~= 0, 32, 64);
      end

      -- move is both makeMove and unmakeMove,
      -- only for unmakeMove the flags have to be restored (counter, castle, enpass...)

      function move(m,c)

        local f = FROM(m);
        local t = TO(m);
        local p = PIECE(m);
        local a = CAP(m);
        local q = 0;
        local c1=bit.bxor(c,1);
        local t56 = 0;
        local w = 0;
        local x = 0;

        g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+f] );
        g_pieceb[1+p] = i64_xor( g_pieceb[1+p], g_BITi[1+f] );

        g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+t] );
        g_pieceb[1+p] = i64_xor( g_pieceb[1+p], g_BITi[1+t] );


        q = bit.bor( bit.lshift(p,6) , bit.lshift(c,9) );
        g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(f,q)] );
        g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(t,q)] );

        g_flags = bit.band( g_flags, 960 );
        g_count = g_count + 0x401;
        if (a ~= 0) then

          if (a == g_ENP) then

            -- Enpassant Capture
            t = bit.bor( bit.band(t,7) , bit.band(f,56) );
            a = g_PAWN;

          else

            if ((a == g_ROOK) and (CASTLE() ~= 0)) then

               --Revoke castling rights
               g_flags = bit.band( g_flags, g_crevoke[1+t] );
            end

          end

          g_pieceb[1+a] = i64_xor( g_pieceb[1+a], g_BITi[1+t] );
          g_colorb[1+c1] = i64_xor( g_colorb[1+c1], g_BITi[1+t] );

          q = bit.bor( bit.lshift(a,6) , bit.lshift(c1,9) );

          g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(t,q)] );

          --Reset Fifty g_counter
          g_count = bit.band( g_count, 0x3FF );

          x = g_pval[1+a];
          g_mat_ = g_mat_ + iif(c == 1, -x, x );
        end

        if (p == g_PAWN) then

          if (bit.band(bit.bxor(f,t),8) == 0) then
            g_flags = bit.bor( g_flags, bit.bxor(f,24) );
            --Enpassant
          else
            t56 = bit.band(t,56);
            if( (t56==0)  or  (t56==56) ) then

              g_pieceb[1+g_PAWN] = i64_xor( g_pieceb[1+g_PAWN], g_BITi[1+t] );
              w = PROM(m);
              g_pieceb[1+w] = i64_xor( g_pieceb[1+w], g_BITi[1+t] );

              q = bit.bor( bit.lshift(g_PAWN,6) , bit.lshift(c,9) );
              g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(t,q)] );
              q = bit.bor( bit.lshift(w,6) , bit.lshift(c,9) );
              g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(t,q)] );

              x = -g_pval[1+g_PAWN] + g_pval[1+w];
              g_mat_ = g_mat_ + iif(c == 1, -x, x );
            end
          end

          --Reset Fifty g_counter
          g_count = bit.band( g_count, 0x3FF );

        else
          if (p == g_KING) then

            if (g_kingpos[1+c] == f) then
              g_kingpos[1+c] = t;
            else
              g_kingpos[1+c] = f;
            end

            -- Lose castling rights
            g_flags = bit.band( g_flags, bit.bnot( bit.lshift(320,c) ) );

            if (bit.band(bit.bxor(f,t),3) == 2) then

                  -- Castle
              if (t == 6) then
                f = 7; t = 5;
              else
                if (t == 2) then
                  f = 0; t = 3;
                else
                  if (t == 62) then
                    f = 63; t = 61;
                  else
                    f = 56; t = 59;
                  end
                end
              end

              g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+f] );
              g_pieceb[1+g_ROOK] = i64_xor( g_pieceb[1+g_ROOK], g_BITi[1+f] );

              g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+t] );
              g_pieceb[1+g_ROOK] = i64_xor( g_pieceb[1+g_ROOK], g_BITi[1+t] );

              q = bit.bor( bit.lshift(g_ROOK,6) , bit.lshift(c,9) );
              g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(f,q)] );
              g_hashb = i64_xor( g_hashb, g_hashxor[1+bit.bor(t,q)] );

            end
          else
            if ((p == g_ROOK)  and  (CASTLE() ~= 0)) then
              g_flags = bit.band( g_flags, g_crevoke[1+f] );
            end
          end
        end
      end

      function doMove(m,c)
        local obj={};
        obj.count = g_count;
        obj.flags = g_flags;
        obj.mat = g_mat_;
        obj.move = m;
        g_mstack[1+COUNT()] = obj;
        move(m, c);
      end

      function undoMove(m,c)
        local obj = g_mstack[1+COUNT() - 1];
        if(m==nil) then
          m = obj.move;
        end
        move(m, c);
        g_count = obj.count;
        g_flags = obj.flags;
        g_mat_ = obj.mat;
      end

      function registerCaps(m,bc,mlist,mn)

        local t = 0;
        local bc1=i64_clone(bc);
        local n = 0;

        while ( i64_nz( bc1 ) ) do

          t = getg_LSB(bc1);
          bc1 = i64_xor( bc1, g_BITi[1+t] );
          n = mn[1+0];
          mlist[1+n] = bit.bor( m , bit.bor( _TO(t) , _CAP(identPiece(t)) ) );
          mn[1+0] = n+1;

        end
      end

      function registerMoves(m,bc,bm,mlist,mn)

        local t = 0;
        local bc1=i64_clone(bc);
        local bm1=i64_clone(bm);
        local n = 0;

        while ( i64_nz( bc1 ) ) do

          t = getg_LSB(bc1);
          bc1 = i64_xor( bc1, g_BITi[1+t] );
          n = mn[1+0];
          mlist[1+n] = bit.bor( m , bit.bor( _TO(t) , _CAP(identPiece(t)) ) );
          mn[1+0] = n+1;

        end

        while ( i64_nz( bm1 ) ) do

          t = getg_LSB(bm1);
          bm1 = i64_xor( bm1, g_BITi[1+t] );
          n = mn[1+0];
          mlist[1+n] = bit.bor( m , _TO(t) );
          mn[1+0] = n+1;

        end

      end

      function registerProms(f,c,bc,bm,mlist,mn)

        local t = 0;
        local bc1=i64_clone(bc);
        local bm1=i64_clone(bm);
        local m = 0;
        local n = 0;

        while ( i64_nz( bc1 ) ) do

          t = getg_LSB(bc1);
          bc1 = i64_xor( bc1, g_BITi[1+t] );

          m = bit.bor( f, _ONMV(c) );
          m = bit.bor( m, _PIECE(g_PAWN) );
          m = bit.bor( m, _TO(t) );
          m = bit.bor( m, _CAP(identPiece(t)) );

          n = mn[1+0];
          mlist[1+n] = bit.bor( m , _PROM(g_QUEEN) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_KNIGHT) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_ROOK) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_BISHOP) );
          n = n + 1;
          mn[1+0] = n;

        end

        while ( i64_nz( bm1 ) ) do

          t = getg_LSB(bm1);
          bm1 = i64_xor( bm1, g_BITi[1+t] );

          m = bit.bor( f, _ONMV(c) );
          m = bit.bor( m, _PIECE(g_PAWN) );
          m = bit.bor( m, _TO(t) );

          n = mn[1+0];
          mlist[1+n] = bit.bor( m , _PROM(g_QUEEN) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_KNIGHT) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_ROOK) );
          n = n + 1;
          mlist[1+n] = bit.bor( m , _PROM(g_BISHOP) );
          n = n + 1;
          mn[1+0] = n;

        end

      end

      function registerKing(m,bc,bm,mlist,mn,c)

        local t = 0;
        local bc1=i64_clone(bc);
        local bm1=i64_clone(bm);
        local n = 0;

        while ( i64_nz( bc1 ) ) do

          t = getg_LSB(bc1);
          bc1 = i64_xor( bc1, g_BITi[1+t] );

          if (not battacked(t, c)) then

            n = mn[1+0];
            mlist[1+n] = bit.bor( m , bit.bor( _TO(t) , _CAP(identPiece(t)) ) );
            mn[1+0] = n+1;

          end

        end

        while ( i64_nz( bm1 ) ) do

          t = getg_LSB(bm1);
          bm1 = i64_xor( bm1, g_BITi[1+t] );

          if (not battacked(t, c)) then

            n = mn[1+0];
            mlist[1+n] = bit.bor( m , _TO(t) );
            mn[1+0] = n+1;

          end
        end

      end

      function generateCheckEsc(ch,apin,c,k,ml,mn)

        local bf = 0;
        local cf = 0;
        local cc=i64(0);
        local fl=i64(0);
        local ww=i64(0);
        local p = 0;
        local d = 0;
        local f = 0;
        local c1=bit.bxor(c,1);

        bf = g_BITCnt(ch);
        g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+k] );

        registerKing(PREMOVE(k, g_KING, c), KCAP(k, c), KMOVE(k), ml, mn, c);

        g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+k] );

        --Doublecheck:
        if (bf > 1) then
          return bf;
        end

        bf = getg_LSB(ch);

        --Can we capture the checker?
        cc = i64_and( attacked(bf, c1), apin );

        while ( i64_nz( cc ) ) do

          cf = getg_LSB(cc);
          cc = i64_xor( cc, g_BITi[1+cf] );
          p = identPiece(cf);
          if ((p == g_PAWN)  and  RANK(cf, iif(c ~= 0, 0x08, 0x30) )) then

            registerProms(cf, c, ch, g_0, ml, mn);

          else

            registerMoves(PREMOVE(cf, p, c), ch, g_0, ml, mn);

          end

        end

        if ((g_ENPASS() ~= 0) and i64_nz( i64_and(ch, g_pieceb[1+g_PAWN]) ) ) then

          --Enpassant capture of attacking Pawn
          cc = i64_and( i64_and( PCAP(g_ENPASS(), c1) , g_pieceb[1+g_PAWN] ), apin );
          while ( i64_nz( cc ) ) do

            cf = getg_LSB(cc);
            cc = i64_xor( cc, g_BITi[1+cf] );
            registerMoves(PREMOVE(cf, g_PAWN, c), g_BITi[1+g_ENPASS()], g_0, ml, mn);
          end
        end

        if ( i64_nz(i64_and(ch, i64_or(g_nmoves[1+k], g_kmoves[1+k])) ) ) then
          --We can not move anything between!
          return 1;
        end

        d = getDir(bf, k);
        if (bit.band(d, 8) ~= 0) then
          fl = i64_and( RMOVE1(bf) , RMOVE1(k) );
        else
          if (bit.band(d, 16) ~= 0) then
            fl = i64_and( RMOVE2(bf) , RMOVE2(k) );
          else
            if (bit.band(d, 32) ~= 0) then
              fl = i64_and( BMOVE3(bf) , BMOVE3(k) );
            else
              fl = i64_and( BMOVE4(bf) , BMOVE4(k) );
            end
          end
        end

        while ( i64_nz( fl ) ) do

          f = getg_LSB(fl);
          fl = i64_xor( fl, g_BITi[1+f] );

          cc = i64_and( reach(f, c1), apin );
          while ( i64_nz( cc ) ) do

            cf = getg_LSB(cc);
            cc = i64_xor( cc, g_BITi[1+cf] );
            p = identPiece(cf);
            registerMoves(PREMOVE(cf, p, c), g_0, g_BITi[1+f], ml, mn);

          end

          bf = iif(c ~= 0, f+8, f-8);
          if (bf >= 0  and  bf <= 63) then

           ww = i64_and( g_BITi[1+bf] , g_pieceb[1+g_PAWN] );
           ww = i64_and( ww , g_colorb[1+c] );
           ww = i64_and( ww , apin );

           if ( i64_nz( ww ) ) then

            if (RANK(bf, iif(c ~= 0, 0x08, 0x30) )) then
              registerProms(bf, c, g_0, g_BITi[1+f], ml, mn);
            else
              registerMoves(PREMOVE(bf, g_PAWN, c), g_0, g_BITi[1+f], ml, mn);
            end

           end

           if (RANK(f, iif(c ~= 0, 0x20, 0x18) )) then

            ww = i64_and( g_BITi[1+ iif(c ~= 0, f+16, f-16) ] , g_pieceb[1+g_PAWN] );
            ww = i64_and( ww , g_colorb[1+c] );
            ww = i64_and( ww , apin );
            if ( i64_nz( ww ) and i64_is0( i64_and( BOARD() , g_BITi[1+bf] ) ) ) then
              registerMoves(PREMOVE( iif(c ~= 0, f+16, f-16 ), g_PAWN, c), g_0, g_BITi[1+f], ml, mn);
            end

           end

          end

        end

        return 1;
      end

      function generateMoves(ch,c,ply)

        local ret = 0;
        local t = 0;
        local c1=bit.bxor(c,1);
        local f = g_kingpos[1+c];
        local cb = g_colorb[1+c];
        local pin = pinnedPieces(f, c1);
        local npin = i64_not(pin);
        local ml = g_movelist[1+ply];
        local mn = {0};
        local b=i64(0);
        local m=i64(0);
        local a=i64(0);
        local hh=i64(0);
        local clbd = 0;
        local b1=i64(0);
        local b2=i64(0);

        if ( i64_nz( ch ) ) then

          ret = generateCheckEsc(ch, npin, c, f, ml, mn);
          g_movenum[1+ply] = mn[1+0];
          return ret;

        end

        registerKing(PREMOVE(f, g_KING, c), KCAP(f, c), KMOVE(f), ml, mn, c);

        cb = i64_and( g_colorb[1+c] , npin );
        b = i64_and( g_pieceb[1+g_PAWN] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          m = PMOVE(f, c);
          a = PCAP(f, c);

          if ( i64_nz( m )  and  RANK(f, iif( c ~= 0, 0x30, 0x08) )) then
            m = i64_or( m, PMOVE( iif(c ~= 0, f-8, f+8), c) );
          end

          if (RANK(f, iif(c ~= 0, 0x08, 0x30) )) then

            registerProms(f, c, a, m, ml, mn);

          else

            if( (g_ENPASS() ~= 0)  and  i64_nz( i64_and(g_BITi[1+g_ENPASS()] , g_pcaps[1+c][1+f]) ) ) then

              clbd = bit.bxor( g_ENPASS(), 8 );
              g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+clbd] );
              hh = ROCC1(f);
              b1 = i64_and(hh, g_BITi[1+g_kingpos[1+c]]);
              b2 = i64_and( i64_and(hh, g_colorb[1+c1]), RQU() );
              if ( i64_is0( b1 ) or i64_is0( b2 ) ) then
                a = i64_or( a, g_BITi[1+g_ENPASS()] );
              end

              g_colorb[1+c] = i64_xor( g_colorb[1+c] , g_BITi[1+clbd] );

            end

            registerMoves(PREMOVE(f, g_PAWN, c), a, m, ml, mn);

          end

        end

        b = i64_and( pin, g_pieceb[1+g_PAWN] );
        while ( i64_nz( b ) ) do

         f = getg_LSB(b);
         b = i64_xor( b, g_BITi[1+f] );

         t = getDir(f, g_kingpos[1+c]);
         if ( bit.band(t,8) == 0) then

          m = i64(0);
          a = i64(0);
          if (bit.band(t, 16) ~= 0) then

            m = PMOVE(f, c);

            if ( i64_nz( m ) and RANK(f, iif( c ~= 0, 0x30, 0x08) )) then
              m = i64_or( m, PMOVE( iif(c ~= 0, f-8, f+8 ), c) );
            end

          else
            if (bit.band(t, 32) ~= 0) then
              a = PCA3(f, c);
            else
              a = PCA4(f, c);
            end

            if (RANK(f, iif(c ~= 0, 0x08, 0x30) )) then

              registerProms(f, c, a, m, ml, mn);

            else

              registerMoves(PREMOVE(f, g_PAWN, c), a, m, ml, mn);

            end

          end

         end

        end

        b = i64_and( g_pieceb[1+g_KNIGHT] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerMoves(PREMOVE(f, g_KNIGHT, c), NCAP(f, c), NMOVE(f), ml, mn);

        end


        b = i64_and( g_pieceb[1+g_ROOK] , cb );

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerMoves(PREMOVE(f, g_ROOK, c), RCAP(f, c), RMOVE(f), ml, mn);
          if ( (CASTLE() ~= 0)  and  i64_is0( ch ) ) then
            if (c ~= 0) then
              b1 = i64_and( RMOVE1(63) , g_BITi[1+61] );

              if ((bit.band(g_flags, 128) ~= 0)  and  (f == 63)  and i64_nz( b1 ) ) then
                if (not DUALATT(61, 62, c)) then
                  registerMoves(PREMOVE(60, g_KING, c), g_0, g_BITi[1+62], ml, mn);
                end
              end

              b1 = i64_and( RMOVE1(56) , g_BITi[1+59] );
              if ((bit.band(g_flags, 512) ~= 0)  and  (f == 56)  and i64_nz( b1 ) ) then
                if (not DUALATT(59, 58, c)) then
                  registerMoves(PREMOVE(60, g_KING, c), g_0, g_BITi[1+58], ml, mn);
                end
              end

            else

              b1 = i64_and( RMOVE1(7) , g_BITi[1+5] );
              if ((bit.band(g_flags, 64) ~= 0)  and  (f == 7)  and i64_nz( b1 ) ) then
                if (not DUALATT(5, 6, c)) then
                  registerMoves(PREMOVE(4, g_KING, c), g_0, g_BITi[1+6], ml, mn);
                end
              end

              b1 = i64_and( RMOVE1(0) , g_BITi[1+3] );
              if ((bit.band(g_flags, 256) ~= 0)  and  (f == 0)  and i64_nz( b1 )) then
                if (not DUALATT(3, 2, c)) then
                  registerMoves(PREMOVE(4, g_KING, c), g_0, g_BITi[1+2], ml, mn);
                end
              end
            end
          end
        end

        b = i64_and( g_pieceb[1+g_BISHOP] , cb );

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerMoves(PREMOVE(f, g_BISHOP, c), BCAP(f, c), BMOVE(f), ml, mn);

        end

        b = i64_and( g_pieceb[1+g_QUEEN] , cb );

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          b1 = i64_or( RCAP(f, c), BCAP(f,c) );
          b2 = i64_or( RMOVE(f), BMOVE(f) );
          registerMoves(PREMOVE(f, g_QUEEN, c), b1, b2, ml, mn);

        end

        b = i64_or( i64_or( g_pieceb[1+g_ROOK], g_pieceb[1+g_BISHOP] ), g_pieceb[1+g_QUEEN] );
        b = i64_and( pin, b );

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );

          p = identPiece(f);
          t = bit.bor( p, getDir(f, g_kingpos[1+c]) );

          if (bit.band(t,10) == 10) then
            registerMoves(PREMOVE(f, p, c), RCAP1(f, c), RMOVE1(f), ml, mn);
          end
          if (bit.band(t,18) == 18) then
            registerMoves(PREMOVE(f, p, c), RCAP2(f, c), RMOVE2(f), ml, mn);
          end
          if (bit.band(t,33) == 33) then
            registerMoves(PREMOVE(f, p, c), BCAP3(f, c), BMOVE3(f), ml, mn);
          end
          if (bit.band(t,65) == 65) then
            registerMoves(PREMOVE(f, p, c), BCAP4(f, c), BMOVE4(f), ml, mn);
          end

        end

        g_movenum[1+ply] = mn[1+0];
        return 0;
      end

      function generateCaps(ch,c,ply)

        local ret = 0;
        local t = 0;
	local p = 0;
        local f = g_kingpos[1+c]
        local cb = g_colorb[1+c];
        local c1=bit.bxor(c,1);
        local pin = pinnedPieces(f, c1);
        local npin = i64_not(pin);
        local ml = g_movelist[1+ply];
        local mn = {0}
        local b=i64(0);
        local m=i64(0);
        local a=i64(0);
        local clbd = 0;
        local b1=i64(0);
        local b2=i64(0);
        local hh=i64(0);

        if ( i64_nz( ch ) ) then

          ret = generateCheckEsc(ch, npin, c, f, ml, mn);
          g_movenum[1+ply] = mn[1+0];
          return ret;

        end

        registerKing(PREMOVE(f, g_KING, c), KCAP(f, c), g_0, ml, mn, c);

        cb = i64_and( g_colorb[1+c] , npin );
        b = i64_and( g_pieceb[1+g_PAWN] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );

          a = PCAP(f, c);
          if (RANK(f, iif(c ~= 0, 0x08, 0x30) )) then

            registerMoves( bit.bor( PREMOVE(f, g_PAWN, c) , _PROM(g_QUEEN) ), a, PMOVE(f, c), ml, mn);

          else

            if ((g_ENPASS() ~= 0)  and i64_nz( i64_and(g_BITi[1+g_ENPASS()] , g_pcaps[1+c][1+f]) ) ) then

              clbd = bit.bxor( g_ENPASS(), 8 );
              g_colorb[1+c] = i64_xor( g_colorb[1+c], g_BITi[1+clbd] );
              hh = ROCC1(f);


              b1 = i64_and(hh, g_BITi[1+g_kingpos[1+c]]);
              b2 = i64_and( i64_and(hh, g_colorb[1+c1]), RQU() );
              if ( i64_is0( b1 ) or i64_is0( b2 ) ) then
                a = i64_or( a, g_BITi[1+g_ENPASS()] );
              end


              g_colorb[1+c] = i64_xor( g_colorb[1+c] , g_BITi[1+clbd] );

            end

            registerCaps(PREMOVE(f, g_PAWN, c), a, ml, mn);

          end

        end

        b = i64_and( pin, g_pieceb[1+g_PAWN] );
        while ( i64_nz( b ) ) do

         f = getg_LSB(b);
         b = i64_xor( b, g_BITi[1+f] );

         t = getDir(f, g_kingpos[1+c])
         if (bit.band(t,8) == 0) then

          m = i64(0);
          a = i64(0);

          if (bit.band(t,16) ~= 0) then
            m = PMOVE(f, c);
          else
            if (bit.band(t,32) ~= 0) then
              a = PCA3(f, c);
            else
              a = PCA4(f, c);
            end
          end

          if (RANK(f, iif(c ~= 0, 0x08, 0x30) )) then

            registerMoves( bit.bor( PREMOVE(f, g_PAWN, c) , _PROM(g_QUEEN) ), a, m, ml, mn);

          else

            registerCaps(PREMOVE(f, g_PAWN, c), a, ml, mn);

          end

         end

        end

        b = i64_and( g_pieceb[1+g_KNIGHT] , cb );
        while ( i64_nz( b ) ) do


          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerCaps(PREMOVE(f, g_KNIGHT, c), NCAP(f, c), ml, mn);

        end


        b = i64_and( g_pieceb[1+g_BISHOP] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerCaps(PREMOVE(f, g_BISHOP, c), BCAP(f, c), ml, mn);

        end


        b = i64_and( g_pieceb[1+g_ROOK] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerCaps(PREMOVE(f, g_ROOK, c), RCAP(f, c), ml, mn);

        end


        b = i64_and( g_pieceb[1+g_QUEEN] , cb );
        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          registerCaps(PREMOVE(f, g_QUEEN, c), i64_or(RCAP(f, c) , BCAP(f,c)), ml, mn);

        end

        b = i64_or( i64_or( g_pieceb[1+g_ROOK], g_pieceb[1+g_BISHOP] ), g_pieceb[1+g_QUEEN] );
        b = i64_and( pin, b );

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          p = identPiece(f);
          t = bit.bor( p, getDir(f, g_kingpos[1+c]) );

          if (bit.band(t,10) == 10) then
            registerCaps(PREMOVE(f, p, c), RCAP1(f, c), ml, mn)
          end
          if (bit.band(t,18) == 18) then
            registerCaps(PREMOVE(f, p, c), RCAP2(f, c), ml, mn)
          end
          if (bit.band(t,33) == 33) then
            registerCaps(PREMOVE(f, p, c), BCAP3(f, c), ml, mn)
          end
          if (bit.band(t,65) == 65) then
            registerCaps(PREMOVE(f, p, c), BCAP4(f, c), ml, mn)
          end

        end

        g_movenum[1+ply] = mn[1+0];
        return 0;
      end

      --SEE Stuff
      function swap(m)

        local k_list = {} --[0 for x in range(32)]

        local f = FROM(m);
        local t = TO(m);
        local onmv = ONMV(m);
        local a_piece = g_pval[1+CAP(m)];
        local piece = PIECE(m)
        local c = bit.bxor( onmv,1 );
        local nc = 1;
        local d = 0;
        local temp = i64(0);
        local b1 = i64(0);
        local colstore0 = i64_clone( g_colorb[1+0] );
        local colstore1 = i64_clone( g_colorb[1+1] );

        local attacks = i64_or( attacked(t, 0) , attacked(t, 1) );

        k_list[1+0] = a_piece;
        a_piece = g_pval[1+piece];
        g_colorb[1+onmv] = i64_xor( g_colorb[1+onmv], g_BITi[1+f] );
        if ((bit.band(piece,4) ~= 0)  or  (piece == 1)) then

          d = getDir(f, t);
          if (d == 32  or  d == 64) then
            attacks = i64_or( attacks, i64_and( BOCC(t) , BQU() ) );
          end
          if (d == 8  or  d == 16) then
            attacks = i64_or( attacks, i64_and( ROCC(t) , RQU() ) );
          end

        end

        attacks = i64_and( attacks, BOARD() );

        while ( i64_nz( attacks ) ) do

          b1=i64_and( g_colorb[1+c] , attacks );

          temp = i64_and( g_pieceb[1+g_PAWN], b1 );
          if (i64_nz( temp )) then
            piece = g_PAWN;
          else
            temp = i64_and( g_pieceb[1+g_KNIGHT], b1 );
            if (i64_nz( temp )) then
              piece = g_KNIGHT;
            else
              temp = i64_and( g_pieceb[1+g_BISHOP], b1 );
              if (i64_nz( temp )) then
                piece = g_BISHOP;
              else
                temp = i64_and( g_pieceb[1+g_ROOK], b1 );
                if (i64_nz( temp )) then
                  piece = g_ROOK;
                else
                  temp = i64_and( g_pieceb[1+g_QUEEN], b1 );
                  if (i64_nz( temp )) then
                    piece = g_QUEEN;
                  else
                    temp = i64_and( g_pieceb[1+g_KING], b1 );
                    if (i64_nz( temp )) then
                      piece = g_KING;
                    else
                      break;
                    end
                  end
                end
              end
            end
          end

          temp = i64_and( temp, i64_neg( temp ) );

          g_colorb[1+c] = i64_xor( g_colorb[1+c], temp );

          if ((bit.band(piece,4) ~= 0)  or  (piece == 1)) then

            if (bit.band(piece,1) ~= 0) then
              attacks = i64_or( attacks, i64_and( BOCC(t) , BQU() ) );
            end
            if (bit.band(piece,2) ~= 0) then
              attacks = i64_or( attacks, i64_and( ROCC(t) , RQU() ) );
            end
          end

          attacks = i64_and( attacks, BOARD() );

          k_list[1+nc] = -k_list[1+nc - 1] + a_piece;
          a_piece = g_pval[1+piece];
          nc = nc+1;
          c=bit.bxor(c,1);
        end

        while (nc ~= 1) do
           nc = nc-1;
           if (k_list[1+nc] > -k_list[1+nc - 1]) then
             k_list[1+nc - 1] = -k_list[1+nc];
           end
        end

        g_colorb[1+0] = i64_clone( colstore0 );
        g_colorb[1+1] = i64_clone( colstore1 );
        return k_list[1+0];
      end

      -- In quiesce the moves are ordered just for the value of the captured piece
      function qpick(ml,mn,s)

        local pi = 0;
        local vmax = -g_HEUR
        local i = s;
        local m = 0;
        local t = 0;

        while(i < mn) do

          m = ml[1+i];
          t = g_cag_p_val[1+CAP(m)];
          if (t > vmax) then
            vmax = t; pi = i;
          end

          i = i+1;
        end

        m = ml[1+pi];

        if (pi ~= s) then
          ml[1+pi] = ml[1+s];
        end

        return m;
      end

      -- In normal search some basic move ordering heuristics are used

      function spick(ml,mn,s,ply)

        local pi = 0;
        local vmax = -g_HEUR
        local i = s;
        local m = 0;
        local t = 0;
        local cap = 0;

        while(i < mn) do

          m = ml[1+i];
          cap = CAP(m);
          if (cap ~= 0) then
            t = g_cag_p_val[1+cap];
            if (t > vmax) then
              vmax = t; pi = i;
            end
          end

          if ((vmax < g_HEUR)  and  (m == g_killer[1+ply])) then
            vmax = g_HEUR; pi = i;
          end

          if (vmax < g_history[1+ bit.band(m, 0xFFF)]) then
            vmax = g_history[1+ bit.band(m, 0xFFF)]; pi = i;
          end

          i = i+1;
        end

        m = ml[1+pi];

        if (pi ~= s) then
          ml[1+pi] = ml[1+s];
        end

        return m;
      end

      -- The evaluation for Color c. It's only mobility stuff.
      -- Pinned pieces are still awarded for limiting opposite's king

      function evalc(c,sf)

        local mn = 0;
        local katt = 0;
        local oc = bit.bxor(c,1);
        local ocb = g_colorb[1+oc];
        local kn = g_kmoves[1+g_kingpos[1+oc]];
        local pin = pinnedPieces(g_kingpos[1+c], oc);
        local npin = i64_not(pin);
        local b=i64(0);
        local ppos = 0;
        local f = 0;
        local m=i64(0);
        local a=i64(0);
        local w=i64(0);

        b = i64_and( g_pieceb[1+g_PAWN] , g_colorb[1+c] );
        while ( i64_nz( b ) ) do

          ppos = 0;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          ppos = g_pawnprg[1+c][1+f];

          m = PMOVE(f, c)
          a = POCC(f, c)

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

          w = i64_and(g_BITi[1+f] , pin);
          if (i64_nz( w )) then
            if ( bit.band(getDir(f, g_kingpos[1+c]) , 16) == 0) then
              m = i64(0);
            end
          else
            w = i64_and(a , g_pieceb[1+g_PAWN]);
            w = i64_and(w , g_colorb[1+c]);
            ppos = ppos + bit.lshift( g_BITCnt(w) , 2 );
          end

          ppos = ppos + iif( m ~= 0, 8, -8 );

          w = i64_and( i64_and(g_pawnfile[1+c][1+f] , g_pieceb[1+g_PAWN]), ocb );
          if (i64_is0( w )) then

                  --Free file?
            w = i64_and( i64_and(g_pawnfree[1+c][1+f] , g_pieceb[1+g_PAWN]), ocb );
            if (i64_is0( w )) then
              --Free run?
              ppos = (ppos+ppos);
            end
            w = i64_and( i64_and(g_pawnhelp[1+c][1+f] , g_pieceb[1+g_PAWN]), g_colorb[1+c] );
            if (i64_is0( w )) then
              --Hanging backpawn?
              ppos = (ppos-33);
            end
          end

          mn = mn + ppos;

        end

        cb = i64_and( g_colorb[1+c] , npin );
        b = i64_and( g_pieceb[1+g_KNIGHT] , cb );
        while (i64_nz( b )) do

          sf[1+0] = sf[1+0]+1;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          a = g_nmoves[1+f];

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

          mn = mn + g_nmobil[1+f];

        end

        b = i64_and( g_pieceb[1+g_KNIGHT] , pin );

        while ( i64_nz( b ) ) do

          sf[1+0] = sf[1+0]+1;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          a = g_nmoves[1+f];

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

        end

        --Opposite King does not block mobility at all
        g_colorb[1+oc] = i64_xor( g_colorb[1+oc], g_BITi[1+g_kingpos[1+oc]] );
        b = i64_and( g_pieceb[1+g_QUEEN] , cb );

        while ( i64_nz( b ) ) do

          sf[1+0] = sf[1+0]+4;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          a = i64_or( RATT1(f) , RATT2(f) );
          a = i64_or( a, i64_or( BATT3(f) , BATT4(f) ) );

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

          mn = mn+g_BITCnt(a);

        end

        --Opposite Queen & Rook does not block mobility for bishop
        g_colorb[1+oc] = i64_xor( g_colorb[1+oc], i64_and( RQU() , ocb ) );

        b = i64_and( g_pieceb[1+g_BISHOP] , cb );

        while ( i64_nz( b ) ) do

          sf[1+0] = sf[1+0]+1;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          a = i64_or( BATT3(f) , BATT4(f) );

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

          mn = mn+ bit.lshift(g_BITCnt(a), 3);

        end

        --Opposite Queen does not block mobility for rook.
        g_colorb[1+oc] = i64_xor( g_colorb[1+oc], i64_and( g_pieceb[1+g_ROOK] , ocb ) );


        --Own non-pinned Rook does not block mobility for rook.
        g_colorb[1+c] = i64_xor( g_colorb[1+c], i64_and( g_pieceb[1+g_ROOK] , cb ) );

        b = i64_and( g_pieceb[1+g_ROOK] , cb );

        while ( i64_nz( b ) ) do

          sf[1+0] = sf[1+0]+2;
          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          a = i64_or( RATT1(f) , RATT2(f) );

          w = i64_and(a , kn);
          if (i64_nz( w )) then
            katt = katt + bit.lshift( g_BITCnt(w) , 4 );
          end

          mn = mn+ bit.lshift(g_BITCnt(a), 2);

        end

        -- Back
        g_colorb[1+c] = i64_xor( g_colorb[1+c], i64_and( g_pieceb[1+g_ROOK] , cb ) );

        b = i64_or( i64_or( g_pieceb[1+g_ROOK] , g_pieceb[1+g_BISHOP] ), g_pieceb[1+g_QUEEN] );
        b = i64_and( pin , b);

        while ( i64_nz( b ) ) do

          f = getg_LSB(b);
          b = i64_xor( b, g_BITi[1+f] );
          p = identPiece(f);
          if (p == g_BISHOP) then

            sf[1+0] = sf[1+0]+1;
            a = i64_or( BATT3(f) , BATT4(f) );

            w = i64_and(a , kn);
            if (i64_nz( w )) then
              katt = katt + bit.lshift( g_BITCnt(w) , 4 );
            end

          else
            if (p == g_ROOK) then

              sf[1+0] = sf[1+0]+2;
              a = i64_or( RATT1(f) , RATT2(f) );

              w = i64_and(a , kn);
              if (i64_nz( w )) then
                katt = katt + bit.lshift( g_BITCnt(w) , 4 );
              end

            else

              sf[1+0] = sf[1+0]+4;
              a = i64_or( RATT1(f) , RATT2(f) );
              a = i64_or( a, i64_or( BATT3(f) , BATT4(f) ) );

              w = i64_and(a , kn);
              if (i64_nz( w )) then
                katt = katt + bit.lshift( g_BITCnt(w) , 4 );
              end

            end
          end

          t = bit.bor( p , getDir(f, g_kingpos[1+c]) );

          if (bit.band(t,10) == 10) then
            mn = mn + g_BITCnt(RATT1(f));
          end
          if (bit.band(t,18) == 18) then
            mn = mn + g_BITCnt(RATT2(f));
          end
          if (bit.band(t,33) == 33) then
            mn = mn + g_BITCnt(BATT3(f));
          end
          if (bit.band(t,65) == 65) then
            mn = mn + g_BITCnt(BATT4(f));
          end

        end

        --Back
        g_colorb[1+oc] = i64_xor( g_colorb[1+oc], i64_and( g_pieceb[1+g_QUEEN] , ocb ) );

        --Back
        g_colorb[1+oc] = i64_xor( g_colorb[1+oc], g_BITi[1+g_kingpos[1+oc]] );

        w = i64_and(g_pieceb[1+g_PAWN] , g_colorb[1+c]);
        if ((sf[1+0] == 1)  and i64_is0( w )) then
          --No mating material:
          mn =- 200;
        end

        if (sf[1+0] < 7) then
          --Reduce the bonus for attacking king squares
          katt =  math.floor( katt * (sf[1+0]/7) );
        end

        if (sf[1+0] < 2) then
          sf[1+0] = 2;
        end

        return (mn + katt + (5-(os.clock()%10)));	-- let's give some random fun
      end

      function eval0(c)

        local sf0 = 0;
        local sf1 = 0;
        local sfp = {0};
        local ev0 = 0;
        local ev1 = 0;

        ev0 = evalc(0, sfp);
        sf0 = sfp[1+0];
        sfp[1+0] = sf1;
        ev1 = evalc(1, sfp);
        sf1 = sfp[1+0];
        g_eval1 = g_eval1+1;

        if (sf1 < 6) then
          ev0 = ev0 + ( g_kmobil[1+g_kingpos[1+0]]*(6-sf1));
        end

        if (sf0 < 6) then
          ev1 = ev1 + ( g_kmobil[1+g_kingpos[1+1]]*(6-sf0));
        end

        return iif(c ~= 0, (ev1 - ev0), (ev0 - ev1));
      end

      function quiesce(ch,c,ply,alpha,beta)

        local best = -32000;
        local cmat = iif( c == 1, -g_mat_, g_mat_ );
        local i = 0;
        local m = 0;
        local w = 0;
        local c1=bit.bxor(c,1);
        local cont = false;

        if (ply >= g_sd or g_sabort) then
          return (eval0(c) + cmat);
        end

	if (g_nodes % 16 == 0) then
          if(os.clock() - g_starttime >= g_tm and g_pvlength[1+0] > 0) then
            g_sabort = true;
          end
        end

        if (i64_is0( ch )) then

          if (cmat - 200 >= beta) then
            return beta
          end

          if (cmat + 200 > alpha) then

            best = eval0(c) + cmat;
            if (best > alpha) then

              alpha = best;
              if (best >= beta) then
                return beta;
              end
            end
          end
        end

        generateCaps(ch, c, ply);

        if (i64_nz( ch )  and  (g_movenum[1+ply] == 0)) then
          return (-32000 + ply);
        end

        i = -1;
        while( (i+1) < g_movenum[1+ply] and (not g_sabort)) do

         i = i+1;

         m = qpick(g_movelist[1+ply], g_movenum[1+ply], i);


         cont = (i64_is0( ch ) and  (PROM(m) == 0)  and  (g_pval[1+PIECE(m)] > g_pval[1+CAP(m)])  and  (swap(m) < 0));

         if(not cont) then

          doMove(m, c);
          g_nodes = g_nodes+1;

          w = -quiesce(attacked(g_kingpos[1+c1], c1), c1, ply+1, -beta, -alpha);

          undoMove(m, c);

          if (w > best) then

            best = w;
            if (w > alpha) then

              alpha = w;
              if (w >= beta) then
                return beta;
              end
            end
          end

         end

        end

        return iif( best >= alpha, best, eval0(c) + cmat );
      end

      function retPVMove(c,ply)

        local i = 0;
        local m = 0;

        generateMoves(attacked(g_kingpos[1+c], c), c, 0);

        i = 0;
        while(i < g_movenum[1+0]) do

          m = g_movelist[1+0][1+i];

          if (m == g_p_v[1+0][1+ply]) then
            return m;
          end

          i = i+1;

        end

        return 0;
      end

      function g_Nonevariance(delta)

        local r = 0;

        if (delta >= 4) then
          r = 1;
          while(r <= table.getn(g_Nonevar)) do

            if (delta < g_Nonevar[1+r - 1]) then
              break;
            end
            r = r+1;

          end
        end

        return r;
      end

      function HASHP(c)
        local b=bit.bor( g_flags, 1024 );
        b=bit.bor( b, bit.lshift(c,11) );
        return i64_xor(g_hashb, g_hashxor[1+b]);
      end

      function HASHB(c,d)
        local b=bit.bor( g_flags, 1024 );
        local z=bit.bor( c, 2048 );
        z=bit.bor( z, bit.lshift(d,1) );

        return i64_xor( i64_xor(g_hashb, g_hashxor[1+b]) , g_hashxor[1+z]);
      end

      function search(ch,c,d,ply,alpha,beta,pvnode,isNone)

        local hp=i64(0);
        local hb=i64(0);
        local he=i64(0);
        local w = 0;
        local c1=bit.bxor(c,1);
        local b1=i64(0);
        local R = 0;

        local v = 0;
        local hsave=0;
        local hmove=0;

        local m = 0;
        local n = 0;
        local i = 0;
        local j = 0;
        local best = 0;
        local asave = 0;
        local first = 0;
        local ext = 0;
        local nch=i64(0);
        local cont = false;

        g_pvlength[1+ply] = ply;

        if (ply >= g_sd or g_sabort) then
          return (eval0(c) + iif(c ~= 0, -g_mat_, g_mat_));
        end

        g_nds = g_nds+1;

        if (g_nds % 16 == 0) then
          if(os.clock() - g_starttime >= g_tm and g_pvlength[1+0] > 0) then
            g_sabort = true;
          end
        end

        hp = HASHP(c);
        if ((ply ~= 0)  and  (ig_sdraw(hp, 1) ~= 0)) then
          return 0;
        end

        if (d == 0) then
          return quiesce(ch, c, ply, alpha, beta);
        end
        g_hstack[1+COUNT()] = hp;

        hb = HASHB(c, d);

        v = bit.band(hb.l, g_HMASKB);
        he = g_hashDB[1+v];
        if ((he~=nil) and i64_is0( i64_and(i64_xor(he,hb), g_HINVB) )) then

          g_hc = g_hc + 1;
          w = LOW16(he.l) - 32768;
          if (bit.band(he.l, 0x10000) ~= 0) then

            isNone = 0;
            if (w <= alpha) then
              return alpha;
            end

          else

            if (w >= beta) then
              return beta;
            end
          end

        else

          w = iif( c ~= 0, -g_mat_, g_mat_ );
        end

        b1 = i64_and( g_colorb[1+c], i64_not( g_pieceb[1+g_PAWN] ) );
        b1 = i64_and( b1, i64_not( pinnedPieces(g_kingpos[1+c], c1) ) );

        if ((pvnode == 0)  and  i64_is0( ch )  and  (isNone ~= 0)  and  (d > 1)  and (g_BITCnt(b1) > 2) ) then

          g_flagstore = g_flags;
          R = math.floor( (10 + d + g_Nonevariance(w - beta))/4 );
          if (R > d) then
            R = d;
          end

          g_flags = bit.band( g_flags, 960 );
          g_count = g_count + 0x401;

          --Null Move Search
          w = -search(g_0, c1, d-R, ply+1, -beta, -alpha, 0, 0);
          g_flags = g_flagstore;
          g_count = g_count- 0x401;
          if ((not g_sabort)  and  (w >= beta)) then

            g_hashDB[1+ bit.band(hb.l, g_HMASKB)] = i64_or( i64_and(hb, g_HINVB) , i64(w + 32768) );
            return beta;
          end
        end

        hsave = 0;
        hmove = 0;

        if (ply > 0) then
          v = bit.band(hp.l, g_HMASKP);
          he = g_hashDP[1+v];
          if ((he~=nil) and i64_is0( i64_and(i64_xor(he,hp), g_HINVP) ) ) then
            hsave = bit.band(he.l, g_HMASKP);
            hmove = hsave;
          end

          if ((d >= 4)  and  (hmove==0)) then

            -- Simple version of Internal iterative Deepening
            w = search(ch, c, d-3, ply, alpha, beta, pvnode, 0);
            v = bit.band(hp.l, g_HMASKP);
            he = g_hashDP[1+v];
            if ((he~=nil) and i64_is0( i64_and(i64_xor(he,hp), g_HINVP) ) ) then
              hsave = bit.band(he.l, g_HMASKP);
              hmove = hsave;
            end
          end

        else

          hmove = retPVMove(c, ply);
        end

        n = -1;
        i = 0;
        best = iif(pvnode ~= 0, alpha, -32001 );
        asave = alpha;
        first = 1;

        while ((i ~= n) and (not g_sabort)) do

         i = i+1;
         ext = 0;
         if ( hmove ~= 0) then

            m = hmove;
            hmove = 0;
            i = i-1;

         else

            if (n == -1) then

              generateMoves(ch, c, ply);
              n = g_movenum[1+ply];
              if (n == 0) then
                return iif( i64_nz( ch ), -32000+ply, 0 );
              end
            end

            m = spick(g_movelist[1+ply], n, i, ply);

            cont = ((hsave ~= 0)  and  (m == hsave));

         end

         if(not cont) then

          doMove(m, c);

          nch = attacked(g_kingpos[1+c1], c1);
          -- Check Extension:
          if ( i64_nz( nch ) ) then
            ext = ext+1;

          else
            --LMR
            if ((d >= 3)  and  (i >= 4)  and  (pvnode == 0)) then

              if ((CAP(m) == 0) and (PROM(m) == 0)) then

                b1 = i64_and( g_pawnfree[1+c][1+TO(m)], g_pieceb[1+g_PAWN] );
                b1 = i64_and( b1, g_colorb[1+c1] );
                if ((PIECE(m) ~= g_PAWN)  or i64_nz( b1 )) then
                  ext = ext-1;
                end
              end
            end
          end

          if ((first ~= 0)  and  (pvnode ~= 0)) then

            w = -search(nch, c1, d-1+ext, ply+1, -beta, -alpha, 1, 1)

          else

            w = -search(nch, c1, d-1+ext, ply+1, -alpha-1, -alpha, 0, 1);

            if ((w > alpha)  and  (ext < 0)) then
              w = -search(nch, c1, d-1, ply+1, -alpha-1, -alpha, 0, 1);
            end

            if ((w > alpha)  and  (w < beta)  and  (pvnode ~= 0)) then
              w = -search(nch, c1, d-1+ext, ply+1, -beta, -alpha, 1, 1);
            end

          end

          undoMove(m, c);

          if ((not g_sabort)  and  (w > best)) then

            if (w > alpha) then
              v = bit.band(hp.l, g_HMASKP);
              g_hashDP[1+v] = i64_or( i64_and(hp,g_HINVP) , i64(m) );
              alpha = w;
            end

            if (w >= beta) then

              if (CAP(m) == 0) then

                g_killer[1+ply] = m;
                v = bit.band(m,0xFFF);
                g_history[1+v] = g_history[1+v]+1;

              end

              v = bit.band(hb.l, g_HMASKB);
              g_hashDB[1+v] = i64_or( i64_and(hb,g_HINVB) , i64(w + 32768) );
              return beta;

            end

            if ((pvnode ~= 0)  and  (w >= alpha)) then

              g_p_v[1+ply][1+ply] = m;
              j = ply +1;
              while(j < g_pvlength[1+ply +1]) do
                g_p_v[1+ply][1+j] = g_p_v[1+ply +1][1+j];
                j = j+1;
              end

              g_pvlength[1+ply] = g_pvlength[1+ply +1];

              if (w == 31999 - ply) then
                return w;
              end
            end

            best = w;

          end

          first = 0;

         end

        end

        if ((not g_sabort)  and  ((pvnode ~= 0)  or  (asave == alpha))) then
          v = bit.band(hb.l, g_HMASKB);
          b1 = i64_or( i64(0x10000), i64(best + 32768) );
          b1 = i64_or( b1, i64_and(hb,g_HINVB) );
          g_hashDB[1+v] = b1;
        end

        return alpha;
      end

      function execMove(m)

        local c = 0;
        local i = 0;

        doMove(m, g_onmove);
        g_onmove = bit.bxor( g_onmove, 1 );
        c = g_onmove;

        g_hstack[1+COUNT()] = HASHP(c);
        i = 0;
        while(i < 127) do
          g_killer[1+i] = g_killer[1+i+1];
          i = i+1;
        end

        i = 0;
        while(i < 0x1000) do
          g_history[1+i] = 0;
          i = i+1;
        end

        i = generateMoves(attacked(g_kingpos[1+c], c), c, 0);

        if (g_movenum[1+0] == 0) then

          if (i == 0) then
            g_gameover = "1/2-1/2 Stalemate";
            return 4;

          else

            g_gameover = iif(c == 1, "1-0 White mates", "0-1 Black mates");
            return (5 + c);

          end

        end

        c = ig_sdraw(HASHP(c), 2);

        if( c==1 ) then
          g_gameover = "1/2-1/2 Draw by Repetition";
        else
          if( c==2 ) then
            g_gameover = "1/2-1/2 Draw by Fifty Move Rule";
          else
            if( c==3 ) then
              g_gameover = "1/2-1/2 Insufficient material";
            else
              c = 0;
            end
          end
        end

        return c;
      end

      function ismove(m,to,fr,piece,prom,h)

        if (TO(m) ~= to) then
          return false;
        end

        if ((fr < 0)  and  (PIECE(m) ~= piece)) then
          return false;
        end

        if ((fr >= 0)  and  (FROM(m) ~= fr)) then
          return false;
        end

        if (ISFILE(string.char(h))  and  (bit.band(FROM(m),7) ~= h - string.byte("a",1) )) then
          return false;
        end

        if (ISRANK(string.char(h))  and  (bit.band(FROM(m),56) ~= 8*(h - string.byte("1",1)) )) then
          return false;
        end

        if ((prom ~= 0) and  (PROM(m) ~= prom)) then
          return false;
        end

        return true;
      end

      function parseMove(s,u,p)

        local fr = -1;
        local to = -1;
        local piece = g_PAWN;
        local prom = 0;
        local ip = {1};
        local c = "";
        local c1 = "";
        local c2 = "";
        local h = 0;
        local i = 0;
	local sp = 0;

        if (string.sub(s,1,5)=="O-O-O") then
          s = iif(u ~= 0, "Kc8", "Kc1");

        else
          if (string.sub(s,1,3)=="O-O") then
            s = iif(u ~= 0, "Kg8", "Kg1");
          end
        end

        sp = 0;

          c = string.sub(s,1+sp,1+sp);
          if (c >= "A"  and  c <= "Z") then
            piece = _getpiece(c, ip);
            sp = sp+1;
            if (piece< 1) then
              return -1;
            end
          end

          c = string.sub(s,1+sp,1+sp);
          if (c == "x") then
            sp = sp+1;
          end

          c = string.sub(s,1+sp,1+sp);
          if (ISRANK(c)) then
            h = string.byte(c,1);
            sp = sp+1;

            c = string.sub(s,1+sp,1+sp);
            if (c == "x") then
              sp = sp+1;
            end
          end

          c = string.sub(s,1+sp,1+sp);
          if (not ISFILE(c)) then
            return -1;
          end

          c1 = string.sub(s,1+sp,1+sp);
          sp = sp+1;

          c = string.sub(s,1+sp,1+sp);
          if (c == "x") then
            sp = sp+1;
          end

          c = string.sub(s,1+sp,1+sp);
          if (ISFILE(c)) then
            h = string.byte(c1,1);
            c1 = c;
            sp = sp+1;
          end

          c2 = string.sub(s,1+sp,1+sp);
          sp = sp+1;

          if (not ISRANK(c2)) then
            return -1;
          end

          if (string.len(s) > sp) then

            c = string.sub(s,1+sp,1+sp);
            if (c == "=") then
              prom = _getpiece( string.sub(s,1+sp + 1,1+sp + 1) , ip);

            else
              if (c ~= "+") then

                -- Algebraic Notation
                fr = string.byte(c1,1) - string.byte("a",1) + ( 8*(string.byte(c2,1) - string.byte("1",1)) );
                c1 = string.sub(s,1+sp,1+sp);
                sp = sp+1;
                c2 = string.sub(s,1+sp,1+sp);
                sp = sp+1;
                if ( (not ISFILE(c1))  or  (not ISRANK(c2))) then
                  return -1;
                end

                if (string.len(s) > sp) then
                  prom = _getpiece( string.sub(s,1+sp,1+sp), ip);
                end
              end
            end
          end

          to = string.byte(c1,1) - string.byte("a",1) + ( 8*(string.byte(c2,1) - string.byte("1",1)) );
          if (p ~= 0) then

            if (ismove(p, to, fr, piece, prom, h)) then
              return p;
            end

            return 0;
          end

          generateMoves(attacked(g_kingpos[1+u], u), u, 0);
          i = 0;

          while(i < g_movenum[1+0]) do

            if (ismove(g_movelist[1+0][1+i], to, fr, piece, prom, h)) then
              return (g_movelist[1+0][1+i]);
            end
            i = i+1;
          end

        return 0;
      end

      function parseMoveNExec(s,c,m)

        m[1+0] = parseMove(s, c, 0);
        if (m[1+0] == -1) then
          print("UNKNOWN COMMAND: "..s);

        else
          if (m[1+0] == 0) then
            errprint("Illegal move: "..s);

          else
            return execMove(m[1+0]);
          end
        end

        return -1;
      end

      function undo()
        g_onmove = bit.bxor( g_onmove, 1 );
        undoMove( nil, g_onmove);
      end

      function calc()

        local s="";
        local t1 = 0;
        local ch = attacked(g_kingpos[1+g_onmove], g_onmove);
        g_eval1 = 0;
        g_iter = 0;
        g_kvalue[1+0] = 0;
        g_sabort = false;
        g_nodes = 0;
        g_nds = 0;
        g_hc = 0;
        g_gameover = "";

	-- we simply set search time
        g_movemade = "";

        g_starttime = os.clock();

        g_iter = 1;
        while(g_iter <= g_sd) do

          g_kvalue[1+g_iter] = search(ch, g_onmove, g_iter, 0, -32000, 32000, 1, 0);

          if (g_sabort) then
             break;
          end

          if ((g_post_)  and  (g_pvlength[1+0] > 0)) then
            t1 = (os.clock() - g_starttime);
            s = string.format("%d",g_iter)..". ";
            s = s..string.format("%d",g_kvalue[1+g_iter]).." ";
            s = s..string.format("%d",math.floor(t1)).."s ";
            s = s..string.format("%d",g_nds+g_nodes ).." nodes ";
            print(s);
            displaypv();
          end

          g_iter = g_iter+1;

        end

        if (g_post_) then
          t1 = (os.clock() - g_starttime);
          s = ""
          s = s.." Nodes: ".. string.format("%d",g_nds);
	  s = s.." QNodes: ".. string.format("%d",g_nodes);
          s = s.." HashNd: ".. string.format("%d",g_hc);
          s = s.." Evals: ".. string.format("%d",g_eval1);
          s = s.." Secs: ".. string.format("%d",math.floor(t1) );
          s = s.." knps: ".. string.format("%d",math.floor( (g_nds+g_nodes)/(t1+1) ) );
          print(s);
        end

        g_movemade = mvstr(g_p_v[1+0][1+0]);
        print( "move ".. g_movemade );

        return execMove(g_p_v[1+0][1+0]);
      end

      function gomove()
        g_engine = g_onmove
        g_ex = calc();
      end

      function entermove(buf)
        local m = {1};
        g_ex = parseMoveNExec(buf, g_onmove, m);
      end

      -- it takes time to prepare this Lua based chess engine for a game

      function init()

        local i = 0;
        local w=i64(1);
        local mfile = nil;

        woutput("Loading");

        i = 0;
        while(i < 2) do
          g_pmoves[1+i] = {};
          g_pcaps[1+i] = {};
          g_pawnprg[1+i] = {};
          g_pawnfree[1+i] = {};
          g_pawnfile[1+i] = {};
          g_pawnhelp[1+i] = {};
          i = i+1;
        end

        i = 0;
        while(i < 192) do
          g_pcaps[1+0][1+i] = i64(0);
          g_pcaps[1+1][1+i] = i64(0);
          i = i+1;
        end

        i = 0;
        while(i < 64) do

          g_crevoke[1+i] = 0x3FF;
          g_nmoves[1+i] = i64(0);
		  g_kmoves[1+i] = i64(0);
          g_pmoves[1+0][1+i] = i64(0);
          g_pmoves[1+1][1+i] = i64(0);
          i = i+1;
        end

        i = 0;
        while(i < 0x1000) do
          g_history[1+i] = 0;
          i = i+1;
        end


        woutput("64-bit rays");

        -- will be fast on next starting
        mfile = io.open("rays_mem.txt", "r")

        i = 0;
        while(i < 0x10000) do

	  g_rays[1+i] = i64(0);
	  if(mfile==nil) then
            g_LSB[1+i] = _slow_g_LSB(i);
            g_BITC[1+i] = _g_BITCnt(i);
		  else
            g_LSB[1+i] = mfile:read("*number");
			g_BITC[1+i] = mfile:read("*number");
			g_rays[1+i].l = mfile:read("*number");
			g_rays[1+i].h = mfile:read("*number");
          end

          i = i+1;
        end

        woutput("Zobrists");

        i = 0;
        while(i < 4096) do

          g_hashxor[1+i] = i64(0);
          if(mfile==nil) then
		    g_hashxor[1+i] = _rand_64();
          else
            g_hashxor[1+i].l = mfile:read("*number");
			g_hashxor[1+i].h = mfile:read("*number");
          end
	  i = i+1;
        end

        i = 0;
        while(i < 64) do
          g_BITi[1+i] = w;
          w = i64_lshift(w,1);
          i = i+1;
        end

        woutput("Big_masks");

        i = 0;
        while(i < 64) do
          g_bmask45[1+i] = i64_or( _bishop45(i, g_0, 0) , g_BITi[1+i] );
          g_bmask135[1+i] = i64_or( _bishop135(i, g_0, 0) , g_BITi[1+i] );
          i = i+1;
        end

        g_crevoke[1+7] = bit.bxor( g_crevoke[1+7], g_BITi[1+6].l );
        g_crevoke[1+63] = bit.bxor( g_crevoke[1+63], g_BITi[1+7].l );
        g_crevoke[1+0] = bit.bxor( g_crevoke[1+0], g_BITi[1+8].l );
        g_crevoke[1+56] = bit.bxor( g_crevoke[1+56], g_BITi[1+9].l );

        if(mfile==nil) then

          woutput("Rays 1 of 4");
          _init_g_rays1();

          woutput("Rays 2 of 4");
          _init_g_rays2();

          woutput("Rays 3 of 4");
          _init_g_rays3();

          woutput("Rays 4 of 4");
          _init_g_rays4();

          mfile = io.open("rays_mem.txt", "w")
          i = 0;
          while(i < 0x10000) do
            mfile:write( g_LSB[1+i] );
            mfile:write( "\n" );
            mfile:write( g_BITC[1+i] );
            mfile:write( "\n" );
            mfile:write( g_rays[1+i].l );
            mfile:write( "\n" );
            mfile:write( g_rays[1+i].h );
            mfile:write( "\n" );
            i = i+1;
          end

          i = 0;
          while(i < 4096) do
            mfile:write( g_hashxor[1+i].l );
            mfile:write( "\n" );
            mfile:write( g_hashxor[1+i].h );
            mfile:write( "\n" );
            i = i+1;
          end

          woutput("Wrote to file");

        else

          woutput("Got from file");

        end

        mfile:close();


        woutput("Shorts");

        _init_shorts(g_nmoves, g_knight);
        _init_shorts(g_kmoves, g_king);

        woutput("Pawns");

        _init_pawns(g_pmoves[1+0], g_pcaps[1+0], g_pawnfree[1+0], g_pawnfile[1+0], g_pawnhelp[1+0], 0);
        _init_pawns(g_pmoves[1+1], g_pcaps[1+1], g_pawnfree[1+1], g_pawnfile[1+1], g_pawnhelp[1+1], 1);

        _startpos();

        woutput("Board");

        i = 0;
        while(i < 64) do
          g_nmobil[1+i] = (g_BITCnt( g_nmoves[1+i] )-1)*6;
          g_kmobil[1+i] = g_BITCnt( g_nmoves[1+i] )*2;

          i = i+1;
        end

        woutput("Ready");

      end

      -- AI vs AI game for testing...
      function autogame()
        g_engine = g_onmove;
        g_pgn = "";
        print("Autogame!");

        while(true) do
          g_ex = calc();
          printboard();

          local mr = COUNT(); -- just export to pgn-viewer
          if(mr%2>0) then
            g_pgn = g_pgn..string.format( "%d",math.floor(mr/2)+1 )..".";
          end
          g_pgn = g_pgn..mvstr( g_p_v[1+0][1+0], true ).." ";

          if( g_ex ~= 0 ) then
	    if(string.find(g_gameover,"mates")~=nil) then
		g_pgn = g_pgn.."#"
	    end
            print(g_pgn);
	    printboard();
	    print(g_gameover);
            break;
          end
        end

      end

      --
      -- starting
      --

      woutput( g_VER );
      init();
      
      printboard();

      autogame();

