-- Sargon assembler code of 1978 ported to lua
--  (http://chessprogramming.wikispaces.com/Dan+Spracklen)
--
-- by Chessforeva at http://chessforeva.blogspot.com
-- 2011

-- to randomize
math.randomseed(os.time());

PLYMAX = 1;  -- max.depth

-- registers
R = {};
R.A = 0;
R.B = 0;
R.C = 0;
R.D = 0;
R.E = 0;
R.H = 0;
R.L = 0;
R.M = 0;
R.X = 0;
R.Y = 0;
R.Z = 0;

nodes = 0;    --nodes of moves processed
started = 0;  --time of processing start
timeout = 8;  --timeout above ~(8+some) seconds for plies above 2
MYMOVE = "";  --move by sargon
wasasc=false; --ascending detection

PAWN = 1;
KNIGHT = 2;
BISHOP = 3;
ROOK = 4;
QUEEN = 5;
KING = 6;
WHITE = 0;
BLACK = 0x80;

p_piece = { ".","p","n","b","r","q","k" };


DIRECT = {9,11,-11,-9,10,-10,1,-1,-21,-12,8,19,21,12,-8,-19,10,10,11,9,-10,-10,-11,-9};

DPOINT = {20,16,8,0,4,0,0};

DCOUNT = {4,4,8,4,4,8,8};

PVALUE = {0,1,3,3,5,9,10};

PIECES = {4,2,3,5,6,3,2,4};

BOARD = {};

WACT = 0;
BACT = 0;
ATKLSTW = {};
ATKLSTB = {};

PLISTD = {};
PLISTA = {};

POSK = {25,95};		-- starting position of KkQq
POSQ = {24,94};

SCORE = {};

PLYIX = {};

M1 = 0;
M2 = 0;
M3 = 0;
M4 = 0;
T1 = 0;
T2 = 0;
T3 = 0;
INDX1 = 0;
INDX2 = 0;
NPINS = 0;
SCRIX = 0;

MLPTRI = -1;
MLPTRJ = -1;
BESTM = -1;
MLNXT = -1;

KOLOR = 0;
COLOR = 0;

PMATE = 0;
MOVENO = 0;

NPLY = 0;
CKFLG = 0;
MATEF = 0;
VALM = 0;
BRDC = 0;
PTSL = 0;
PTSW1 = 0;
PTSW2 = 0;
MTRL = 0;
BC0 = 0;
MV0 = 0;
PTSCK = 0;

BMOVES = {35,55,0x10, 34,54,0x10, 85,65,0x10, 84,64,0x10};

MLIST = {};

MLPTR = 0
MLFRP = 2
MLTOP = 3
MLFLG = 4
MLVAL = 5


MVENUM = "01 ";

MVEMSG = "a1-a1";

-- (if ? then : else) substitute
-- other syntax for binary operators a,b:  cond and a or b

function iif(ask, ontrue, onfalse)
 if( ask ) then
  return ontrue;
 end
 return onfalse;
end

-- define board square
function BO_(piece,color)
 local b = {};
 b.p = piece;
 b.c = color;
 b.f3 = 0;
 b.f4 = 0;
 return b;
end

-- board clone
function BO_cl(ob)
 local b = {};
 b.p = ob.p;
 b.c = ob.c;
 b.f3 = ob.f3;
 b.f4 = ob.f4;
 return b;
end

--
function INITBD()

 local X=0;
 local piece = nil;

 for X=119, 0, -1 do
  BOARD[1+X]= BO_(0xFF,0);
 end

 for X=0, 7, 1 do
  piece = PIECES[1+X];
  BOARD[1+21+X]= BO_(piece,WHITE);
  BOARD[1+91+X]= BO_(piece,BLACK);
  BOARD[1+31+X]= BO_(PAWN,WHITE);
  BOARD[1+81+X]= BO_(PAWN,BLACK);
  BOARD[1+41+X]= BO_(0,0);
  BOARD[1+51+X]= BO_(0,0);
  BOARD[1+61+X]= BO_(0,0);
  BOARD[1+71+X]= BO_(0,0);
 end

 POSK = {25,95};
 POSQ = {24,94};

 COLOR = 0;
 MVENUM = "01 ";
 MOVENO = 1;

 PLYIX = {};
 MLIST = {};
 MLPTRI = -1;
 MLPTRJ = -1;
 BESTM = -1;
 MLNXT = -1;
 PMATE = 0;

end

--
function PATH()

 M2 = M2 + R.C;
 local piece = BOARD[1+M2].p;

 if(piece==0) then
  R.A = 0;
 else
  if(piece==0xFF) then
   R.A = 3;
  else
   T2 = piece;
   R.A = iif( BOARD[1+M2].c==BOARD[1+M1].c, 2, 1);
  end
 end

end

--
function MPIECE()

local bo = BOARD[1+M1];
local piece = bo.p;
local pcol = bo.c;

T1 = (piece-iif(piece==PAWN and pcol==BLACK,1,0));

R.B = DCOUNT[1+T1];

INDX2 = DPOINT[1+T1];

R.Y = INDX2;

local cstlck=true;

while(R.B>0) do		-- one scan for all directions, all squares, all exceptions

 R.C = DIRECT[1+R.Y];

 M2 = M1;

 R.A = 0;

 if(piece==PAWN) then

    PATH();
    if(R.A<2) then

     if(R.B<3) then

       if(R.A==0) then
         ENPSNT();
       else
         ADMOVE(0);
       end

     else

        if(R.B==3) then

           if( bo.f3>0 ) then
             R.A=3;
           end
           if(R.A==0) then
             PATH();
           end
        end
        if(R.A==0) then
          ADMOVE(0);
        end
     end

    end
 else

  if(piece==KNIGHT) then

     PATH();
     if(R.A<2) then
       ADMOVE(0);
     end

  else

   if(piece==KING) then

     PATH();
     if(R.A<2) then
       ADMOVE(0);
       if(cstlck) then
         CASTLE();
         cstlck = false;
       end
     end

   else

    while(R.A==0) do

     PATH();
     if(R.A<2) then
       ADMOVE(0);
     end
    end

   end
  end
 end

 R.Y = R.Y+1;
 R.B = R.B-1;

end

end

--
function ENPSNT()

R.A = M1;

local bo = BOARD[1+M1];
local piece = bo.p;
local pcol = bo.c;

local bo2 = nil;
local piece2 = nil;
local pcol2 = nil;

if(pcol>0) then
  R.A = R.A + 10;
end

local Ob = MLIST[1+MLPTRJ];

if(R.A>=61 and R.A<=69) then


 if( Ob.MLFLG.f4>0 ) then


  M4 = Ob.MLTOP;

  bo2 = BOARD[1+M4];
  piece2 = bo2.p;
  pcol2 = bo2.c;


  if(piece2==PAWN) then

   if( math.abs(M4-M2)==10 ) then

    ADMOVE(1);	-- capture

    M3 = M1;
    M1 = M4;
    M2 = M4;	-- clear pawn

    ADMOVE(1);

    M1 = M3;

   end
  end
 end

end

end

--
function CASTLE()

local bo = BOARD[1+M1];

if( bo.f3>0 ) then
 return;
end

if(CKFLG>0) then
 return;
end

local kqside = 0;
local can = true;
local bo3 = nil;
local rookpos = nil;

for kqside = -1, 1, 2 do

 can = true;

 rookpos = iif(kqside<0 , M1+3 , M1-4 );	-- rook position
 M3 = rookpos;

 bo3 = BOARD[1+M3];

 if((bo3.p==ROOK) and (bo3.f3==0) and (bo3.f4==0)) then

  M3 = M3 + kqside;
  while( can and (M3~=M1)) do

   bo3 = BOARD[1+M3];
   if(bo3.p~=0) then
    can = false;
    break;
   end

   if((M3~=22) and (M3~=92)) then

     BOARD[1+M3] = BO_cl( bo );	-- put king here
     ATTACK();
     BOARD[1+M3] = BO_(0,0);			-- put back empty square
     if(R.A>0) then
       can = false;
     end

   end

   M3 = M3 + kqside;
  end

  if(can) then
    M2 = M1 - (2*kqside);
    ADMOVE(1);			-- king

    M2 = M1 - kqside;
    M1 = rookpos;
    ADMOVE(1);			-- rook
    M1 = M3;
  end

 end

end

end


--
function ADMOVE(dbl)

local bo = BOARD[1+M1];
local bo2 = BOARD[1+M2];
local Ob = {};

Ob.MLPTR = MLPTRJ;
Ob.MLFRP = M1;
Ob.MLTOP = M2;

local fl = {};
fl.p = bo2.p;	--  captured piece
fl.c = bo2.c;	--  color or piece
fl.bo = BO_cl(bo2); -- captured object to restore

fl.f4 = iif((bo.f3==0),1,0);					-- first move
fl.f6 = iif((dbl>0),1,0);					-- double move
fl.f5 = iif(((bo.p == PAWN) and (M2>=91 or M2<=29)),1,0);	-- promotion
Ob.MLFLG = fl;

Ob.MLVAL = 0;

Ob.move = string.format("%c",96+(M1%10))..string.format("%c",48+math.floor(M1/10)-1).."-"..
          string.format("%c",96+(M2%10))..string.format("%c",48+math.floor(M2/10)-1);

MLNXT = MLNXT + 1;
MLIST[1+MLNXT]=Ob;

while( table.getn( MLIST ) > (1+MLNXT) ) do
  table.remove(  MLIST );
end

end

--
function GENMOV()

INCHK();

CKFLG = R.A;

MLPTRI = MLPTRI + 1;
PLYIX[1+MLPTRI] = MLNXT+1;

local X=0;
local bo = nil;

for X=21,98,1 do

  bo = BOARD[1+X];

  M1 = X;

  if((bo.p~=0) and (bo.p~=0xFF)) then

   if(COLOR == bo.c) then
     MPIECE();
   end
  end

end

end

--
function INCHK()

M3 = POSK[1+ iif(COLOR>0, 1, 0) ];

local bo = BOARD[1+M3];

T1 = bo.p;

ATTACK();

end

--
function ATTACK()

local SaveMs = { M1,M2,M3,M4, R.B,R.C,R.D,R.Y };
local is=0;
local R20=0;
local R40=0;
local R80=0;
local sc2 = 0;
local goAT14=false;
local pwh = nil;

R.B = 16;

INDX2 = 0;

R.Y = INDX2

	-- directions
while(R.B>0) do

R.C = DIRECT[1+R.Y];

R20=0;
R40=0;
R80=0;

R.D = 0;

M1 = M3;
M2 = M3;

sc2 = 8;
	-- squares
while(sc2>0) do

sc2 = sc2 - 1;

if(R.B<9) then
  sc2=0;	-- knight scan 1sq=1direction
end

R.D = R.D + 1;

PATH();

goAT14=false;

if(R.A==1) then

   if(R40==0) then
     R20=1;
     goAT14=true;
   else
     sc2=0;
   end

else
 if(R.A==2) then

   if(R20==0) then
     R40=1;
     goAT14=true;
   else
     sc2=0;
   end

 else

  if(R.A==3) then
   sc2=0;
  end

 end
end

if(goAT14) then


is=0;

if(T2==KING) then
   if((R.D==1) and (R.B>8)) then
     is=1;
   end
else
 if(T2==QUEEN) then
   if(R.B>8) then
     R80=1;
     is=1;
   end
 else
  if(T2==ROOK) then
   if(R.B>8 and R.B<13) then
    is=1;
   end
  else
   if(T2==BISHOP) then
    if(R.B>12) then
     is=1;
    end
   else
    if(T2==KNIGHT) then
     if(R.B<9) then
      is=1;
     end
    else
     if(T2==PAWN) then
      if(R.D==1) then
        pwh = (BOARD[1+M2].c==0);
        if((R.B>12) and ((R.B<15)==pwh)) then
          is=1;
        end
      end
     end
    end
   end
  end
 end
end

if(is>0) then

  if(T1==7) then
    R.Z = R80;
    ATKSAV();	-- if searching for attackers and defenders
  else

   if(R20>0) then
      sRetRest( 1, SaveMs);
      return;	-- Attacker found
   end
  end
else
 sc2=0;
end

end --goAT14

end --squares

R.Y = R.Y + 1;
R.B = R.B - 1;

end --directions

sRetRest( 0, SaveMs );	-- result = not found
return;

end

--
function sRetRest(ret,SaveMs)

 M1 = SaveMs[1+0];
 M2 = SaveMs[1+1];
 M3 = SaveMs[1+2];
 M4 = SaveMs[1+3];
 R.A = ret;
 R.B = SaveMs[1+4];
 R.C = SaveMs[1+5];
 R.D = SaveMs[1+6];
 R.Y = SaveMs[1+7];

end

--
function ATKSAV()

if(PNCK()) then
 return;
end

local pz = T2;
if(R.Z>0) then
 pz = QUEEN;	-- if queen detected, use queen slot
end

local pval = PVALUE[1+pz];

local wh = (BOARD[1+M2].c==0);

local i=0;

local l=table.getn( iif( wh, ATKLSTW, ATKLSTB ) );

for i=0,l-1,1 do
  if( iif( wh, ATKLSTW[1+i], ATKLSTB[1+i] ) >pval) then
    table.insert( iif( wh, ATKLSTW, ATKLSTB ), 1+i, pval);
    i=-9;
    break;
  end
end

if(i>=0) then
  table.insert( iif( wh, ATKLSTW, ATKLSTB ), pval);
end

if(wh) then
  WACT = WACT + 1;
else
  BACT = BACT + 1;
end

end

--
function PNCK()

 local at = 0;

 if(NPINS>0) then

  at = tIndexOf(PLISTA, 0, M2);
  if(at>=0) then

     -- if found another direction or second time then abnormal exit
    if((math.abs(R.C)~=PLISTD[1+at]) or (tIndexOf(PLISTA, at+1, M2)>=0)) then
      return true;
    end
  end

 end

 return false;

end

--
function tIndexOf( tb, st, v )
 local i=0;
 local l=table.getn(tb)-1;
 for i=st, l, 1 do
  if(tb[1+i]==v) then
    return i;
  end
 end
 return -1;
end

--
function PINFND()

local SaveMs={M1,M2,M3,M4};

local j=0;

local bo3 = nil;
local pw3 = nil;
local sc=0;
local is=0;

NPINS = 0;
PLISTA = {};
PLISTD = {};

for j=0, 3, 1 do

M3 = iif(j<2, POSK[1+j] , POSQ[1+j-2]);

bo3 = BOARD[1+M3];
pw3 = (bo3.c==0);

if(M3>0) then

R.B = 8;	-- all diognals, files, ranks

INDX2 = 0;

R.Y = INDX2;

	-- directions
while(R.B>0) do

M1 = M3;
M2 = M3;

M4 = 0;

R.C = DIRECT[1+R.Y];

sc=8;	-- squares
while(sc>0) do

sc = sc-1;

PATH();

is=0;

-- if 0 then next square
if(R.A>0) then
 if(R.A==3) then
  sc=0;	-- next direction
 else
  if(R.A==2) then
	-- our piece on this direction
    if(M4==0) then
      M4=M2;
    else
      sc=0;
    end
  else
    if(M4>0) then	-- if pin possible
      if(T2==QUEEN) then
        is=1;
      else
        if(T2==ROOK) then
          if(R.B<5) then
            is=1;
          end
        else
          if(T2==BISHOP) then
           if(R.B>4) then
             is=1;
           end
          end
        end
      end
    end

    if(is==0) then
      sc=0; -- next direction
    end

  end
 end
end


if(is>0) then

R.A = -1; -- valid pin

if((bo3.p==QUEEN) and (T2==QUEEN)) then

  WACT = 0;
  BACT = 0;
  ATKLSTW = {};
  ATKLSTB = {};

  T1 = 7;
  ATTACK();	-- call attacker finding + save

  R.A = iif(pw3, WACT - BACT, BACT - WACT )-1;

end

	-- if valid pin
if(R.A<0) then
  NPINS = NPINS + 1;
  PLISTA[NPINS] = M4;
  PLISTD[NPINS] = math.abs(R.C);
end

end

end	-- squares

R.Y = R.Y + 1;
R.B = R.B - 1;

end	-- directions

end     -- if piece on board
end	-- j at POSK,POSQ

M1=SaveMs[1+0];
M2=SaveMs[1+1];
M3=SaveMs[1+2];
M4=SaveMs[1+3];

end

--
function XCHNG()

local bo = BOARD[1+M3];
local colorf = (bo.c>0);

R.E = 0;	-- points lost

R.C = 0;

R.D = (PVALUE[1+T3] * 2);

local pval=R.D;
local attr = 0;
local plus=false;
local defr = 0;

NEXTAD(colorf);

if(R.A>0) then

 attr = R.A;	-- if attacker exist

  --XC10
 while(R.A>0) do

  plus=false;

  NEXTAD(colorf);
  defr = R.A;

  if(R.A==0) then
    R.A=pval;
    plus=true;
  else
    if(pval>=attr) then
      R.A=pval;
      plus=true;
    else

       --XC15
      while(defr>0) do

       if(defr<attr) then
         return;
       else
         NEXTAD(colorf);
         if(R.A==0) then
           return;
         else
           attr = R.A;
           NEXTAD(colorf);
           defr = R.A;
           if(defr==0) then
             plus=true;
           end
         end
       end
      end

    end
  end

    --XC18, XC19
  if(plus) then
    R.E = R.E + iif(R.C>0, -R.A, R.A );
    pval=attr;
    R.A=defr;
  end

 end

end

end

--
function NEXTAD(colorf)

R.A = 0;
local white = (R.C==0);
if(not colorf) then
  white = (not white);	-- swap colors
end

if(white) then
  if WACT>0 then
    R.A = table.remove ( ATKLSTW, 1 );
    WACT = WACT-1
  end
else
  if BACT>0 then
    R.A = table.remove ( ATKLSTB, 1 );
    BACT = BACT-1
  end
end

R.C = 1-R.C;

if(R.A>0) then
 R.A = R.A * 2;
end

end

--
function POINTS()

local Ob = MLIST[1+MLPTRJ];		-- last move
local bo = nil;
local j = 0;
local pc_white = false;
local colmoved = false;
local goPT20 = false;
local goPT23 = false;

MTRL = 0;

BRDC = 0;

PTSL = 0;

PTSW1 = 0;

PTSW2 = 0;

PTSCK = 0;

	-- scan board squares
for j=21, 98, 1 do

M3 = j;

bo = BOARD[1+M3];
R.A = 0;
T3 = 0;

if(bo.p>0) then
 if(bo.p==0xFF) then
   R.A = 3;
 else
  pc_white = (bo.c==0);
  colmoved = (COLOR == iif(pc_white, 0, 0x80));
  T3 = bo.p;

  if(T3>PAWN) then

   if(T3>BISHOP) then

    if(T3==KING) then

     if(bo.f4>0) then
       BRDC = BRDC + iif(pc_white,6,-6);
     end
    else
     if((MOVENO<7) and (bo.f3>0)) then
       BRDC = BRDC - iif(pc_white,2,-2);
     end
    end

   else
    if(bo.f3==0) then
      BRDC = BRDC - iif(pc_white,2,-2);
    end
   end

  end

 end
end


	-- if board square
if(R.A==0) then

WACT = 0;
BACT = 0;
ATKLSTW = {};
ATKLSTB = {};

T1 = 7;
ATTACK();	-- call attacker finding + save

BRDC = BRDC + (WACT - BACT);

goPT20 = false;
goPT23 = false;

R.D=0; -- material on square

if(T3>0) then

  XCHNG();
  if(R.E~=0) then

    R.D = R.D - 1;
    if(colmoved) then

      if(R.E>PTSL) then

       PTSL = R.E;
       if(M3==Ob.MLTOP) then
         PTSCK = M3;
       end
      end
      goPT23 = true;

    else
     goPT20 = true;
    end

  else
    goPT23 = true;
  end
end

if(goPT20) then

 R.A = R.E;

 if(R.A>PTSW1) then
  R.A = PTSW1;
  PTSW1 = R.E;
 end

 if(R.A>PTSW2) then
  PTSW2 = R.A;
 end

 goPT23=true;

end

if(goPT23) then

 MTRL = MTRL + iif(pc_white, R.D, -R.D );

end

end -- square

end -- board scan

if(PTSCK~=0) then

  PTSW1 = PTSW2;
  PTSW2 = 0;
end

R.B = PTSL;
if(R.B>0) then
  R.B = R.B - 1;
end

R.A = PTSW1;
if(R.A~=0) then
  R.A = PTSW2;
  if(R.A~=0) then
   R.A = (R.A-1)/2;
  end
end
R.A = R.A - R.B;
if(COLOR~=0) then
 R.A = -R.A;
end

R.B = R.A + MTRL - MV0;

R.A = 30;
LIMIT();

R.E = R.A;

R.B = BRDC - BC0;

if(PTSCK~=0) then
 R.B=0;
end

R.A = 6;
LIMIT();
R.D = R.A;

R.A = (R.E*4) + R.D;

R.A = iif((COLOR==0) , -R.A , R.A) + 0x80;

VALM = R.A + (math.random(6)-3);	-- lets play different game

Ob.MLVAL = VALM;

end


--
function LIMIT()

if(R.B<0) then
  R.A=-R.A;
  if( R.A<R.B ) then
    R.A = R.B;
  end
else
  if( R.A>R.B ) then
    R.A = R.B;
  end
end

end

--
function MOVE()

local ex1 = 2;
local Ob = nil;
local fl = nil;
local bo = nil;
local pw = nil;

while(ex1>0) do

Ob = MLIST[1+MLPTRJ];

M1 = Ob.MLFRP;

M2 = Ob.MLTOP;
fl = Ob.MLFLG;
bo = BOARD[1+M1];

if( fl.f5>0 ) then
  bo.p = 5;
end
pw = (bo.c==0);

if(bo.p==QUEEN) then
   POSQ[1+iif(pw,0,1)]=M2;
else
 if(bo.p==KING) then
   if(fl.f6>0) then
     bo.f4=1;
   end
   POSK[1+iif(pw,0,1)]=M2;
 else
   if(bo.p==ROOK) then
    if(fl.f6>0) then
     bo.f4=1;
    end
   end
 end
end

bo.f3 = 1;

BOARD[1+M2] = BO_cl(bo);

BOARD[1+M1] = BO_(0,0);

if((ex1==2) and (fl.f6>0)) then

  MLPTRJ = MLPTRJ + 1;

else

   if(fl.p==QUEEN) then
     POSQ[1+(1-iif(pw,0,1))]=0;
   end
   ex1 = ex1 - 1;
end

ex1 = ex1 - 1;

end

end

--
function UNMOVE()

local ex1 = 2;
local Ob = nil;
local fl = nil;
local bo = nil;
local pw = nil;
local piece2 = nil;

while(ex1>0) do

Ob = MLIST[1+MLPTRJ];

M1 = Ob.MLFRP;

M2 = Ob.MLTOP;

fl = Ob.MLFLG;
bo = BOARD[1+M2];

if( fl.f5>0 ) then
  bo.p = 1;
end

pw = (bo.c==0);

if(bo.p==QUEEN) then
  POSQ[1+iif(pw,0,1)]=M1;
else
 if(bo.p==KING) then
   POSK[1+iif(pw,0,1)]=M1;
 end
end


if((bo.f4>0) or (fl.f4>0)) then
 bo.f3=0;	--undo first move - no movements before
 bo.f4=0;
end

BOARD[1+M1] = BO_cl(bo);
BOARD[1+M2] = BO_cl(fl.bo);

if((ex1==2) and (fl.f6>0)) then

  MLPTRJ = MLPTRJ - 1;

else

   MLPTRJ = Ob.MLPTR;
   if(fl.p==QUEEN) then
     POSQ[1+(1-iif(pw,0,1))]=M2;
   end
   ex1 = ex1 - 1;
end

ex1 = ex1 - 1;

end

end

--
function DO_UNDO()

 local Ob=nil;
 local lastmv=nil;

 if(MLPTRJ>=0) then

  PMATE = 0;

  BOARD[1+ POSK[1+0] ] = BO_( KING, WHITE );
  BOARD[1+ POSK[1+1] ] = BO_( KING, BLACK );

  Ob= MLIST[1+MLPTRJ];
  lastmv=Ob.move;
  UNMOVE();

    -- set pointer to previous move
  while((MLPTRJ>=0) and (MLIST[1+MLPTRJ].move==lastmv)) do
    MLPTRJ = MLIST[1+MLPTRJ].MLPTR;
  end

  COLOR = (0x80 - COLOR);
  if(COLOR>0) then
    MOVENO = MOVENO - 1;
  end

 end
end

--
function SORTM()

local MLf = PLYIX[1+MLPTRI];
local MLt = MLNXT;
local sortmas={};
local t = 0;
local i = 0;
local cnt=0;
local Ob = nil;
local Ob2 = nil;

for t=MLf, MLt, 1 do

 if(no_cs_enp(t)) then

  MLPTRJ=t;
  Ob = MLIST[1+MLPTRJ];
  EVALMV();
  Ob.MLVAL = VALM;
  Ob.sorted = 0;
  sortmas[1+cnt]=VALM;
  cnt = cnt + 1;
 end
end

table.sort( sortmas );

for i=0, cnt-1, 1 do

 for t=MLf, MLt, 1 do

  if(no_cs_enp(t)) then

   Ob = MLIST[1+t];
   if((Ob.sorted==0) and (Ob.MLVAL==sortmas[1+i])) then

    Ob.sorted=1
    MLNXT = MLNXT + 1;
    MLIST[1+MLNXT]=Ob;		-- just use large array of objects without swaping at all

    if(Ob.MLFLG.f6>0) then
      t = t + 1;
      Ob2=MLIST[1+t];	-- if double move
      Ob2.sorted=1;
      Ob2.MLVAL=Ob.MLVAL;
      MLNXT = MLNXT + 1;
      MLIST[1+MLNXT]=Ob2;
    end

    break;
   end
  end

 end

end

PLYIX[1+MLPTRI]=MLt+1;	-- new pointer to sorted list (takes x2 space)

end

--
function EVALMV()

local t0=MLPTRJ;
MOVE();
INCHK();

if(R.A>0) then
 VALM = 0;
else
	-- legal move
   PINFND();
   POINTS();
end
UNMOVE();
MLPTRJ = t0;

end


--
function FNDMOV()

local t=0;
local j=0;

BESTM = -1;

if(MOVENO==1) then
 BOOK();
 return;
end

NPLY = 0;

PLYIX = {};
MLPTRI = -1;

SCRIX=0;
SCORE={};


for j=0, PLYMAX+2, 1 do
 SCORE[1+j]=0;
end

BC0 = 0;

MV0 = 0;

PINFND();

POINTS();

BC0 = BRDC;

MV0 = MTRL;

local nextply=false;
wasasc=false;

t = 0;

local Ob = nil;
local goFM19 = false;
local goFM35 = false;

while(NPLY>=0) do

if(wasasc) then

  wasasc=false;
  t = MLPTRJ + 1; -- just next element in list

else


 NPLY = NPLY + 1;

 nextply=false;

 MATEF = 0;

 GENMOV();

 if(NPLY <= PLYMAX) then
   SORTM()
 end

 t = PLYIX[1+MLPTRI];

end

while( table.getn(MLIST)>t and MLIST[1+ PLYIX[1+MLPTRI] ].MLPTR == MLIST[1+t].MLPTR ) do

 if(no_cs_enp(t)) then

 nodes = nodes + 1;

 MLPTRJ=t;
 Ob=MLIST[1+t];

 goFM19 = false;
 goFM35 = false;

if(NPLY >= PLYMAX) then

  MOVE();
  MLPTRJ = t;

  INCHK();

  if(R.A>0) then

    undodbl();
    UNMOVE();
    MLPTRJ = t;     -- and go FM15 - next move of list

  else

   if(NPLY == PLYMAX) then

     COLOR = (0x80 - COLOR);
     INCHK();
     COLOR = (0x80 - COLOR);
     if(R.A==0) then
       goFM35 = true;
     else
       goFM19 = true;
     end
   else
     goFM35=true;
   end

  end

else

  if(Ob.MLVAL~=0) then

    MOVE();
    MLPTRJ = t;
    goFM19 = true;
  end

end

   -- timeout
if(goFM19) then
  if( (NPLY>2) and ((sectime() - started)>timeout) ) then
    goFM35 = true;
    goFM19 = false;
  end
end

if(goFM19) then

  COLOR = (0x80 - COLOR);

  if(COLOR==0) then
    MOVENO = MOVENO + 1;
  end

  SCRIX = SCRIX + 1;
  SCORE[1+(SCRIX+1)] = SCORE[1+(SCRIX-1)];

  nextply=true;

  break; -- go to FM5

end

if(goFM35) then

   PINFND();
   POINTS();
   undodbl();
   UNMOVE();

   MLPTRJ = t;
   R.A = VALM;

   if( jmpFM36() ) then
     return;
   end
end

 end

 t = t + 1;

end	-- FM15

if((not nextply) and (not wasasc)) then

 -- FM25
 if(MATEF>0) then
    -- FM30
   if(NPLY==1) then
     return;
   end
   ASCEND();
   R.A = SCORE[1+(SCRIX+2)];
   if( jmpFM37() ) then
     return;
   end

 else

  -- checkmate detection is modified in JS version

  if(CKFLG==0) then
    R.A = 0x80;	-- stalemate
  else

    if((COLOR~=KOLOR) and (NPLY<3)) then
      PMATE = MOVENO;		-- we see checkmate in next move
    end
    R.A = 0xFF;		-- checkmate
  end

  if(NPLY==1) then
     return;
  end
  if((COLOR~=KOLOR) and jmpFM36() ) then
      return;	-- otherwise ascend
  end
  if(not wasasc) then
     ASCEND();
  end

 end
end

end	-- FM5

end

--
function jmpFM36()

 MATEF = 1;
 return jmpFM37();
end

--
function jmpFM37()

 local mateflag = ((R.A==0xFF) and (NPLY<3));

 local sc=SCORE[1+SCRIX];	 -- -2ply

 if( (R.A<=sc) and (NPLY>1) ) then

   ASCEND(); -- and go FM15

 else

	-- NEG is kinda invertion of score
   R.A=0x100-R.A;

   sc=SCORE[1+(SCRIX+1)];	-- -1ply
   if( (R.A>sc) or ((NPLY==1) and mateflag) ) then

     SCORE[1+(SCRIX+1)]=R.A;

     if(NPLY==1) then
          BESTM = MLPTRJ;
          R.A = SCORE[1+1];
     else
      if(NPLY==2) then

        if(mateflag) then

          BESTM = MLIST[1+MLPTRJ].MLPTR;
          if(KOLOR~=0) then
            PMATE = PMATE - 1;
          end
          ASCEND();
          return true;
        end
      end
     end


   end
 end

 return false;
end

--
function no_cs_enp(ptr)

 local Ob = MLIST[1+ptr];
 local MV = string.upper( Ob.move );
 local fl = Ob.MLFLG;
 local s1 = string.sub(MV,1,2);
 local s2 = string.sub(MV,4,5);
				-- no en-passant, no castling
 return ( (s1~=s2) and ((fl.f6==0) or (string.find("{H1}{A1}{H8}{A8}",s1)==nil)) );
end

--
function undodbl()

 local Ob = MLIST[1+MLPTRJ];
 local fl = Ob.MLFLG;
 if(fl.f6>0) then
   MLPTRJ = MLPTRJ + 1;
 end
end

--
function ASCEND()

COLOR = (0x80 - COLOR);

if(COLOR>0) then
  MOVENO = MOVENO - 1;
end

SCRIX = SCRIX - 1;

NPLY = NPLY - 1;

MLf = PLYIX[1+MLPTRI];

while( table.getn( PLYIX ) > (1+MLPTRI) ) do
  table.remove(  PLYIX );
end

MLPTRI = MLPTRI - 1;

MLPTRJ = MLIST[1+MLf].MLPTR;
local t0 = MLPTRJ;

undodbl();
UNMOVE();

while(not no_cs_enp(t0)) do
 t0 = t0 - 1;
end

MLPTRJ = t0;

MLNXT = MLf-1;

while( table.getn( MLIST ) > 1+(1+MLNXT) ) do
  table.remove(  MLIST );
end

wasasc = true;

end

--
function BOOK()

local r = 0;
local Ob = nil;
local f = nil;

if(KOLOR==0) then

 r = 3*iif(math.random(2)>=1, 0, 1);

else
 Ob = MLIST[1+MLPTRJ];
 f = Ob.MLFRP;

 r = iif( (f==22) or (f==27) or (f==34) or (f>35), r + 9, r + 6 );

end

 M1 = BMOVES[1+(r)];
 M2 = BMOVES[1+(r+1)];
 SCORE[1+0] = BMOVES[1+(r+2)];
 ADMOVE(0);
 BESTM = MLNXT;

end

--
function CPTRMV()

nodes = 0;
started = sectime();

MYMOVE = "";

local bef=BOA();

FNDMOV();

local Ob = nil;
local move = nil;

local aft=BOA();
local diff = cBOAs(bef,aft);
if( string.len(diff)>0 ) then
  print("DEBUG, different pos: ".. diff);
end

if(BESTM>=0) then

 MLPTRJ = BESTM;
 Ob = MLIST[1+MLPTRJ];
 move = string.upper( Ob.move );

 MYMOVE = move;

 print("bestmove: "..move ..", nodes of moves: "..
	string.format("%d",nodes) ..", calc.time: "..
	string.format("%d",(sectime()-started)).."sec." );
 return;

else
 print("no moves");
end

end

--
function FCDMAT()

INCHK();
CKFLG = R.A;

if(R.A>0) then

  if((PMATE>0) or ((COLOR==KOLOR) and (BESTM<0))) then

   print("CHECKMATE.");
   PMATE = 1;
   MYMOVE = "";

   return true;

  else

   print("CHECK+");
  end
end

return false; -- no mate
end

--
function TBPLCL()

local mnr = string.format("%d",MOVENO);
MVENUM = iif((string.len(mnr)<2) , "0" , "")..mnr.." ";

if( not FCDMAT() ) then
 -- print(MVENUM..iif((COLOR==0),"","... "));
end

end

--
function BITASN()

 R.L = math.floor(R.A/10)-1;
 R.H = R.A - ((R.L+1)*10);
 R.L = R.L + 0x30; -- 0
 R.H = R.H + 0x60; -- a

end

--
function PLYRMV( INPUT )

  --computer move
if(INPUT=="COMP") then

  if( PMATE==0 ) then
    KOLOR = COLOR;
    CPTRMV();
    INPUT=MYMOVE;
  end

end

if(INPUT=="UNDO") then
 if(MOVENO>1) then
   DO_UNDO();
   DO_UNDO();
 end
end

if(string.sub(INPUT,3,3)=="-") then

 R.H = string.byte(INPUT,1);
 R.L = string.byte(INPUT,2);
 ASNTBI();	-- from

 R.H = string.byte(INPUT,4);
 R.L = string.byte(INPUT,5);
 ASNTBI();	-- to

 MVEMSG = string.sub(INPUT,1,5);

 VALMOV();

 if(R.A==0) then
  print("move not valid");
 end

 TBPLCL();

end

--DSPBRD();

end

--
function ASNTBI()

R.L = R.L - 0x30;	-- 0
R.H = R.H - 0x40;	-- A
R.A = iif( (R.L>=1 and R.L<=8 and R.H>=1 and R.H<=8) , (10*(R.H+1)) + R.L , -1 );

end

--
function VALMOV()

MLNXT = MLPTRJ;

GENMOV();

R.A = 0;

local Ob = nil;
local MV = nil;
local fl = nil;
local s1 = nil;
local s2 = nil;


local t=MLPTRJ;
while(t<MLNXT) do

 t = t + 1;
 Ob = MLIST[1+t];
 MV = string.upper( Ob.move );
 fl = Ob.MLFLG;

 s1 = string.sub(MV,1,2);
 s2 = string.sub(MV,4,5);
				-- no en-passant, no castling
 if( (MV==MVEMSG) and (s1~=s2) and ((fl.f6==0) or (string.find("{H1}{A1}{H8}{A8}",s1)==nil)) ) then

   MLPTRJ=t;
   MOVE();

   INCHK();
   if(R.A>0) then
    UNMOVE();
    R.A = 0;
   else

     COLOR = (0x80 - COLOR);
     if(COLOR==0) then
       MOVENO = MOVENO + 1;
     end
     --DSPBRD();
     R.A = 1;
   end

   break;

 end
end

end


--
function DSPBRD()

local K=0;
local L=0;
local bo = nil;
local ch = nil;
local s = "";

for K=7,0,-1 do
 s = "";
 for L=0,7,1 do
   bo = BOARD[1+21+(10*K)+L];
   ch = p_piece [ 1+ bo.p ];
   s = s..iif( bo.c==0, string.upper(ch), ch );
 end
 print(s);
end

end

--
function sectime()
 return ( math.floor(os.clock()) );
end



-- Debug-functions
-- returns current board position in string to compare
function BOA()
 local s="";
 local i=0;
 local bo=nil;
 for i=21, 98, 1 do
  bo=BOARD[i];
  s=s..iif(bo.c>0, "b", "w")..string.format("%d",bo.p).." ";
 end
 return s;
end

function sSplit( s1, arr )

 local i=0;
 local s=s1;
 arr = {};
 while(string.len(s)>0) do
  i=string.find(s," ");
  if(i>0) then
    table.insert(arr,string.sub(s,1,i-1));
	s=string.sub(s,i+1);
  else
    table.insert(arr,s);
	s="";
  end
 end
end

-- compares 2 previously saved boards and returns string of differences, if there are
function cBOAs( s1, s2)

 local r="";
 local b1={};
 local b2={};
 sSplit(s1,b1);
 sSplit(s2,b2);
 local i=0;
 for i=21, 98, 1 do
   if(b1[1+i]~=b2[1+i]) then
      r = r..string.format("%d",i).."[".. b1[i]..","..b2[i].."] ";
   end
 end
 return r;
end

-- call after GENMOV
function DspMoves()

 local t = PLYIX[1+MLPTRI];
 local Ob = MLIST[1+t];
 local fl = nil;
 local pre = Ob.MLPTR;
 local s = "";

 while( table.getn( MLIST )>t ) do

  Ob = MLIST[1+t];
  fl = Ob.MLFLG;

  if(Ob.MLPTR ~=pre) then
    break;
  end
  s = s..Ob.move..iif( (fl.f6>0), "[dbl] ", " " );
  t = t + 1;

 end
 print(s);

end

--
function DRIVER()

print("Sargon port to Lua.");

INITBD();

DSPBRD();

KOLOR = 0x80;	-- white=0, black=0x80

end

-- enters movelist without promotions (queens by default)
function ENTERLIST(str)
 local i=1;
 local mvstr="";
 while(i<string.len(str)) do
   mvstr = string.upper( string.sub(str,i,i+4) );
   PLYRMV( string.sub(mvstr,1,2).."-"..string.sub(mvstr,3,4) );
   i = i + 5;
 end
end


-- AI vs AI game for testing...
function autogame()

  local pgn = "";
  local mc = 0;
  local mlist = "";

  DRIVER();

  print("Autogame!");

  while(true) do

    PLYRMV( "COMP");

    if(BESTM>=0) then
      if(mc%2==0) then
        pgn = pgn..string.format( "%d",math.floor(mc/2)+1 )..".";
      end

      pgn = pgn..PgnMove(BESTM).." ";
    end

    mlist = mlist .. " " .. MYMOVE;


	if( string.len(MYMOVE)==0 ) then

	  if(CKFLG==0) then
	   print("1/2-1/2");
	  else
	    if(COLOR==0) then
	      print("0-1");
	    else
	      print("1-0");
	    end
	  end

	  print(pgn);
	  --print(mlist);
	  break;
	end

    DSPBRD();

    mc = mc + 1;
  end
end

-- pgn move notation from given MLIST[idx]
function PgnMove( idx )

  local Ob = nil;
  local pc = nil;
  local capt = nil;
  local bo = nil;
  local fl = nil;
  local movestr = "";

  Ob = MLIST[1+BESTM];
  bo = BOARD[1+Ob.MLTOP];
  fl = Ob.MLFLG;
  pc = iif( (bo.p<2) or (fl.f5>0), "", string.upper( p_piece[1+bo.p] ) );
  capt = "-";
  movestr = "";

  if(fl.f6>0) then
   if (string.find("{e1-g1}{e8-g8}",Ob.move)~=0) then
      movestr = "0-0"
   else
     if (string.find("{e1-c1}{e8-c8}",Ob.move)~=0) then
       movestr = "0-0-0"
     else
       capt = "x";
     end
   end
  end

  if(fl.p>0) then
    capt = "x";
  end

  if string.len(movestr)==0 then
	movestr = pc .. string.sub(Ob.move,1,2) .. capt .. string.sub(Ob.move,4,5) ..
	    iif(fl.f5>0,"=q","") .. iif( PMATE>0, "x", iif(CKFLG>0, "+", "") );
  end

  return movestr;
end


----------
--
-- Here it starts
--
----------

DRIVER(); -- to set up new game

-- samples
-- ..... enter list of moves without promoted pieces
--ENTERLIST("e2e4,b7b6,f1c4,c8b7,g1f3,b8c6,e1g1,h7h6");

-- ..... or enter move
--PLYRMV("E2-E4");
--PLYRMV("E7-E5");
--PLYRMV("G1-F3");

-- ..... calculate move
--PLYRMV("COMP");

-- ..... undo last move
--PLYRMV("UNDO");

-- for debugging purposes to generate and display valid moves
--    GENMOV();
--    DspMoves();

autogame();

DSPBRD();

