
require "bit"

--
-- Lua port of OWL CHESS written in Borland Turbo C (year 1992-95)
-- done by http://chessforeva.blogspot.com (year 2017)
--
-- Uses file "Owlbook.dat" - opening book.
--
-- Note:
--  LuaJIT sometimes gives a crash error and throws out a window :/
--  Maybe memory management or garbage collector does it, I donno.
--  There are newer LuaJIT versions also, btw.
--  On Lua works ok.
--

MAXPLY = 5;		-- max.ply
MAXSECS = 8;		-- max.seconds to search

function MOVETYPE()	--struct
 local m = {};
 m.nw1 = 0; -- new and
 m.old = 0;	--   old square
 m.spe = 0; --  Indicates special move:
			-- case movepiece of
			--	king: castling
			--	pawn: e.p. capture
			--	else : pawn promotion
 m.movpiece = 0;	-- moving piece
 m.content = 0;		-- evt. captured piece
 return m;
end

function cloneMove(m) -- construct a new and assign
 local n = {};
 n.nw1 = m.nw1; n.old = m.old; n.spe = m.spe;
 n.movpiece = m.movpiece; n.content = m.content;
 return n;
end

function copyMove(t,f) -- assign values to existing
 t.nw1=f.nw1; t.old=f.old; t.spe=f.spe;
 t.movpiece=f.movpiece; t.content=f.content;
end

function BOARDTYPE()
 local b = {};
 b.piece = 0;
 b.color = 0;
 b.index = 0;
 b.attacked = 0;
 return  b;
end

function PIECETAB()
 local p = {};
 p.isquare = 0;
 p.ipiece = 0;
 return p;
end

function CASTTYPE()
 local c = {};
 c.castsquare = 0;
 c.cornersquare = 0;
 return c;
end

function ATTACKTABTYPE()
 local a = {};
 --  A set of king..pawn.  gives the pieces, which can move to the square
 a.pieceset = 0;
 a.direction = 0;  --  The direction from the piece to the square
 return a;
end


-- (if ? then : else) substitute
function iif(ask, ontrue, onfalse)
 if( ask ) then
  return ontrue;
 end
 return onfalse;
end


-- constants and globals
empty = 0; king = 1; queen = 2; rook = 3; bishop = 4; knight = 5; pawn = 6;	-- pieces
white = 0; black = 1;			-- colours
zero = 0; lng = 1; shrt = 2;		-- castlings


Player = white; Opponent = black;	-- Side to move, opponent
ProgramColor = white;			-- AI side


PiecList = { " ", "K", "Q", "R", "B", "N", "P" };

Pieces = { rook, knight, bishop, queen, king, bishop, knight, rook };	-- [8]
PieceTab = { {}, {} };
Board = {};	-- [0x78]

MovTab = {};
mc = 0;		-- count of moves

OfficerNo = {}; PawnNo = {};	-- [2]

function InsertPiece(p,c,sq)
 Board[1+sq].piece = p;
 Board[1+sq].color = c;
end

function ResetMoves()
   mc = 1;
   MovTab = { MOVETYPE(), MOVETYPE(), MOVETYPE() }
   Mo = MovTab[1+mc]; Mpre = MovTab[1+mc-1];
end

function ClearBoard()
 local sq;
 for sq = 0, 0x77, 1 do
   Board[1+sq] = BOARDTYPE();
 end
end

function ResetGame()

 ClearBoard();
 local i;
 for i = 0, 7, 1 do
  InsertPiece(Pieces[1+i], white, i);
  InsertPiece(pawn, white, i+0x10);
  InsertPiece(pawn, black, i+0x60);
  InsertPiece(Pieces[1+i], black, i+0x70);
 end
 CalcPieceTab();
 Player = white; Opponent = black;	-- Side to move, opponent
 ResetMoves();
 UseLib = 200;

end

--
--  Clears indexes in board and piecetab
--

function ClearIndex()

    local square, col, index;
    for square = 0, 0x77, 1 do
        Board[1+square].index = 16;
    end
    for col = white, black, 1 do
        for index = 0,16,1 do
	    PieceTab[1+col][1+index] = PIECETAB();
        end
    end
    OfficerNo = { -1, -1 }; PawnNo = { -1, -1 };
end


--
--  Calcualates Piece table from scratch
--

function CalcPieceTab()

    local square, piece1, o,p,w,q;

    ClearIndex();

    for piece1 = king, pawn, 1 do
        if(piece1 == pawn) then
            OfficerNo[1+white] = PawnNo[1+white];
            OfficerNo[1+black] = PawnNo[1+black];
        end
        square = 0;
        repeat
            o = Board[1+square];
            if(o.piece == piece1) then
                w = o.color;
                PawnNo[1+w] = PawnNo[1+w] + 1;
                p = PawnNo[1+w];
                q = PieceTab[1+w][1+p];
                q.ipiece = piece1; q.isquare = square;
                o.index = p;
            end
            square = bit.bxor(square,0x77);
            if(bit.band(square,4)==0) then
                if(square >= 0x70) then
                    square = bit.band((square + 0x11), 0x73);
                else
                    square = square + 0x10;
                end
            end
        until (square==0);
    end
end


Depth = 1;		-- search current depth (originally Depth starts from 0)  1..MAXPLY
AttackTab = {};
BitTab = { 0, 1, 2, 4, 8, 0x10, 0x20};	-- [7]
DirTab = { 1, -1, 0x10, -0x10, 0x11, -0x11, 0x0f, -0x0f };	-- [8]
KnightDir = { 0x0E, -0x0E, 0x12, -0x12, 0x1f, -0x1f, 0x21, -0x21 };	-- [8]
PawnDir = { 0x10, -0x10 };	-- [2]
BufCount = 0;
BufPnt = 0;
Next = {};
Buffer = {};
ZeroMove = MOVETYPE();

function CSTPE(n,o)
 local c = {};
 c.castnew = n;
 c.castold = o;
 return c;
end

	-- [2][2] of new,old squares
CastMove = { { CSTPE(2,4), CSTPE(6,4) }, { CSTPE(0x72, 0x74), CSTPE(0x76, 0x74) } };

-- === MOVEGEN ===

function CalcAttackTab()

    local dir, sq, i, o;

    for sq = -0x77, 0x77, 1 do
	AttackTab[1+120+sq] = ATTACKTABTYPE();
    end
    for dir = 7, 0, -1 do
        for i = 1, 7, 1 do
		  o = AttackTab[1+120+(DirTab[1+dir]*i)];
		  o.pieceset = BitTab[1+queen]+BitTab[1 + iif(dir < 4, rook, bishop)];
		  o.direction = DirTab[1+dir];
        end
        o = AttackTab[1+120+DirTab[1+dir]];
        o.pieceset = o.pieceset + BitTab[1+king];
        o = AttackTab[1+120+KnightDir[1+dir]];
        o.pieceset = BitTab[1+knight];
        o.direction = KnightDir[1+dir];
    end
end


--
--  calculate whether apiece placed on asquare attacks the square
--

function PieceAttacks(apiece, acolor, asquare, square)

    local x = square - asquare;
    if(apiece == pawn) then   --  pawn attacks
        return (math.abs(x - PawnDir[1+acolor]) == 1);

        --  other attacks: can the piece move to the square?
    else
	if(bit.band( AttackTab[1+120+x].pieceset, BitTab[1+apiece])~=0) then

        if(apiece == king or apiece == knight) then
            return true;
        else
            --  are there any blocking pieces in between?
            local sq = asquare;
            repeat
                sq = sq + AttackTab[1+120+x].direction;
            until( sq == square or Board[1+sq].piece ~= empty );
            return (sq == square);
        end
	end
    end
    return false;
end


--
--  calculate whether acolor attacks the square with at pawn
--

function PawnAttacks(acolor,square)

    local o;
    local sq = square - PawnDir[1+acolor] - 1;  --  left square
    if(bit.band(sq, 0x88)==0) then
        o = Board[1+sq];
        if(o.piece == pawn and o.color == acolor) then
            return true;
        end
    end
    sq = sq + 2;   --  right square
    if(bit.band(sq, 0x88)==0) then
        o = Board[1+sq];
        if(o.piece == pawn and o.color == acolor) then
            return true;
        end
    end
    return false;
end


--
--  Calculates whether acolor attacks the square
--

function Attacks(acolor, square)

    if(PawnAttacks(acolor, square)) then    --  pawn attacks
        return true;
    end
    --  Other attacks:  try all pieces, starting with the smallest
    local i;
    for i = OfficerNo[1+acolor], 0, -1 do
	local o = PieceTab[1+acolor][1+i];
        if(o.ipiece ~= empty) then
            if(PieceAttacks(o.ipiece, acolor, o.isquare, square)) then
                return true;
            end
        end
    end
    return false;
end


--
--  check whether inpiece is placed on square and has never moved
--

function Check(square, inpiece, incolor)

    local o = Board[1+square];
    if(o.piece == inpiece and o.color == incolor) then
        local dep = mc - 1;
        while (dep>=0 and MovTab[1+dep].movpiece ~= empty) do
            if(MovTab[1+dep].nw1 == square) then
                return false;
            end
            dep = dep - 1;
        end
        return true;
    end
    return false;
end


--
--  Calculate whether incolor can castle
--

function CalcCastling(incolor)

    local square = 0;
    local cast = zero;

    if(incolor == black) then
	square = 0x70;
    end
    if(Check(square + 4, king, incolor)) then  --  check king
        if(Check(square, rook, incolor)) then
            cast = cast + lng;  --  check a-rook
        end
        if(Check(square + 7, rook, incolor)) then
            cast = cast + shrt;  --  check h-rook
        end
    end
    return cast;
end


--
--  check if move is a pawn move or a capture
--

function RepeatMove(move)

    return (move.movpiece ~= empty and move.movpiece ~= pawn  and
              move.content == empty and move.spe==0);
end


--  Count the number of moves since last capture or pawn move
--  The game is a draw when fiftymovecnt = 100

function FiftyMoveCnt()

    local cnt = 0;
    while (cnt<=mc and RepeatMove(MovTab[1+mc - cnt])) do
        cnt = cnt + 1;
    end
    return cnt;
end


--
--  Calculate how many times the move has occurred before
--  The game is a draw when repetition = 3
--  MovTab contains the previous moves
--  When immediate is set, only immediate repetition is checked
--

function Repetition(immediate)

    local lastdep, compdep, tracedep, checkdep, samedepth, tracesq, checksq, repcount, o;

    repcount = 1;

    lastdep = mc;    --  current position
    samedepth = lastdep;
    compdep = samedepth - 4;            --  First position to compare

    --  MovTab contains previous relevant moves
    while (RepeatMove(MovTab[1+lastdep-1]) and (compdep < lastdep  or (not immediate))) do
		lastdep = lastdep - 1;
    end

    if(compdep >= lastdep) then

      checkdep = samedepth;

      while (true) do

        checkdep = checkdep - 1;
        checksq = MovTab[1+checkdep].nw1;
		local f=true;
		tracedep = checkdep + 2;
        while (tracedep < samedepth) do

            if(MovTab[1+tracedep].old == checksq) then
              f=false;
              break;
            end
            tracedep = tracedep + 2;
        end
		if(f) then

		--  Trace the move backward to see if it has been 'undone' earlier
		tracedep = checkdep;
		tracesq = MovTab[1+tracedep].old;
		repeat

			if(tracedep-2 < lastdep) then
				return repcount;
			end
			tracedep = tracedep - 2;
			--  Check if piece has been moved before
			o = MovTab[1+tracedep];
			if(tracesq == o.nw1) then
				tracesq = o.old;
			end
		until ( tracesq  == checksq  and tracedep <= compdep + 1);

		if(tracedep < compdep) then	--  Adjust evt. compdep

			compdep = tracedep;
			if((samedepth - compdep) % 2 == 1) then

				if(compdep == lastdep) then
					return repcount;
				end
				compdep = compdep -1;
			end
			checkdep = samedepth;
		end
		end -- f

        --  All moves between SAMEDEP and compdep have been checked,
        --  so a repetition is found
--TEN :
        if(checkdep <= compdep) then
            repcount = repcount + 1;
            if(compdep - 2 < lastdep) then
				return repcount;
            end
            samedepth = compdep;
            checkdep = compdep;
            compdep = compdep - 2;
        end
      end

    end

    return repcount;
end


--
--  Test whether a move is possible
--
--  On entry:
--   Move contains a full description of a move, which
--   has been legally generated in a different position.
--    MovTab[1+mc] contains last performed move.
--
--  On exit:
--    KillMovGen indicates whether the move is possible
--

function KillMovGen(move)

    local castsq, promote, castdir, o, q;
    local cast=0;
    local killmov = false;

    if((move.spe~=0) and (move.movpiece == king)) then

        cast = CalcCastling(Player);     --  Castling
        castdir = iif((move.nw1 > move.old), shrt , lng );

        if( bit.band(cast, castdir)~=0) then    --  Has king or rook moved before

            castsq =  ((move.nw1 + move.old) / 2);
            --  Are the squares empty ?
            if(Board[1+move.nw1].piece == empty) then
              if(Board[1+castsq].piece == empty) then
                if((move.nw1 > move.old) or (Board[1+move.nw1-1].piece == empty)) then
                  --  Are the squares unattacked
                  if( not Attacks(Opponent, move.old)) then
                    if( not Attacks(Opponent, move.nw1)) then
                      if( not Attacks(Opponent, castsq)) then
                        killmov = true;
                      end
                    end
                  end
                end
              end
            end
        end

    else

      if((move.spe~=0) and (move.movpiece == pawn)) then

            --  E.p. capture
            --  Was the Opponent's move a 2 square move?
		if(Mpre.movpiece == pawn) then
			if(math.abs(Mpre.nw1 - Mpre.old) >= 0x20) then

				q = Board[1+move.old];
				if((q.piece == pawn) and (q.color == Player)) then
					killmov = (move.nw1 == ((Mpre.nw1 + Mpre.old) / 2));
				end
			end
		end

      else

	if(move.spe~=0) then                  --  Normal test
		promote = move.movpiece;   --  Pawnpromotion
		move.movpiece = pawn;
	end

        --  Is the content of Old and nw1 squares correct?
        if(Board[1+move.old].piece == move.movpiece) then
          if(Board[1+move.old].color == Player) then
            if(Board[1+move.nw1].piece == move.content) then
              if(move.content == empty or Board[1+move.nw1].color == Opponent) then

                if(move.movpiece == pawn) then   --  Is the move possible?

                  if(math.abs(move.nw1 - move.old) < 0x20) then
                    killmov = true;
                  else
                    killmov = (Board[1+(move.nw1+move.old) / 2].piece == empty);
                  end

                else
                  killmov = PieceAttacks(move.movpiece, Player,
                                 move.old, move.nw1);
                end
              end
            end
          end
        end

	if(move.spe~=0) then
		move.movpiece = promote;
	end
      end
    end
    return killmov;
end



--
--  Store a move in buffer
--

function Generate()

	BufCount = BufCount + 1;
	Buffer[1+ BufCount] = cloneMove(Next); -- new copied MOVETYPE()
end


--
--  Generates pawn promotion
--

function PawnPromotionGen()

    Next.spe = 1;
    local promote;
    for promote = queen, knight, 1 do
        Next.movpiece = promote;
        Generate();
    end
    Next.spe = 0;
end


--
--  Generates captures of the piece on nw1 using PieceTab
--

function CapMovGen()

    local nextsq, sq, i,o,p;

    Next.spe = 0;
    Next.content = Board[1+Next.nw1].piece;
    Next.movpiece = pawn;
    nextsq = Next.nw1 - PawnDir[1+Player];
    for sq = nextsq-1, nextsq+1, 1 do
        if(sq ~= nextsq) then
          if(bit.band(sq, 0x88)==0) then

            o = Board[1+sq];
            if(o.piece == pawn and o.color == Player) then

                Next.old = sq;
                if(Next.nw1 < 8 or Next.nw1 >= 0x70) then
                    PawnPromotionGen();
                else
                    Generate();
                end
            end
          end
        end
    end

            --  Other captures, starting with the smallest pieces
    for i = OfficerNo[1+Player], 0, -1 do

        o = PieceTab[1+Player][1+i]; p = o.ipiece;
        if(p ~= empty and p ~= pawn) then
          if(PieceAttacks(p, Player, o.isquare, Next.nw1)) then
              Next.old = o.isquare;
              Next.movpiece = p;
              Generate();
          end
        end
    end
end


--
-- generates non captures for the piece on old
--

function NonCapMovGen()

    local first, last, dir, direction, newsq;

    Next.spe = 0;
    Next.movpiece = Board[1+Next.old].piece;
    Next.content = empty;
    --switch (Next.movpiece)

    if(Next.movpiece == king) then
	for dir = 7, 0, -1 do
		newsq = Next.old + DirTab[1+dir];
		if(bit.band(newsq, 0x88)==0) then
		 if(Board[1+newsq].piece == empty) then
                      Next.nw1 = newsq;
                      Generate();
		 end
		end
	end
    else
    if(Next.movpiece == knight) then
 	for dir = 7, 0, -1 do
  		newsq = Next.old + KnightDir[1+dir];
		if(bit.band(newsq, 0x88)==0) then
                  if(Board[1+newsq].piece == empty) then
                      Next.nw1 = newsq;
                      Generate();
                  end
		end
	end
    else
    if(Next.movpiece >= queen and Next.movpiece <= bishop) then
	-- queen,rook,bishop
            first = 7;
            last = 0;
            if(Next.movpiece == rook) then
				first = 3;
            end
            if(Next.movpiece == bishop) then
				last = 4;
            end
            for dir = first, last, -1 do

                direction = DirTab[1+dir];
                newsq = Next.old + direction;
                --  Generate all non captures in the direction
                while (bit.band(newsq, 0x88)==0) do
                    if(Board[1+newsq].piece ~= empty) then
						break;
                    end
                    Next.nw1 = newsq;
                    Generate();
                    newsq = Next.nw1 + direction;
                end
            end
    else
    if(Next.movpiece == pawn) then
            Next.nw1 = Next.old + PawnDir[1+Player];  --  one square forward
            if(Board[1+Next.nw1].piece == empty) then

                if(Next.nw1 < 8 or Next.nw1 >= 0x70) then
                    PawnPromotionGen();
                else
                    Generate();
                    if(Next.old < 0x18 or Next.old >= 0x60) then
                        -- 2 squares forward
                        Next.nw1 = Next.nw1  + (Next.nw1 - Next.old);
                        if(Board[1+Next.nw1].piece == empty) then
							Generate();
                        end
                    end
                end
            end
    end
    end
    end
    end
    -- switch
end


--
--  The move generator.
--  InitMovGen generates all possible moves and places them in a buffer.
--  Movgen will the generate the moves one by one and place them in next.
--
--  On entry:
--    Player contains the color to move.
--    MovTab[1+mc-1] the last performed move.
--
--  On exit:
--    Buffer contains the generated moves.
--
--    The moves are generated in the order :
--      Captures
--      Castlings
--      Non captures
--      E.p. captures
--

function InitMovGen()

    local castdir, sq, index, o;
    Next = MOVETYPE();
    Buffer = {};
    BufCount = 0; BufPnt = 0;
    --  generate all captures starting with captures of
    --  largest pieces
    for index = 1, PawnNo[1+Opponent], 1 do

        o = PieceTab[1+Opponent][1+index];
        if(o.ipiece ~= empty) then

            Next.nw1 = o.isquare;
            CapMovGen();
        end
    end
    Next.spe = 1;
    Next.movpiece = king;
    Next.content = empty;
    for castdir = (lng-1), shrt-1, 1 do
        o = CastMove[1+Player][1+castdir];
        Next.nw1 = o.castnew;
        Next.old = o.castold;
        if(KillMovGen(Next)) then
          Generate();
        end
    end

    --  generate non captures, starting with pawns
    for index = PawnNo[1+Player], 0, -1 do

	o = PieceTab[1+Player][1+index];
        if(o.ipiece ~= empty) then

            Next.old = o.isquare;
            NonCapMovGen();
        end
    end

    if(Mpre.movpiece == pawn) then   --  E.p. captures
        if(math.abs(Mpre.nw1 - Mpre.old) >= 0x20) then

            Next.spe = 1;
            Next.movpiece = pawn;
            Next.content = empty;
            Next.nw1 = (Mpre.nw1 + Mpre.old) / 2;
            for sq = Mpre.nw1-1, Mpre.nw1+1, 1 do
                if(sq ~= Mpre.nw1) then
                    if(bit.band(sq, 0x88)==0) then

                        Next.old = sq;
                        if(KillMovGen(Next)) then
                          Generate();
                        end
                    end
                end
            end
        end
    end
end


--
--  place next move from the buffer in next.
--  Generate zeromove when there are no more moves.
--


function MovGen()

    if(BufPnt >= BufCount) then
        Next = ZeroMove;
    else
        BufPnt = BufPnt + 1;
        Next = Buffer[1+ BufPnt ];
    end
end

--
--  Test if the move is legal for color == player in the
--  given position
--

function IllegalMove(move)

   Perform(move, false);
   local illegal = Attacks(Opponent, PieceTab[1+Player][1+0].isquare);
   Perform(move, true);
   return illegal;
end

--
--  Prints comment to the game (check, mate, draw, resign)
--


function Comment()

    local s = "";

    local possiblemove = false;
    local checkmate = false;

    InitMovGen();
    local i;
    for i=1, BufCount, 1 do
        MovGen();
        if( not IllegalMove(Next)) then
          possiblemove = true;
          break;
        end
    end

    local check = Attacks(Opponent, PieceTab[1+Player][1+0].isquare);  --calculate check
    --  No possible move means checkmate or stalemate
    if( not possiblemove) then

        if(check) then

            checkmate = true;
            s = s .. "CheckMate! " .. iif(Opponent==white ,"1-0" , "0-1");
        else
            s = s .. "StaleMate! 1/2-1/2";
        end
    else
        if(MainEvalu >= MATEVALUE - DEPTHFACTOR * 16) then

            local nummoves = math.floor( ((MATEVALUE - MainEvalu + 0x40) / (DEPTHFACTOR * 2)) );
            if(nummoves>0) then
              s = s .. "Mate in " .. nummoves .. " move" .. iif((nummoves > 1) ,"s" ,"") .. "!";
            end
        end
    end

    if(check and (not checkmate)) then
		s = s .. "Check!";
    else  --test 50 move rule and repetition of moves

      if(FiftyMoveCnt() >= 100) then

         s = s .. "Draw, 50 Move rule";
      else
         if(Repetition(false) >= 3) then

            s = s .. "Draw, 3 fold Repetition";
         else                --Resign if the position is hopeless
            if(Opponent==ProgramColor and (-25500 < MainEvalu and MainEvalu < -0x880)) then
               s = s .. iif(Opponent==white, "White", "Black") .. " resigns";
            end
         end
      end
    end

    return s;
end


function CHR(n)
    return string.char(n)
end
function sq2str( square )
	return CHR(97+bit.band(square,7)) .. CHR(49+bit.rshift(square,4));
end


--
--  convert a move to a string
--


function MoveStr(move)

    if(move.movpiece ~= empty) then

        if((move.spe~=0) and move.movpiece == king) then  --  castling

            return "O-O" .. iif((move.nw1 > move.old) , "" , "-O");

        else

            local s="";
            local piece = Board[1+ move.old ].piece;
            local ispawn = (piece == pawn);
            local c = (move.content ~= empty) or
				( ispawn and
				math.abs( math.abs(move.nw1 - move.old)-0x10 )==1 );
            local p = (ispawn and (move.movpiece<6));
            if( not ispawn) then
			  s = s .. PiecList[1+ move.movpiece];
            end
            s = s .. sq2str(move.old);
            s = s .. iif(c , 'x' , '-');
            s = s .. sq2str(move.nw1);
            if(p) then
			  s = s .. "=" ..  PiecList[1+ move.movpiece];
            end
            return s;
        end
    end
    return "?";
end



-- generates string of possible moves,
-- does not include check,checkmate,stalemate flags
function GenMovesStr()

    local s = "";

    InitMovGen();
    local i;
    for i=1, BufCount, 1 do
        MovGen();
        if( not IllegalMove(Next)) then
		  s = s .. "," .. MoveStr( Next );
        end
    end
    return string.sub(s,2);
end

function printboard()

 local v,h,o,p;

 for v = 7, 0, -1 do
  local s = "";
  for h=0, 7, 1 do

	o = Board[1+ (v*16)+h ];
	p = ".";
	if( o.piece ~= 0 ) then
	  p = PiecList[1+o.piece];
	end

	if(o.color == black) then
	  p = string.lower(p);
	end
	s = s .. p;
  end
  print(s);
 end
end

-- === DO MOVE, UNDO MOVE ===

--
--  move a piece to a new location on the board
--

function MovePiece( nw1, old )

    local n = Board[1+nw1];
    local o = Board[1+old];
    Board[1+nw1] = o; Board[1+old] = n;
    PieceTab[1+o.color][1+o.index].isquare = nw1;
end

--
--  Calculate the squares for the rook move in castling
--

function GenCastSquare( nw1, Cast )

    if(bit.band(nw1, 7) >= 4) then	-- short castle

        Cast.castsquare = nw1 - 1;
        Cast.cornersquare = nw1 + 1;

    else                           	-- long castle

        Cast.castsquare = nw1 + 1;
        Cast.cornersquare = nw1 - 2;
    end
end


--
--  This function used in captures.  insquare must not be empty.
--

function DeletePiece(insquare)

    local o = Board[1+insquare];
    o.piece = empty;
    PieceTab[1+o.color][1+o.index].ipiece = empty;
end


--
--  Take back captures
--

function InsertPTabPiece( inpiece, incolor, insquare )

    local o = Board[1+insquare];
    q = PieceTab[1+incolor][1+o.index];
    o.piece =  inpiece; q.ipiece  = inpiece;
    o.color = incolor;
    q.isquare = insquare;
end


--
--  Used for pawn promotion
--

function ChangeType( nwtype, insquare )

    local o = Board[1+insquare];
    o.piece = nwtype;
    PieceTab[1+o.color][1+o.index].ipiece = nwtype;
    if(OfficerNo[1+o.color] < o.index) then
		OfficerNo[1+o.color] = o.index;
    end
end


--
-- Do move
--
function DoMove( move )

 Perform( move, false );
 Player = 1-Player;
 Opponent = 1-Opponent;
end

--
-- Undo move
--
function UndoMove( move )

 Player = 1-Player;
 Opponent = 1-Opponent;
 unPerform();
end

--
--  Perform or take back move (takes back if resetmove is true),
--  and perform the updating of Board and PieceTab.  Player must
--  contain the color of the moving player, Opponent the color of the
--  Opponent.
--
--  MovePiece, DeletePiece, InsertPTabPiece and ChangeType are used to update
--  the Board module.
--


function sqByAt(square)
	return ((string.byte(square,1)-97) +
		(0x10*(string.byte(square,2)-49)));
end

function DoMoveByStr( mstr )

 local ret = "";
 local old = sqByAt( string.sub(mstr,1,2) );
 local nw1 = sqByAt( string.sub(mstr,3,4) );

 InitMovGen();
 local i;
 for i=1, BufCount, 1 do

	MovGen();
	if(Next.old == old and Next.nw1 == nw1  and
		(string.len(mstr)<5  or
		((Next.spe~=0) and
		PiecList[1+Next.movpiece]==
			string.upper( string.sub(mstr,5,5) ) ))) then

			ret = MoveStr( Next );
			DoMove( Next );
			break;
	end
 end
 return ret;
end

function Perform( move, resetmove )

    if(resetmove) then

        MovePiece(move.old, move.nw1);
        if(move.content ~= empty) then
            InsertPTabPiece(move.content, Opponent, move.nw1);
        end

    else

        if(move.content ~= empty) then
            DeletePiece(move.nw1);
        end
        MovePiece(move.nw1, move.old);
    end

    if(move.spe~=0) then

        if(move.movpiece == king) then

	    local Cast = CASTTYPE();
            GenCastSquare(move.nw1, Cast);
            if(resetmove) then
                MovePiece(Cast.cornersquare, Cast.castsquare);
            else
                MovePiece(Cast.castsquare, Cast.cornersquare);
            end

        else

            if(move.movpiece == pawn) then
                local epsquare = bit.band(move.nw1,7) +
					bit.band(move.old,0x70); -- E.p. capture
                if(resetmove) then
                    InsertPTabPiece(pawn, Opponent, epsquare);
                else
                    DeletePiece(epsquare);
                end
            else
                if(resetmove) then
                    ChangeType(pawn, move.old);
                else
                    ChangeType(move.movpiece,move.nw1);
                end
            end
        end
    end

    if(resetmove) then
		mc = mc - 1;
		table.remove(MovTab);
    else

		MovTab[1+mc] = cloneMove(move);
		mc = mc + 1;
		if( table.getn(MovTab)<=mc ) then
			MovTab[1+mc] = MOVETYPE();
		end
    end
    Mo = MovTab[1+mc];
    Mpre = MovTab[1+mc-1];
end

-- simply undo last move in searching
function unPerform()
  Perform( Mpre, true )
end

--
-- Compare two moves
--

function EqMove( a, b )

 return (a.movpiece == b.movpiece and a.nw1 == b.nw1 and a.old == b.old  and
		a.content == b.content and a.spe == b.spe);
end

-- === EVALUATE ===

-- creates objects for 3-dim arrays
function arr2xN(n)

 local a={{},{}};
 local i;
 for i=1,n,1 do
   a[1][i]= {}; a[2][i]= {};
 end
 return a;
end

TOLERANCE = 8; --  Tolerance width
EXCHANGEVALUE =32; --  Value for exchanging pieces when ahead (not pawns)
ISOLATEDPAWN = 20; --  Isolated pawn.  Double isolated pawn is 3 * 20
DOUBLEPAWN = 8; --  Double pawn
SIDEPAWN = 6; --  Having a pawn on the side
CHAINPAWN = 3; --  Being covered by a pawn
COVERPAWN = 3; --  covering a pawn
NOTMOVEPAWN = 2; --  Penalty for moving pawn
BISHOPBLOCKVALUE = 20; --  Penalty for bishop blocking d2/e2 pawn
ROOKBEHINDPASSPAWN = 16; --  Bonus for Rook behind passed pawn

-- constants and globals

PieceValue = { 0, 0x1000, 0x900, 0x4c0, 0x300, 0x300, 0x100 };	-- [7]
distan = { 3, 2, 1, 0, 0, 1, 2, 3 };	-- [8]
    --  The value of a pawn is the sum of Rank and file values.
    --  The file value is equal to PawnFileFactor * (Rank Number + 2)
pawnrank = { 0, 0, 0, 2, 4, 8, 30, 0 };	-- [8]
passpawnrank = {0, 0, 10, 20, 40, 60, 70, 0};	-- [8]
pawnfilefactor = {0, 0, 2, 5, 6, 2, 0, 0};	-- [8]
castvalue = { 4, 32 };	-- [2]  --  Value of castling

filebittab = { 1, 2, 4, 8, 0x10, 0x20, 0x40, 0x80 };	-- [8]
totalmaterial = 0;
pawntotalmaterial = 0;
material = 0;
  --  Material level of the game
  --    (early middlegame = 43 - 32, endgame = 0)
materiallevel = 0;
squarerankvalue = { 0, 0, 0, 0, 1, 2, 4, 4 };	-- [8]

mating = false;  --  mating evaluation function is used

PVTable = arr2xN(7); -- [2][7][0x78]

function PAWNBITTYPE()
 local p = {};
 p.one = 0;
 p.dob = 0;
 return p;
end

function copyPwBt(t,f)
 t.one=f.one;
 t.dob=f.dob;
end

function PwBtList()
 local a = {};
 local i;
 for i=0, MAXPLY, 1 do
   a[1+i] = PAWNBITTYPE();
 end
 return a;
end

pawnbit = {};

MAXINT = 32767;

RootValue = 0;

bitcount = {};	-- count the number of set bits in b (0..255)
function prepareBitCounts()

 local b,c;
 local i;
 for i=0, 255, 1 do

   b = i;
   c = 0;
   while (b~=0) do

    if(bit.band(b,1)~=0) then
      c = c + 1;
    end

    b = bit.rshift(b,1);
   end
   bitcount[1+i] = c;
 end
end

prepareBitCounts();	-- calculate



--
--  Calculate value of the pawn structure in pawnbit[1+color][1+depth]
--

function pawnstrval( depth, color)

	--  contains FILEs with isolated pawns

    local o = pawnbit[1+color][1+depth];
    local v = o.one;
    local d = o.dob;
    local l = bit.lshift(v,1);
    local r = bit.rshift(v,1);

    local iso = bit.band( v ,  bit.bnot( bit.bor( l , bit.rshift(v,1)) ) );
    return (-(bitcount[1+d] * DOUBLEPAWN +
		bitcount[1+iso] * ISOLATEDPAWN +
		bitcount[1+ bit.band(iso,d)] * ISOLATEDPAWN * 2));
end


--
--  calculate the value of the piece on the square
--

function PiecePosVal( piece, color, square )

    return (PieceValue[1+piece] + PVTable[1+color][1+piece][1+square]);
end

--
--  calculates piece-value table for the static evaluation function
--

function CalcPVTable()

    --  Bit tables for static pawn structure evaluation
    local pawnfiletab, bt, oppasstab, behindoppass,
        leftsidetab, rightsidetab, sidetab, leftchaintab,
        rightchaintab, chaintab, leftcovertab, rightcovertab;

    --  Importance of an attack of the square
    local attackvalue = {{},{}};	--[2][0x78]

    local pawntab = {{},{}};	-- [2][8]

    --  Value of squares controlled from the square
    local pvcontrol = arr2xN(5); --[2][5][0x78]

    local losingcolor;     --  the color which is being mated
    local posval;                --  The positional value of piece
    local attval;                --  The attack value of the square
    local line;             --  The file of the piece
    local rank;             --  The rank of the piece
    local dist, kingdist;       --  Distance to center, to opponents king
    local cast;             --  Possible castlings
    local direct;              --  Indicates direct attack
    local cnt;                   --  Counter for attack values
    local strval;                --  Pawnstructure value
    local color, oppcolor; --  Color and opponents color
    local piececount;      --  Piece counter
    local square;         --  Square counter
    local dir;               --  Direction counter
    local sq;         --  Square counter
    local t,t2,t3;           --  temporary junk
    local o,p,v,q, k,w;

    --  Calculate SAMMAT, PAWNSAMMAT and Material
    material = 0;
    pawntotalmaterial = 0;
    totalmaterial = 0;
    mating = false;

    for square = 0, 0x77, 1 do
        if(bit.band(square, 0x88)==0) then

            o = Board[1+square]; p = o.piece;
            if(p ~= empty) then
                if(p ~= king) then

                    t = PieceValue[1+p];
                    totalmaterial = totalmaterial + t;
                    if(p == pawn) then
                        pawntotalmaterial = pawntotalmaterial + PieceValue[1+pawn];
                    end
                    if(o.color == white) then
					 t = -t;
                    end
                    material = material - t;
                end
            end
	end
    end
    materiallevel = math.floor( math.max(0, totalmaterial - 0x2000) / 0x100 );
    --  Set mating if weakest player has less than the equivalence
    -- of two bishops and the advantage is at least a rook for a bishop
    losingcolor = iif((material < 0) , white , black);
    v = math.abs(material);
    mating = ((totalmaterial - v) / 2 <= PieceValue[1+bishop] * 2)
        and (v >= PieceValue[1+rook] - PieceValue[1+bishop]);
    --  Calculate ATTACKVAL (importance of each square)
    for rank = 0, 7, 1 do
        for line = 0, 7, 1 do

            square = (rank*16) + line;
            attval = math.max(0, 8 - 3 * (distan[1+rank] + distan[1+line]));
                    --  center importance
                    --  Rank importance
            for color = white, black, 1 do

                attackvalue[1+color][1+square] =
					bit.rshift( (squarerankvalue[1+rank] * 3 *
					(materiallevel + 8)) , 5) + attval;
                square = bit.bxor( square, 0x70 );
            end
        end
    end

    for color = white, black, 1 do

        oppcolor = 1-color;
        cast = CalcCastling( oppcolor );
        if(cast ~= shrt and materiallevel > 0) then
            --  Importance of the 8 squares around the opponent's King
        for dir = 0, 7, 1 do
            sq = PieceTab[1+oppcolor][1+0].isquare + DirTab[1+dir];
            if(bit.band(sq, 0x88)==0) then
				q = attackvalue[1+color];
                q[1+sq] = q[1+sq] + bit.rshift((12 * (materiallevel + 8)), 5);
            end
        end
	end
    end

    --  Calculate PVControl
    for square = 0x77, 0, -1 do
        if(bit.band(square, 0x88)==0) then
            for color = white, black, 1 do
                for piececount = rook, bishop, 1 do
                    pvcontrol[1+color][1+piececount][1+square] = 0;
                end
            end
        end
    end

    for square = 0x77, 0, -1 do
        if(bit.band(square, 0x88)==0) then
            for color = white, black, 1 do

                for dir = 7, 0, -1 do

                    piececount = iif((dir < 4) , rook , bishop);
                --  Count value of all attacs from the square in
                --  the Direction.
                --  The Value of attacking a Square is Found in ATTACKVAL.
                --  Indirect Attacks (e.g. a Rook attacking through
                --  another Rook) counts for a Normal attack,
                --  Attacks through another Piece counts half
                    cnt = 0;
                    sq = square;
                    direct = true;
                    repeat

                        sq = sq + DirTab[1+dir];
                        if(bit.band(sq, 0x88)~=0) then
							break;	--goto TEN
                        end
                        t = attackvalue[1+color][1+sq];
                        if( direct ) then
                            cnt = cnt + t;
                        else
                            cnt = cnt + bit.rshift(t,1);
                        end
                        p = Board[1+sq].piece;
                        if(p ~= empty) then
                            if((p ~= piececount) and (p ~= queen)) then
                                direct = false;
                            end
                        end
                    until (p == pawn);
--TEN:
                    q = pvcontrol[1+color][1+piececount];
                    q[1+square] = q[1+square] + bit.rshift(cnt, 2);
                end
            end
           end
    end

    --  Calculate PVTable, value by value
    for square = 0x77, 0, -1 do
      if(bit.band(square, 0x88)==0) then

         for color = white, black, 1 do

            oppcolor = 1- color;
            line = bit.band(square, 7);
            rank = bit.rshift(square, 4);
            if(color == black) then
				rank = 7 - rank;
            end
            dist = distan[1+rank] + distan[1+line];
            v = PieceTab[1+oppcolor][1+0].isquare;
            kingdist = math.abs( bit.rshift(square,4) - bit.rshift(v,4)) +
			bit.band((square - v), 7);
            for piececount = king, pawn, 1 do

                posval = 0;        --  Calculate POSITIONAL Value for
                                   --  The piece on the Square
                if(mating and (piececount ~= pawn)) then

                    if(piececount == king) then
                        if(color == losingcolor) then  --  Mating evaluation

                            posval = 128 - 16 * distan[1+rank] - 12 * distan[1+line];
                            if(distan[1+rank] == 3) then
                                posval = posval - 16;
                            end

                        else

                            posval = 128 - 4 * kingdist;
                            if((distan[1+rank] >= 2) or (distan[1+line] == 3)) then
                                posval = posval - 16;
                            end
                        end
                    end
                else

                    t = pvcontrol[1+color][1+rook][1+square];
                    t2 = pvcontrol[1+color][1+bishop][1+square];
                    --  Normal evaluation function

			-- switch

                        if(piececount == king) then
                            if(materiallevel <= 0) then
                              posval = -2 * dist;
                            end
                        else
                        if(piececount == queen) then
                            posval = bit.rshift( (t + t2), 2);
                        else
                        if(piececount == rook) then
                            posval = t;
                        else
                        if(piececount == bishop) then
                            posval = t2;
                        else
                        if(piececount == knight) then
                            cnt = 0;
                            for dir = 0, 7, 1 do

                                sq = square + KnightDir[1+dir];
                                if(bit.band(sq, 0x88)==0) then
                                    cnt = cnt +attackvalue[1+color][1+sq];
                                end
                            end
                            posval = bit.rshift(cnt, 1) - dist * 3;
                        else
                        if(piececount == pawn) then
                            if((rank ~= 0) and (rank ~= 7)) then
                                posval = pawnrank[1+rank] +
                                  pawnfilefactor[1+line] * (rank + 2) - 12;
                            end
                        end
                        end
                        end
                        end
                        end
                        end

                end
                PVTable[1+color][1+piececount][1+square] = posval;
            end
         end
      end
    end

    --  Calculate pawntab (indicates which squares contain pawns)

    for color = white, black, 1 do
        for rank = 0, 7, 1 do
            pawntab[1+color][1+rank] = 0;
        end
    end

    for square = 0x77, 0, -1 do
        if(bit.band(square, 0x88)==0) then

            o = Board[1+square];
            if(o.piece == pawn) then

                rank = bit.rshift(square, 4);
                if(o.color == black) then
					rank = 7 - rank;
                end
                q = pawntab[1+o.color];
                q[1+rank] = bit.bor( q[1+rank],
					filebittab[1+ bit.band(square,7)] );
            end
	end
    end

    for color = white, black, -1 do	--  initialize pawnbit

        o = pawnbit[1+color][1+0]; o.dob = 0; o.one = 0;
        for rank = 1, 6, 1 do

            t = pawntab[1+color][1+rank];
            o.dob = bit.bor( o.dob, bit.band(o.one , t) );
            o.one = bit.bor( o.one, t );
        end
    end

    --  Calculate pawnstructurevalue
    RootValue = pawnstrval(0, Player) - pawnstrval(0, Opponent);

    --  Calculate static value for pawn structure
    for color = white, black, 1 do

        oppcolor = 1-color;
        pawnfiletab = 0;
        leftsidetab = 0;
        rightsidetab = 0;
        behindoppass = 0;
        oppasstab = 0xff;
        for rank = 1, 6, 1 do

            --  Squares where opponents pawns are passed pawns
            k = bit.bor( leftsidetab, rightsidetab );
            w = bit.bor( pawnfiletab, k );
            oppasstab = bit.band( oppasstab, bit.bnot(w) );

            --  Squares behind the opponents passed pawns
            k = bit.band( oppasstab, pawntab[1+oppcolor][1+7 - rank] );
            behindoppass = bit.bor( behindoppass, k );

            --  squares which are covered by a pawn
            leftchaintab = leftsidetab;
            rightchaintab = rightsidetab;
            pawnfiletab = pawntab[1+color][1+rank]; --  squares w/ pawns

            --  squares w/ a pawn beside them
            k = bit.lshift(pawnfiletab,1);
            leftsidetab = bit.band( k, 0xff );
            k = bit.rshift(pawnfiletab,1);
            rightsidetab = bit.band( k, 0xff );
            sidetab = bit.bor( leftsidetab , rightsidetab );
            chaintab = bit.bor( leftchaintab , rightchaintab );

            --  squares covering a pawn
            t = pawntab[1+color][1+rank+1];
            k = bit.lshift(t,1);
            leftcovertab = bit.band( k, 0xff );
            k = bit.rshift(t,1);
            rightcovertab = bit.band( k, 0xff );
            sq = bit.lshift( rank, 4 );
            if(color == black) then
			   sq = bit.bxor( sq, 0x70 );
            end
            bt = 1;
            while (bt~=0) do

                strval = 0;
                if( bit.band( bt, sidetab )~=0 ) then
                    strval = SIDEPAWN;
                else
				  if( bit.band( bt, chaintab )~=0 ) then
				    strval = CHAINPAWN;
				  end
                end

                if( bit.band( bt, leftcovertab )~=0 ) then
                    strval = strval + COVERPAWN;
                end
                if( bit.band( bt, rightcovertab )~=0 ) then
                    strval = strval + COVERPAWN;
                end
                if( bit.band( bt, pawnfiletab )~=0 ) then
                    strval = strval + NOTMOVEPAWN;
                end
                q = PVTable[1+color][1+pawn];
                q[1+sq] = q[1+sq] + strval;
                if((materiallevel <= 0) or (oppcolor ~= ProgramColor)) then

                    if( bit.band( bt, oppasstab )~=0 ) then
                        q = PVTable[1+oppcolor][1+pawn];
                        q[1+sq] = q[1+sq] + passpawnrank[1+7 - rank];
                    end
                    if( bit.band( bt, behindoppass )~=0 ) then

                        t = bit.bxor(sq, 0x10);
                        for t3 = black, white, -1 do
                            q = PVTable[1+t3][1+rook];
                            q[1+sq] = q[1+sq] + ROOKBEHINDPASSPAWN;
                            if(rank == 6) then
                                q[1+t] = q[1+t] + ROOKBEHINDPASSPAWN;
                            end
                        end
                    end
                end
                sq = sq + 1;
                bt = bit.band( bit.lshift(bt,1), 0xff );
            end
        end
    end

    --  Calculate penalty for blocking center pawns with a bishop
    for sq = 3, 4, 1 do

        o = Board[1+sq + 0x10];
        if((o.piece == pawn) and (o.color == white)) then
            q = PVTable[1+white][1+bishop];
            w = sq+0x20;
            q[1+w] = q[1+w] - BISHOPBLOCKVALUE;
        end
        o = Board[1+sq + 0x60];
        if((o.piece == pawn) and (o.color == black)) then
            q = PVTable[1+black][1+bishop];
            w = sq+0x50;
            q[1+w] = q[1+w] - BISHOPBLOCKVALUE;
        end
    end

    --  Calculate RootValue
    for square = 0x77, 0, -1 do
        if(bit.band(square, 0x88)==0) then

            o = Board[1+square]; p = o.piece;
            if(p ~= empty) then
                if(o.color == Player) then
                    RootValue = RootValue +
                        PiecePosVal(p, Player, square);
                else
                    RootValue = RootValue -
                        PiecePosVal(p, Opponent, square);
                end
            end
	end
    end
end

--
--  Update pawnbit and calculates value when a pawn is removed from line
--

function decpawnstrval(color, line)

    local o = pawnbit[1+color][1+Depth];
    local t = bit.bnot( filebittab[1+line] );

    o.one = bit.bor( bit.band(o.one , t), o.dob );
    o.dob = bit.band( o.dob, t );

    return (pawnstrval(Depth, color) - pawnstrval(Depth - 1, color));
end

--
--  Update pawnbit and calculates value when a pawn moves
--  from old to nw1 file
--

function movepawnstrval(color, nw1, old)

    local o = pawnbit[1+color][1+Depth];
    local t = filebittab[1+nw1];
    local t2 = bit.bnot( filebittab[1+old] );

    o.dob = bit.bor( o.dob, bit.band(o.one, t) );
    o.one = bit.bor( bit.bor( bit.band( o.one, t2 ), o.dob ), t );
    o.dob = bit.band( o.dob, t2 );

    return (pawnstrval(Depth, color) - pawnstrval(Depth - 1, color));
end

--
--  Calculate STATIC evaluation of the move
--

function StatEvalu(move)

    local value = 0;
    if(move.spe~=0) then
        if(move.movpiece == king) then

            local Cast = CASTTYPE();
            GenCastSquare(move.nw1, Cast);
            value = PiecePosVal(rook, Player, Cast.castsquare) -
                    PiecePosVal(rook,Player, Cast.cornersquare);
            if(move.nw1 > move.old) then
                value = value + castvalue[1+shrt-1];
            else
                value = value + castvalue[1+lng-1];
            end

        else
        if(move.movpiece == pawn) then

            local epsquare = move.nw1 - PawnDir[1+Player];  --  E.p. capture
            value = PiecePosVal(pawn, Opponent, epsquare);

        else            --  Pawnpromotion
            value = PiecePosVal(move.movpiece, Player, move.old) -
                    PiecePosVal(pawn, Player, move.old) +
                    decpawnstrval(Player, bit.band(move.old,7) );
        end
	end
    end

    if(move.content ~= empty) then  --  normal moves

            value = value + PiecePosVal(move.content, Opponent, move.nw1);
            --  Penalty for exchanging pieces when behind in material
            if(math.abs(MainEvalu) >= 0x100) then
                if(move.content ~= pawn) then
                    if((ProgramColor == Opponent) == (MainEvalu >= 0)) then
                        value = value - EXCHANGEVALUE;
                    end
                end
            end
    end
	--  calculate pawnbit
    copyPwBt( pawnbit[1+black][1+Depth], pawnbit[1+black][1+Depth-1] );
    copyPwBt( pawnbit[1+white][1+Depth], pawnbit[1+white][1+Depth-1] );
    if((move.movpiece == pawn) and
	((move.content ~= empty) or (move.spe~=0))) then
            value = value + movepawnstrval(Player,
				bit.band(move.nw1,7), bit.band(move.old,7) );
    end
    if((move.content == pawn) or
	(move.spe~=0) and (move.movpiece == pawn)) then
            value = value - decpawnstrval(Opponent, bit.band( move.nw1,7) );
    end
        --  Calculate value of move
    return (value + PiecePosVal(move.movpiece, Player, move.nw1)-
                PiecePosVal(move.movpiece, Player, move.old));
end

-- === SEARCH with own MOVEGEN 2 ===

--
--  Global Variables for this module
--

Mo = {};	-- pointer to MovTab[1+mc] - current move
Mpre = {};	-- pointer to MovTab[1+mc-1] - previous move by opponent

Analysis = true;	-- to display
MateSrch = false;	-- set 1 to search mate only

MaxDepth = 0;	-- max.ply reached (=Depth-1)
LegalMoves = 0;
SkipSearch = false;

rank7 = {0x60, 0x10};

timer = {};

function InitTime()
 timer.started = os.clock();
 timer.elapsed = 0;
end
InitTime();

Nodes = 0;

killingmove = {{},{}};	-- [2][MAXPLY+1]
checktab = {};	--[MAXPLY+3], start from 1, not 0
--  Square of eventual pawn on 7th rank
passedpawn = {};	-- [MAXPLY+4], start from 2

alphawindow = 0;  --  alpha window value
rptevalu = 0;  --  MainEvalu at ply one

function INFTYPE()
 local i = {};
 i.principv = false;	--  Principal variation search
 i.value = 0;		--  Static incremental evaluation
 i.evaluation = 0;	--  Evaluation of position
 return i;
end
startinf = INFTYPE();     --  Inf at first ply

mane = 0; specialcap = 1; kill = 2; norml = 3;	--  move type

LOSEVALUE  = 0x7D00;
MATEVALUE  = 0x7C80;
DEPTHFACTOR  = 0x80;

-- a line of moves
function LINETYPE()
 local a= {};
 local i;
 for i=1, MAXPLY+2, 1 do
   a[i] = MOVETYPE();
 end
 return a;
end

-- slow "deepcopy"
function cloneMLine(a)
 local b = {};
 local i;
 for i=1, table.getn(a), 1 do
   b[i] = cloneMove(a[i]);
 end
 return b;
end

-- slow "deepcopy" of move arrays, t should be length of f
function copyMLine(t,f)
 local i;
 for i=1, table.getn(f), 1 do
  copyMove(t[i],f[i]);
 end
end


function MLINE()
 local m = {};
 m.a = LINETYPE();
 return m;
end	-- we need object to pass as parameter

MainLine = MLINE();
MainEvalu = 0;

function SEARCHTYPE()
 local s = {};
 s.line = MLINE();		--  best line at next ply
 s.capturesearch = false;	--  indicates capture search
 s.maxval = 0;			--  maximal evaluation returned in search
 s.nextply = 0;			--  Depth of search at next ply
 s.next = {};			--  information at Next ply
 s.zerowindow = false;		--  Zero-width alpha-beta-window
 s.movgentype = 0;
 return s;
end

function PARAMTYPE()
 local p = {};
 p.alpha = 0;
 p.beta = 0;
 p.ply = 0;
 p.inf = INFTYPE();
 p.bestline = {};
 p.S = SEARCHTYPE();
 return p;
end

-- holds previous move display
function DISPIF()
 local d = {};
 d.maxelp = 0;
 d.move = ZeroMove;
 return d;
end
dspmv = DISPIF();


function DisplayMove()

   if(Analysis and Depth==1) then

	local move = MainLine.a[1+1];
	timeused(); -- update elapsed


	if((move.movpiece~=empty) and
	  (( dspmv.maxelp<timer.elapsed ) or
	   not EqMove(dspmv.move,move))) then

		dspmv.move = cloneMove(move);
		dspmv.maxelp = timer.elapsed;

		print("" ..  MaxDepth .. " ply " ..
			timer.elapsed .. " sec. " .. Nodes .. " nodes " ..
			sq2str(move.old) .. sq2str(move.nw1));
		PrintBestMove();
	end
   end
end

function PrintBestMove()

   local s = "";
   local dep = 0;
   while(true) do
	 dep = dep + 1;
	 local move = MainLine.a[1+dep];

	 if(move.movpiece == empty) then
		break;
	 end
	 s = s .. sq2str(move.old) .. sq2str(move.nw1) .. " ";
   end

   print("ev:"  .. EvValStr() .. " " .. s);
end


-- evalvalue as string
function EvValStr()

 local e = (MainEvalu/256);
 if(Player == black) then
	e = -e;
 end
 local c = "";
 if(e>0) then
   c = "+";
 end
 if(e<0) then
   c = "-";
   e = -e;
 end

 return (c..string.format("%.2f",e));
end

--
--  Initialize killingmove, checktab and passedpawn
--

function clearkillmove()

    local dep,col,sq,i,o,v;

    for dep = 0, MAXPLY, 1 do
        for i = 0, 1, 1 do
            killingmove[1+i][1+dep] = ZeroMove;
        end
    end
    checktab[1+0] = false;
    passedpawn[1+0] = -1;  --  No check at first ply
    passedpawn[1+1] = -1;
    --  Place eventual pawns on 7th rank in passedpawn
    for col = white, black, 1 do
        v = rank7[1+col];
        for sq = v, (v + 7), 1 do

            o = Board[1+sq];
            if((o.piece == pawn) and (o.color == col)) then
                if(col == Player) then
                    passedpawn[1+0] = sq;
                else
                    passedpawn[1+1] = sq;
                end
            end
	end
    end
end

--
--  Update killingmove using bestmove
--

function updatekill(bestmove)

    if(bestmove.movpiece ~= empty) then

    --  Update killingmove unless the move is a capture of last
    --  piece moved
        if((Mpre.movpiece == empty) or (bestmove.nw1 ~= Mpre.nw1)) then
            if((killingmove[1+0][1+Depth].movpiece == empty)  or
                (EqMove(bestmove, killingmove[1+1][1+Depth]))) then

                killingmove[1+1][1+Depth] = cloneMove( killingmove[1+0][1+Depth] );
                killingmove[1+0][1+Depth] = cloneMove( bestmove );

            else
              if( not EqMove(bestmove, killingmove[1+0][1+Depth])) then
                killingmove[1+1][1+Depth] = cloneMove( bestmove );
              end
            end
        end
    end
end  --  Updatekill



--
--  Test if move has been generated before
--

function generatedbefore(P)	--P is PARAMTYPE

    if(P.S.movgentype ~= mane) then

        if( EqMove(Mo, P.bestline.a[1+Depth]) ) then
			return true;
        end

        if( not P.S.capturesearch) then
            if(P.S.movgentype ~= kill) then
                local i;
                for i = 0, 1, 1 do
                    if( EqMove( Mo, killingmove[1+i][1+Depth]) ) then
                        return true;
                    end
                end
            end
        end
    end
    return false;
end


--
--  Test cut-off.  Cutval cantains the maximal possible evaluation
--

function cut(cutval,P)

    local ct = false;
    if(cutval <= P.alpha) then
        ct = true;
        if(P.S.maxval < cutval) then
		   P.S.maxval = cutval;
        end
    end
    return ct;
end


--
--  Perform move, calculate evaluation, test cut-off, etc
--
function tkbkmv()
  unPerform();
  return true;
end

function update(P)

    Nodes = Nodes + 1;
    P.S.nextply = P.ply - 1;      --  Calculate next ply
    if(MateSrch) then --  MateSrch

        Perform( Mo, false );  --  Perform Move on the board
        --  Check if Move is legal
        if(Attacks(Opponent, PieceTab[1+Player][1+0].isquare)) then
			return tkbkmv(); --TAKEBACKMOVE
        end
        if(Depth==1) then
			LegalMoves = LegalMoves + 1;
        end
        checktab[1+Depth] = false;
        passedpawn[1+1+Depth] = -1;
        local d = P.S.next;
        d.value = 0; d.evaluation = 0;
        if(P.S.nextply <= 0) then
		--  Calculate chech and perform evt. cut-off

            if( P.S.nextply==0) then
                checktab[1+Depth] = Attacks(Player,
                    PieceTab[1+Opponent][1+0].isquare);
            end
            if( not checktab[1+Depth]) then
                if(cut(P.S.next.value, P)) then
					return tkbkmv(); --TAKEBACKMOVE
                end
            end
        end

        DisplayMove();
        return false;	--ACCEPTMOVE
    end

    --  Make special limited capturesearch at first iteration
    if(MaxDepth <= 1) then
        if(P.S.capturesearch and Depth >= 3) then

            if( not ((Mo.content < Mo.movpiece) or
				(P.S.movgentype == specialcap) or
				(Mo.old == MovTab[1+mc-2].nw1))) then

                DisplayMove();
                return true;	-- CUTMOVE
            end
        end
    end

    --  Calculate nxt static incremental evaluation
    P.S.next.value = -P.inf.value + StatEvalu(Mo);
    --  Calculate checktab (only checks with moved piece are calculated)
    --  Giving Check does not count as a ply
    checktab[1+Depth] = PieceAttacks(Mo.movpiece, Player, Mo.nw1, PieceTab[1+Opponent][1+0].isquare);
    if(checktab[1+Depth]) then
		P.S.nextply = P.ply;
    end
    --  Calculate passedpawn.  Moving a pawn to 7th rank does not
    --  count as a ply
    passedpawn[1+1+Depth] = passedpawn[1+1+(Depth-2)];
    if(Mo.movpiece == pawn) then
        if((Mo.nw1 < 0x18) or (Mo.nw1 >= 0x60)) then
            passedpawn[1+1+Depth] = Mo.nw1;
            P.S.nextply = P.ply;
        end
    end

        --  Perform selection at last ply and in capture search
    local selection = ((P.S.nextply <= 0) and
		(not checktab[1+Depth]) and (Depth > 1));
    if(selection) then   --  check evaluation
        if(cut(P.S.next.value, P)) then
			DisplayMove();
			return true;
        end	-- CUTMOVE
    end
    Perform( Mo, false );  --  perform move on the board
    --  check if move is legal
    if(Attacks(Opponent, PieceTab[1+Player][1+0].isquare)) then
		return tkbkmv(); --TAKEBACKMOVE
    end
    local p = passedpawn[1+1+Depth];
    if(p >= 0) then  --  check passedpawn

        local b = Board[1+p];
        if(b.piece ~= pawn or b.color ~= Player) then
            passedpawn[1+1+Depth] = -1;
        end
    end
    if(Depth==1) then
        LegalMoves = LegalMoves + 1;
        P.S.next.value = P.S.next.value + math.floor(math.random()*4);
    end
    P.S.next.evaluation = P.S.next.value;
--ACCEPTMOVE:
    DisplayMove();
    return false;
end


--
--  Calculate draw bonus/penalty, and set draw if the game is a draw
--

function drawgame(S)		-- S is SEARCHTYPE

    local o = S.next;
    if(Depth == 2) then

        local searchfifty = FiftyMoveCnt();
        local searchrepeat = Repetition(false);
        if(searchrepeat >= 3) then
            o.evaluation = 0;
            return true;
        end
        local drawcount = 0;
        if(searchfifty >= 96) then  --  48 moves without pawn moves or captures
            drawcount = 3;
        else
            if(searchrepeat >= 2) then  --  2nd repetition
                drawcount = 2;
            else
              if(searchfifty >= 20) then  --  10 moves without pawn moves or
                drawcount = 1;        		--  captures
              end
            end
        end


        local n = math.floor((rptevalu * drawcount)/4);
        o.value = o.value + n;
        o.evaluation = o.evaluation + n;	--int
    end
    if(Depth >= 4) then
        local searchrepeat = Repetition(true);
        if(searchrepeat >= 2) then       --  Immediate repetition counts as a draw
            o.evaluation = 0;
            return true;
        end
    end
    return false;
end


--
--  Update bestline and MainEvalu using line and maxval
--

function updatebestline(P)

    copyMLine( P.bestline.a, P.S.line.a );
    copyMove( P.bestline.a[1+Depth], Mo );


    if(Depth==1) then

        MainEvalu = P.S.maxval;
        if(MateSrch) then
			P.S.maxval = alphawindow;
        end
        DisplayMove();
    end
end


--
--  The inner loop of the search procedure.  MovTab[1+mc] contains the move.
--

function loopbody(P)

    if(generatedbefore(P)) then
		return false;
    end
    if(Depth < MAXPLY) then

        if(P.S.movgentype == mane) then
			copyMLine( P.S.line.a, P.bestline.a );
        end
        copyMove( P.S.line.a[1+Depth+1], ZeroMove );
    end
    --  principv indicates principal variation search
    --  Zerowindow indicates zero - width alpha - beta window
    P.S.next.principv = false;
    P.S.zerowindow = false;
    if(P.inf.principv) then
        if(P.S.movgentype == mane) then
            P.S.next.principv = (P.bestline.a[1+Depth+1].movpiece ~= empty);
        else
            P.S.zerowindow = (P.S.maxval >= P.alpha);
        end
    end


    repeat	-- loop....

    local lc = false;	-- try exit loop

--REPEATSEARCH:

    if(update(P)) then
		return false;
    end
    local f = true;
    if(MateSrch) then  --  stop evt. search
        if((P.S.nextply <= 0) and  not checktab[1+Depth]) then
          f = false;
        end
    end

    if(f and (drawgame(P.S) or Depth >= MAXPLY)) then
      f = false;
    end


    if(f) then

    --  Analyse nextply using a recursive call to search
    local oldplayer = Player;
    Player = Opponent;
    Opponent = oldplayer;
    Depth = Depth + 1;
    if(P.S.zerowindow) then
        P.S.next.evaluation = -search(-P.alpha - 1, -P.alpha, P.S.nextply,
                P.S.next, P.S.line );
    else
        P.S.next.evaluation = -search(-P.beta, -P.alpha, P.S.nextply,
                P.S.next, P.S.line );
    end
    Depth = Depth - 1;
    oldplayer = Opponent;
    Opponent = Player;
    Player = oldplayer;
    end -- f
--NOTSEARCH:
    unPerform();  --  take back move
    if(SkipSearch) then
        return true;
    end
    --if(Analysis) then
     if(MainEvalu > alphawindow) then
		SkipSearch = timeused();
     end

     if(MaxDepth <= 1) then
		SkipSearch = false;
     end
     --end

    P.S.maxval = math.max(P.S.maxval, P.S.next.evaluation);  --  Update Maxval
    if( EqMove(P.bestline.a[1+Depth], Mo )) then  --  Update evt. bestline
        updatebestline(P);
    end
    if(P.alpha < P.S.maxval) then      --  update alpha and test cutoff

        updatebestline(P);
        if(P.S.maxval >= P.beta) then
            return true;
        end
        --  Adjust maxval (tolerance search)
        if(P.ply >= 2  and P.inf.principv and ( not P.S.zerowindow)) then
            P.S.maxval = math.min(P.S.maxval + TOLERANCE, P.beta - 1);
        end
        P.alpha = P.S.maxval;
        if(P.S.zerowindow and (not SkipSearch)) then

            --  repeat search with full window
            P.S.zerowindow = false;
            lc = true; --goto REPEATSEARCH;
        end
    end


    until(not lc);

    return SkipSearch;
end


--
--  generate  pawn promotions
--

function pawnpromotiongen(P)

    Mo.spe = 1;
    local promote;
    for promote = queen, knight, 1 do
        Mo.movpiece = promote;
        if(loopbody(P)) then
          return true;
        end
    end
    Mo.spe = 0;
    return false;
end


--
-- Generate captures of the piece on Newsq
--

function capmovgen( newsq, P )

    local nxtsq,sq,i,p,q,m,b;
    Mo.content = Board[1+newsq].piece;
    Mo.spe = 0;
    Mo.nw1 = newsq;
    Mo.movpiece = pawn;  --  pawn captures
    nxtsq = Mo.nw1 - PawnDir[1+Player];

    for sq = nxtsq - 1, nxtsq + 1, 1 do
        if(sq ~= nxtsq) then
            if(bit.band(sq, 0x88)==0) then

                b = Board[1+sq];
                if(b.piece == pawn and b.color == Player) then

                    Mo.old = sq;
                    if(Mo.nw1 < 8 or Mo.nw1 >= 0x70) then

                        if(pawnpromotiongen(P)) then
                            return true;
                        end

                    else
                      if(loopbody(P)) then
                        return true;
                      end
                    end
                end
            end
        end
    end


    for i = OfficerNo[1+Player], 0, -1 do  --  other captures

        m = PieceTab[1+Player][1+i]; p = m.ipiece; q = m.isquare;

        if(p ~= empty and p ~= pawn) then
            if(PieceAttacks(p, Player, q, newsq)) then

                Mo.old = q;
                Mo.movpiece = p;
                if(loopbody(P)) then
                  return true;
                end
            end
        end
    end
    return false;
end


--
--  Generates non captures for the piece on oldsq
--

function noncapmovgen( oldsq, P )

    local first, last, dir, direction, newsq;
    Mo.spe = 0;
    Mo.old = oldsq;
    Mo.movpiece = Board[1+oldsq].piece;
    Mo.content = empty;

    --switch (Mo.movpiece)

	if(Mo.movpiece == king) then
            for dir = 7, 0, -1 do

                newsq = Mo.old + DirTab[1+dir];
                if(bit.band(newsq, 0x88)==0) then
                    if(Board[1+newsq].piece == empty) then

                        Mo.nw1 = newsq;
                        if(loopbody(P)) then
                             return true;
                        end
                    end
                end
            end
	else
	if(Mo.movpiece == knight) then
            for dir = 7, 0, -1 do

                newsq = Mo.old + KnightDir[1+dir];
                if(bit.band(newsq, 0x88)==0) then
                    if(Board[1+newsq].piece == empty) then

                        Mo.nw1 = newsq;
                        if(loopbody(P)) then
                             return true;
                        end
                    end
                end
            end
	else
	if(Mo.movpiece >= queen and Mo.movpiece <=bishop) then
		-- queen,rook,bishop

            first = 7;
            last = 0;
            if(Mo.movpiece == rook) then
			  first = 3;
            else
              if(Mo.movpiece == bishop) then
			    last = 4;
              end
            end

            for dir = first, last, -1 do

                direction = DirTab[1+dir];
                newsq = Mo.old + direction;
                while ( bit.band(newsq, 0x88)==0) do

                    if(Board[1+newsq].piece ~= empty) then

						break;	-- goto TEN
                    end
                    Mo.nw1 = newsq;
                    if(loopbody(P)) then
						return true;
                    end
                    newsq = Mo.nw1 + direction;
                end
--TEN:
                --continue;
            end
	else
	if(Mo.movpiece == pawn) then
            --  One square forward
            Mo.nw1 = Mo.old + PawnDir[1+Player];
            if(Board[1+Mo.nw1].piece == empty) then
                if(Mo.nw1 < 8 or Mo.nw1 >= 0x70) then
                    if(pawnpromotiongen(P)) then
					   return true;
                    end
                else

                    if(loopbody(P)) then
                        return true;
                    end
                    if(Mo.old < 0x18 or Mo.old >= 0x60) then

                        --  two squares forward
                        Mo.nw1 = Mo.nw1 + (Mo.nw1 - Mo.old);
                        if(Board[1+Mo.nw1].piece == empty) then
                            if(loopbody(P)) then
                                return true;
                            end
                        end
                    end
                end
            end
	end
	end
	end

    end --  switch
    return false;
end


--
--  castling moves
--

function castlingmovgen(P)

    Mo.spe = 1;
    Mo.movpiece = king;
    Mo.content = empty;
    local castdir;
    for castdir = (lng-1), shrt-1, 1 do

        local m = CastMove[1+Player][1+castdir];
        Mo.nw1 = m.castnew;
        Mo.old = m.castold;
        if(KillMovGen(Mo)) then
            if(loopbody(P)) then
                return true;
            end
        end
    end
    return false;
end


--
--  e.p. captures
--

function epcapmovgen(P)

    if(Mpre.movpiece == pawn) then
        if(math.abs(Mpre.nw1 - Mpre.old) >= 0x20) then

            Mo.spe = 1;
            Mo.movpiece = pawn;
            Mo.content = empty;
            Mo.nw1 = (Mpre.nw1 + Mpre.old) / 2;
            local sq;
            for sq = Mpre.nw1 - 1, Mpre.nw1 + 1, 1 do
                if(sq ~= Mpre.nw1) then
                    if(bit.band(sq, 0x88)==0) then

                        Mo.old = sq;
                        if(KillMovGen(Mo)) then
                            if(loopbody(P)) then
                                return true;
                            end
                        end
                    end
                end
            end
        end
    end
    return false;
end


--
--  Generate the next move to be analysed.
--   Controls the order of the movegeneration.
--      The moves are generated in the order:
--      Main variation
--      Captures of last moved piece
--      Killing moves
--      Other captures
--      Pawnpromotions
--      Castling
--      Normal moves
--      E.p. captures
--

function searchmovgen(P)

    local index, p;
    local w = P.bestline.a[1+Depth];

    copyMove(Mo,ZeroMove);

    --  generate move from the main variation
    if(w.movpiece ~= empty) then
        copyMove( Mo, w );
        P.S.movgentype = mane;
        if(loopbody(P)) then
		  return;
        end
    end
    if(Mpre.movpiece ~= empty) then
        if(Mpre.movpiece ~= king) then
            P.S.movgentype = specialcap;
            if(capmovgen(Mpre.nw1, P)) then
			  return;
            end
        end
    end
    P.S.movgentype = kill;
    if( not P.S.capturesearch) then
        local killno;
        for killno = 0, 1, 1 do

            copyMove( Mo, killingmove[1+killno][1+Depth] );
            if(Mpre.movpiece ~= empty) then
                if(KillMovGen(Mo)) then
                    if(loopbody(P)) then
					  return;
                    end
                end
            end
        end
    end
    P.S.movgentype = norml;
    for index = 1, PawnNo[1+Opponent], 1 do

        w = PieceTab[1+Opponent][1+index];
        if(w.ipiece ~= empty) then
            if(Mpre.movpiece == empty or w.isquare ~= Mpre.nw1) then
                if(capmovgen(w.isquare, P)) then
                    return;
                end
            end
        end
    end
    if(P.S.capturesearch) then

        p = passedpawn[1+1+(Depth-2)];
        if(p >= 0) then

	    w = Board[1+p];
            if(w.piece == pawn and w.color == Player) then
                if(noncapmovgen(p, P)) then
					return;
                end
            end
        end
    end
    if( not P.S.capturesearch) then                --  non-captures

        if(castlingmovgen(P)) then
            return;      --  castling
        end
        for index = PawnNo[1+Player], 0, -1 do

            w = PieceTab[1+Player][1+index];
            if(w.ipiece ~= empty) then
                if(noncapmovgen(w.isquare, P)) then
					return;
                end
            end
        end
    end
    if(epcapmovgen(P)) then
        return;  --  e.p. captures
    end
end


--
--  Perform the search
--  On entry :
--   Player is next to move
--    MovTab[1+Depth-1] contains last move
--   alpha, beta contains the alpha - beta window
--    ply contains the Depth of the search
--    inf contains various information
--
--  On exit :
--    Bestline contains the principal variation
--   search contains the evaluation for Player
--

function search( alpha, beta, ply, inf, bestline)

    local S = SEARCHTYPE();
    local P = PARAMTYPE();
    --  Perform capturesearch if ply <= 0 and  not check
    S.capturesearch = ((ply <= 0) and  (not checktab[1+Depth-1]));
    if(S.capturesearch) then  --  initialize maxval

        S.maxval = -inf.evaluation;
        if(alpha < S.maxval) then

            alpha = S.maxval;
            if(S.maxval >= beta) then
			  return S.maxval;	--goto STOP
            end
        end

    else

        S.maxval = -(LOSEVALUE - (Depth-1)*DEPTHFACTOR);
    end
    P.alpha = alpha;
    P.beta = beta;
    P.ply = ply;
    P.inf = inf;
    P.bestline = bestline;
    P.S = S;
    searchmovgen(P);   --  The search loop
    if(SkipSearch) then
		return S.maxval;	-- goto STOP
    end
    if(S.maxval == -(LOSEVALUE - (Depth-1) * DEPTHFACTOR)) then
        --  Test stalemate

        if( not Attacks(Opponent, PieceTab[1+Player][1+0].isquare)) then

            S.maxval = 0;
            return S.maxval;	--goto STOP
        end
    end
    updatekill(P.bestline.a[1+Depth]);
--STOP:
    return S.maxval;
end


--
--  Begin the search
--

function callsearch( alpha, beta )

    startinf.principv = (MainLine.a[1+1].movpiece ~= empty);
    LegalMoves = 0;
    local maxval = search(alpha, beta, MaxDepth, startinf, MainLine );
    if(LegalMoves==0) then
        MainEvalu = maxval;
    end
    return maxval;
end


--
-- Checks whether the search time is used
--

function timeused()

 if(Analysis) then

    timer.elapsed = math.floor( os.clock() - timer.started );
    return (timer.elapsed >= MAXSECS);
 end
 return false;
end


--
--  setup search (Player = color to play, Opponent = opposite)
--

function FindMove()

    ProgramColor = Player;
    InitTime();
    Nodes = 0;
    SkipSearch = false;
    clearkillmove();
    pawnbit = { PwBtList(), PwBtList() };
    CalcPVTable();
    startinf.value = -RootValue;
    startinf.evaluation = -RootValue;
    MaxDepth = 0;
    MainLine = MLINE();
    --MainLine.a = LINETYPE();
    MainEvalu = RootValue;
    alphawindow = MAXINT;

    repeat

        --  update various variables
        if(MaxDepth <= 1) then
			rptevalu = MainEvalu;
        end
        alphawindow = math.min(alphawindow, MainEvalu - 0x80);
        if(MateSrch) then
            alphawindow = 0x6000;
            if(MaxDepth > 0) then
			  MaxDepth = MaxDepth + 1;
            end
        end
        MaxDepth = MaxDepth + 1;
        local maxval = callsearch(alphawindow, 0x7f00);  --  perform the search
        if(maxval <= alphawindow and  (not SkipSearch) and
				(not MateSrch) and (LegalMoves > 0)) then

            --  Repeat the search if the value falls below the
            --     alpha-window
            MainEvalu = alphawindow;
            maxval = callsearch(-0x7F00, alphawindow - TOLERANCE * 2);
            LegalMoves = 2;
        end

    until( SkipSearch or timeused() or (MaxDepth >= MAXPLY)  or
            (LegalMoves <= 1)  or
            (math.abs(MainEvalu) >= MATEVALUE - 24 * DEPTHFACTOR));

   DisplayMove();
   PrintBestMove();
   return retMvStr();
end

function retMvStr()

   local ret = "";
   local move = MainLine.a[1+1];
   local p = move.movpiece;
   if(p~=empty) then
     ret = sq2str(move.old) .. sq2str(move.nw1);
     if( (move.spe~=0) and (p ~=pawn and p ~=king)) then
		ret = ret .. string.lower( PiecList[1+p] );
     end
   end
   return ret;
end

-- === STARTING ===


-- initiate engine
function initEngine()
	CalcAttackTab();
	ResetGame();
end

initEngine();

-- === Opening book ===


-- file OPENING.LIB as array of bytes

Openings = {};

function ReadBook()
  local lib_file = io.open("Owlbook.dat", "rb");
  if(lib_file~=nil) then

    local i,b;
    local f = true;	-- to append 0s
    print("preparing opening book");
    for i=1, 32000, 1 do
      if(f) then
         b = lib_file:read(1);
         if( not b ) then
           f = false; b = 0;
         end
      end
      Openings[i] = iif(f, string.byte(b,1), 0);
    end
    lib_file:close();

  end
end

ReadBook();		-- prepare array right now

-- Globals
LibNo = 0;		-- [0...32000]
OpCount = 0;		-- current move in list
LibMc = 0;
LibMTab = {};
UseLib = 200;
LibFound = false;

UNPLAYMARK = 0x3f;

--
--  Sets libno to the previous move in the block
--

function PreviousLibNo()

  local n = 0;
  repeat
        LibNo = LibNo - 1;
        local o = Openings[1+LibNo];
        if(o>= 128) then
		  n = n + 1;
        end
        if( bit.band(o,64)~=0 ) then
		  n = n - 1;
        end
  until (n==0);
end

--
--  Set libno to the first move in the block
--

function FirstLibNo()

    while (bit.band(Openings[1+LibNo-1], 64)==0) do
        PreviousLibNo();
    end
end

--
--  set libno to the next move in the block.  Unplayable
--  moves are skipped if skip is set
--

function NextLibNo(skip)

    if(Openings[1+LibNo] >= 128) then
		FirstLibNo();
    else

        local n = 0;
        repeat
            local o = Openings[1+LibNo];

            if( bit.band(o,64)~=0 ) then
			  n = n + 1;
            end
            if(o>= 128) then
			  n = n - 1;
            end

            LibNo = LibNo + 1;
        until(n==0);
        if(skip and (Openings[1+LibNo] == UNPLAYMARK)) then
            FirstLibNo();
        end
    end
end

--
-- find the node corresponding to the correct block
--

function FindNode()

    local o;
    LibNo = LibNo + 1;
    if(mc >= LibMc) then
        LibFound = true;
        return;
    end
    OpCount = -1;
    InitMovGen();
    local i;
    for i=1, BufCount, 1 do

        OpCount = OpCount + 1;
        MovGen();
        if(EqMove(Next, LibMTab[1+mc])) then
			break;
        end
    end

    if(Next.movpiece ~= empty) then

        while(true) do
		  o = Openings[1+LibNo];
		  if(( bit.band(o, 63) == OpCount) or (o >= 128)) then
		    break;
		  end
		  NextLibNo( false );
        end


        if(bit.band(o, 127) == (64+OpCount)) then

            DoMove( Next );
            FindNode();
            UndoMove();

        end
    end
end



function CalcLibNo()

    LibNo = 0;
    if(mc <= UseLib) then

        LibMTab = cloneMLine(MovTab);
        LibMc = mc;
        ResetGame();
        LibFound = false;
        FindNode();
        while(mc < LibMc) do

            DoMove( LibMTab[1+mc] );
        end
        if( not LibFound) then
            UseLib = mc-1;
            LibNo = 0;
        end
    end
end

--
--  find an opening move from the library,
--  return move string or "", also sets LibFound
--

function FindOpeningMove()

    Nodes = 0;

    if(table.getn(Openings)==0) then
	  return "";
    end

    CalcLibNo();

    if(LibNo==0) then
	  return "";
    end

    local weight = {7, 10, 12, 13, 14, 15, 16};	-- [7]
    local cnt = 0;


    local r = math.floor(os.time()*math.random()*16) % 16;

	--  calculate weighted random number in 0..16
    local p = 0;
    while (r >= weight[1+p]) do
		p = p + 1;
    end
    local countp;
    for countp = 1, p, 1 do	-- find corresponding node
        NextLibNo( true );
    end
    OpCount = bit.band( Openings[1+LibNo], 63 );  --  generate the move

    InitMovGen();
    local i;
    for i=1, BufCount, 1 do
		if(cnt>OpCount) then
		  break
		end
        MovGen();
        cnt = cnt + 1;
    end

                          -- store the move in mainline
    MainLine = MLINE();
    MainLine.a[1+1] = cloneMove(Next);
    MainEvalu = 0;
    PrintBestMove();
    return retMvStr();
end


--
-- AI vs AI game for testing...
--
function autogame()

  local PGN = {};
  local GameOver = false;
  local checkmate = false;
  local check = false;
  local draw = false;
  local resigned = false;

  ResetGame();

  while(not GameOver) do

		-- style g7g8q
    local foundmove = FindOpeningMove();	-- openings or...

    if(not LibFound) then
	  foundmove = FindMove();	-- let the engine search
    end
    print("Eval = " .. EvValStr() .. " , nodes = " .. Nodes);


    if(string.len(foundmove)==0) then
      break;
    end

		-- style g7-g8=Q
    local notated = DoMoveByStr(foundmove);
    printboard();

    local s = Comment();
	if(LibFound) then
	  s = "(book) " .. s;
	end
	if(string.len(s)>0) then
	  print(s);
	end

    GameOver =(string.find(s,"Mate!")~=nil);	-- also stalemate
    checkmate = (string.find(s,"CheckMate")~=nil);
    check = (string.find(s,"Check!")~=nil);
    draw = (string.find(s,"Draw,")~=nil);
    resigned = (string.find(s,"resigns")~=nil);


    notated = notated .. iif(checkmate, "#" , iif(check, "+", ""));
    PGN[mc-1] = notated;
    print (notated);

	print("Memory used = " .. string.format("%.1f Mb", collectgarbage("count")/1024));

	-- 50 moves, 3x pos.
	if(draw) then
	  GameOver = true;
	end

	-- AI tries resign, ignore it, wanna see checkmate.
	if(resigned) then
	--  GameOver = true;
	end


    local pgn = "";
    local i;
    for i=1,mc-1,1 do
		pgn = pgn .. iif( i%2==1, ((i+1)/2) .. ".", "" ) ..
		PGN[i] .. " ";
    end

    if(GameOver) then
      pgn = pgn .. "{" .. s .. "}";
    end

    print(pgn);

  end

  if(checkmate or resigned) then
    print( iif(Opponent==white, "1-0","0-1") );
  else
    print( "1/2-1/2");
  end


end


-----------------------------
-- main()
-----------------------------


 --print( FindOpeningMove() );
 --DoMoveByStr("f2f3");
 --DoMoveByStr("e7e5");
 --DoMoveByStr("g2g4");
 --printboard();
 --print( GenMovesStr() );
 --print( FindMove() );
 --DoMoveByStr("d8h4");
 --print( Comment() );
 --printboard();
 --UndoMove();
 --printboard();



-- a small demo

print("Autogame!");
autogame();
print("Ok");

