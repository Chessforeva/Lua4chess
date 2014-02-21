--
-- This is GarboChess engine by Gary Linscott (The author)
-- http://forwardcoding.com
--
-------------------------------------------------------------------
--
-- ported to Lua from javascript by Chessforeva
-- Just because this is absolutely brilliant code for
-- interpreted chess - the optimal AI for videogames :)
-- Very needed for scripting. Just could not find better.
--

require "bit"

g_timeout = 30;		-- can set maximum seconds for analysing
g_maxfinCnt = 100000;	-- can set limit of moves to analyse

g_startTime = 0;
g_finCnt = 0;

g_foundmove = 0;

--
-- Board code
--

-- This somewhat funky scheme means that a piece is indexed by it's lower 4 bits when accessing in arrays.  The fifth bit (black bit)
-- is used to allow quick edge testing on the board.

colorBlack = 0x10;
colorWhite = 0x08;

pieceEmpty = 0x00;
piecePawn = 0x01;
pieceKnight = 0x02;
pieceBishop = 0x03;
pieceRook = 0x04;
pieceQueen = 0x05;
pieceKing = 0x06;

g_vectorDelta = {};		-- new Array(256);

g_bishopDeltas = {-15, -17, 15, 17};
g_knightDeltas = {31, 33, 14, -14, -31, -33, 18, -18};
g_rookDeltas = {-1, 1, -16, 16};
g_queenDeltas = {-1, 1, -15, 15, -17, 17, -16, 16};

g_seeValues = {0, 1, 3, 3, 5, 9, 900, 0, 0, 1, 3, 3, 5, 9, 900, 0};

g_castleRightsMask = {
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 7,15,15,15, 3,15,15,11, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,15,15,15,15,15,15,15,15, 0, 0, 0, 0,
0, 0, 0, 0,13,15,15,15,12,15,15,14, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

moveflagEPC = bit.lshift(0x2, 16);
moveflagCastleKing = bit.lshift(0x4, 16);
moveflagCastleQueen = bit.lshift(0x8, 16);
moveflagPromotion = bit.lshift(0x10, 16);
moveflagPromoteKnight = bit.lshift(0x20, 16);
moveflagPromoteQueen = bit.lshift(0x40, 16);
moveflagPromoteBishop = bit.lshift(0x80, 16);

-- Position variables

g_board = {}		-- new Array(256); -- Sentinel 0x80, pieces are in low 4 bits, 0x8 for color, 0x7 bits for piece type
g_toMove = 0;		-- side to move, 0 or 8, 0 = black, 8 = white
g_castleRights = 0;	-- bitmask representing castling rights, 1 = wk, 2 = wq, 4 = bk, 8 = bq
g_enPassentSquare = 0;
g_baseEval = 0;
g_hashKeyLow = 0;
g_hashKeyHigh = 0;
g_inCheck = false;

-- Utility variables
g_moveCount = 0;
g_moveUndoStack = {};		-- new Array();

g_move50 = 0;
g_repMoveStack = {};		-- new Array();

g_hashSize = bit.lshift(1, 22);

g_hashMask = g_hashSize - 1;
g_hashTable = {};

g_killers = 0;
historyTable = {}		-- new Array(32);

g_zobristLow = {};
g_zobristHigh = {};
g_zobristBlackLow = 0;
g_zobristBlackHigh = 0;

-- Evaulation variables
g_mobUnit = {};

hashflagAlpha = 1;
hashflagBeta = 2;
hashflagExact = 3;

--
-- for searching code
--

g_nodeCount = 0;
g_qNodeCount= 0;
g_searchValid = true;
g_globalPly = 0;

minEval = -2000000;
maxEval = 2000000;

minMateBuffer = minEval + 2000;
maxMateBuffer = maxEval - 2000;

materialTable = {0, 800, 3350, 3450, 5000, 9750, 600000};

pawnAdj =
{
  0, 0, 0, 0, 0, 0, 0, 0,
  -25, 105, 135, 270, 270, 135, 105, -25,
  -80, 0, 30, 176, 176, 30, 0, -80,
  -85, -5, 25, 175, 175, 25, -5, -85,
  -90, -10, 20, 125, 125, 20, -10, -90,
  -95, -15, 15, 75, 75, 15, -15, -95,
  -100, -20, 10, 70, 70, 10, -20, -100,
  0, 0, 0, 0, 0, 0, 0, 0
};

knightAdj =
    {-200, -100, -50, -50, -50, -50, -100, -200,
      -100, 0, 0, 0, 0, 0, 0, -100,
      -50, 0, 60, 60, 60, 60, 0, -50,
      -50, 0, 30, 60, 60, 30, 0, -50,
      -50, 0, 30, 60, 60, 30, 0, -50,
      -50, 0, 30, 30, 30, 30, 0, -50,
      -100, 0, 0, 0, 0, 0, 0, -100,
      -200, -50, -25, -25, -25, -25, -50, -200
     };

bishopAdj =
    { -50,-50,-25,-10,-10,-25,-50,-50,
      -50,-25,-10,  0,  0,-10,-25,-50,
      -25,-10,  0, 25, 25,  0,-10,-25,
      -10,  0, 25, 40, 40, 25,  0,-10,
      -10,  0, 25, 40, 40, 25,  0,-10,
      -25,-10,  0, 25, 25,  0,-10,-25,
      -50,-25,-10,  0,  0,-10,-25,-50,
      -50,-50,-25,-10,-10,-25,-50,-50
     };

rookAdj =
    { -60, -30, -10, 20, 20, -10, -30, -60,
       40,  70,  90,120,120,  90,  70,  40,
      -60, -30, -10, 20, 20, -10, -30, -60,
      -60, -30, -10, 20, 20, -10, -30, -60,
      -60, -30, -10, 20, 20, -10, -30, -60,
      -60, -30, -10, 20, 20, -10, -30, -60,
      -60, -30, -10, 20, 20, -10, -30, -60,
      -60, -30, -10, 20, 20, -10, -30, -60
     };

kingAdj =
    {  50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
       50, 150, -25, -125, -125, -25, 150, 50,
      150, 250, 75, -25, -25, 75, 250, 150
     };

emptyAdj =
    { 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
     };

pieceSquareAdj = {};		-- new Array(8);

-- Returns the square flipped
flipTable = {};			-- new Array(256);

g_pieceIndex = {};		-- new Array(256);
g_pieceList = {};		-- new Array(2 * 8 * 16);
g_pieceCount = {};		-- new Array(2 * 8);

PieceCharList = {" ", "p", "n", "b", "r", "q", "k", " "}

--
function FormatSquare(square)
    return string.char( string.byte("a",1) + bit.band(square, 0xF) - 4) ..
	 string.format("%d", (9 - bit.rshift(square, 4)) + 1);
end
--
--
function deFormatSquare(at)

local h = string.byte(at,1) - string.byte("a",1) + 4;
local v = 9 - (string.byte(at,2) - string.byte("0",1) -1);

return bit.bor( h, bit.lshift( v, 4 ) );

end
--
--
function iif(ask, ontrue, onfalse)
    if( ask ) then
	return ontrue;
    end
    return onfalse;
end


function GetFen()

  local result = "";
  local row = 0;
  local empty = 0;
  local col = 0
  local piece = 0;

  while(row < 8) do
	if (row ~= 0) then
            result = result .. '/';
	end
        empty = 0;
	col = 0;
        while(col < 8) do
            piece = g_board[1+bit.lshift((row + 2),4) + col + 4];
            if (piece == 0) then
                empty = empty + 1;

            else
                if (empty ~= 0) then
                    result = result .. string.format("%d", empty);
		end
                empty = 0;
                pieceChar = PieceCharList[1+bit.band(piece, 0x7)];
		if( bit.band(piece, colorWhite) ~= 0) then
			result=result .. string.upper( pieceChar )
		else
			result=result .. pieceChar
		end
            end

	    col=col+1
	end
        if (empty ~= 0) then
            result = result .. string.format("%d", empty);
        end
	row = row + 1
  end


  result = result .. iif(colorWhite>0," w","b");
  result = result .. " ";
  if (g_castleRights == 0) then
	result = result .. "-";
  else
	if (bit.band(g_castleRights, 1) ~= 0) then
            result = result .. "K";
	end
        if (bit.band(g_castleRights, 2) ~= 0) then
            result = result .. "Q";
	end
        if (bit.band(g_castleRights, 4) ~= 0) then
            result = result .. "k";
	end
        if (bit.band(g_castleRights, 8) ~= 0) then
            result = result .. "q";
	end
  end

  result = result .. " ";

  if (g_enPassentSquare < 1) then
	result = result .. '-';
  else
        result = result .. FormatSquare(g_enPassentSquare);
  end

  return result;

end
--

--
function InitializeEval()

  local i = 0;
  local friend = 0;
  local enemy = 0;

  g_mobUnit = {}		-- new Array(2);

  for i=0, 1, 1 do
        g_mobUnit[1+i] = {}	-- new Array();
        enemy = iif( i == 0, 0x10, 8 );
        friend = iif( i == 0, 8, 0x10 );
        g_mobUnit[1+i][1] = 1;
        g_mobUnit[1+i][1+0x80] = 0;
        g_mobUnit[1+i][1+bit.bor(enemy, piecePawn)] = 1;
        g_mobUnit[1+i][1+bit.bor(enemy, pieceBishop)] = 1;
        g_mobUnit[1+i][1+bit.bor(enemy, pieceKnight)] = 1;
        g_mobUnit[1+i][1+bit.bor(enemy, pieceRook)] = 1;
        g_mobUnit[1+i][1+bit.bor(enemy, pieceQueen)] = 1;
        g_mobUnit[1+i][1+bit.bor(enemy, pieceKing)] = 1;
        g_mobUnit[1+i][1+bit.bor(friend, piecePawn)] = 0;
        g_mobUnit[1+i][1+bit.bor(friend, pieceBishop)] = 0;
        g_mobUnit[1+i][1+bit.bor(friend, pieceKnight)] = 0;
        g_mobUnit[1+i][1+bit.bor(friend, pieceRook)] = 0;
        g_mobUnit[1+i][1+bit.bor(friend, pieceQueen)] = 0;
        g_mobUnit[1+i][1+bit.bor(friend, pieceKing)] = 0;

  end

end
--

--
function HashEntry(lock, value, flags, hashDepth, bestMove, globalPly)
    local hs = {}
    hs.lock = lock;
    hs.value = value;
    hs.flags = flags;
    hs.hashDepth = hashDepth;
    hs.bestMove = bestMove;
    return hs;
end
--

--
function StoreHash(value, flags, ply, move, depth)
	if (value >= maxMateBuffer) then
		value = value + depth;
	else
		if (value <= minMateBuffer) then
			value = value - depth;
		end
	end
	g_hashTable[1+bit.band(g_hashKeyLow, g_hashMask)] =
		 HashEntry(g_hashKeyHigh, value, flags, ply, move);
end

--

--
function SetHash()

  local result = {};
  local i = 0;
  local piece = 0;

  result.hashKeyLow = 0;
  result.hashKeyHigh = 0;

  for i=0, 255, 1 do
	piece = g_board[1+i];
        if (bit.band(piece, 0x18)>0) then
		result.hashKeyLow = bit.bxor( result.hashKeyLow, g_zobristLow[1+i][1+bit.band(piece, 0xF)] );
		result.hashKeyHigh = bit.bxor( result.hashKeyHigh, g_zobristHigh[1+i][1+bit.band(piece, 0xF)] );
        end
  end

  if (g_toMove==0) then
        result.hashKeyLow = bit.bxor( result.hashKeyLow,  g_zobristBlackLow );
        result.hashKeyHigh = bit.bxor( result.hashKeyHigh,  g_zobristBlackHigh );
  end

  return result;
end
--
--
function MakeTable(table)
    local result = {}			-- new Array(256);
    local i = 0;
    local row = 0;
    local col = 0;
    for i=0, 255, 1 do
        result[1+i] = 0;
    end
    for row=0, 7, 1 do
        for col=0, 7, 1 do
            result[1+MakeSquare(row, col)] = table[1+((row * 8) + col)];
	end
    end
    return result;
end
--

--
function MakeSquare(row, column)
    return bit.bor( bit.lshift((row + 2), 4) , (column + 4) );
end
--
--
function InitializeFromFen(fen)

 local chunks = {}
 local i = 0;
 local j = 0;
 local row = 0;
 local col = 0;
 local pieces = 0;
 local c = " ";
 local isBlack = false;
 local piece = 0;
 local fen2 = fen;
 local s1 = 0;

 while( string.len(fen2)>0) do
 	s1 = string.find( fen2, " " );
	if( s1 == nil ) then
		table.insert( chunks, fen2 );
		fen2 = "";
	else
		table.insert( chunks, string.sub( fen2, 1, s1-1) );
		fen2 = string.sub( fen2, s1+1 );
	end
 end


 for i=0, 255, 1 do

  g_board[1+i] = 0x80;

 end

 row = 0;
 col = 0;

 pieces = chunks[1];

 for i=0, string.len(pieces)-1, 1 do

        c = string.sub(pieces, i+1, i+1 );

        if (c == '/') then
            row = row + 1;
            col = 0;
        else
            if ( c >= '0' and c <= '9' ) then
		for j=0, tonumber(c)-1, 1 do
                    g_board[1+((row + 2) * 0x10) + (col + 4)] = 0;
                    col = col + 1;
                end

            else
                isBlack = (c >= 'a' and c <= 'z');
                piece = iif(isBlack, colorBlack, colorWhite);

                if (not isBlack) then
                    c = string.sub( string.lower(pieces), i+1, i+1 );
		end
                if(c=='p') then
			piece = bit.bor(piece, piecePawn);
                end
                if(c=='b') then
                        piece = bit.bor(piece, pieceBishop);
                end
                if(c=='n') then
                        piece = bit.bor(piece, pieceKnight);
                end
                if(c=='r') then
                        piece = bit.bor(piece, pieceRook);
                end
                if(c=='q') then
                        piece = bit.bor(piece, pieceQueen);
                end
                if(c=='k') then
                        piece = bit.bor(piece, pieceKing);
                end

                g_board[1+((row + 2) * 0x10) + (col + 4)] = piece;
                col = col + 1;

	    end

	end

 end

 InitializePieceList();

 g_toMove = iif( chunks[1+1] == 'w' , colorWhite , 0 );

    g_castleRights = 0;
    if (string.find ( chunks[1+2], 'K') ~= nil ) then
        g_castleRights = bit.bor(g_castleRights, 1 );
    end
    if (string.find ( chunks[1+2], 'Q') ~= nil ) then
        g_castleRights = bit.bor(g_castleRights, 2 );
    end
    if (string.find ( chunks[1+2], 'k') ~= nil ) then
        g_castleRights = bit.bor(g_castleRights, 4 );
    end
    if (string.find ( chunks[1+2], 'q') ~= nil ) then
        g_castleRights = bit.bor(g_castleRights, 8 );
    end
    g_enPassentSquare = -1;
    if (string.find ( chunks[1+3], '-') == nil ) then
        g_enPassentSquare = deFormatSquare( chunks[1+3] )
    end


    local hashResult = SetHash();
    g_hashKeyLow = hashResult.hashKeyLow;
    g_hashKeyHigh = hashResult.hashKeyHigh;

    g_baseEval = 0;

    for i=0, 255, 1 do
        if (bit.band(g_board[1+i], colorWhite)>0) then
		g_baseEval = g_baseEval + pieceSquareAdj[1+bit.band( g_board[1+i] , 0x7)][1+i];
		g_baseEval = g_baseEval + materialTable[1+bit.band(g_board[1+i] , 0x7)];
        else
	 if (bit.band(g_board[1+i], colorBlack)>0) then
		g_baseEval = g_baseEval - pieceSquareAdj[1+bit.band(g_board[1+i], 0x7)][1+flipTable[1+i]];
		g_baseEval = g_baseEval - materialTable[1+bit.band(g_board[1+i], 0x7)];
	 end
        end
    end
    if (g_toMove==0) then
	g_baseEval = -g_baseEval;
    end

    g_move50 = 0;

    g_inCheck = IsSquareAttackable(g_pieceList[1+ bit.lshift( bit.bor(g_toMove, pieceKing) , 4)], 8 - g_toMove);

end

--

--
function IsSquareAttackableFrom(target, from)
    local index = from - target + 128;
    local piece = g_board[1+from];
    local inc = 0;

    if ( bit.band( g_vectorDelta[1+index].pieceMask[1+ bit.band( bit.rshift(piece, 3) , 1)] ,
		 bit.lshift(1 , bit.band(piece , 0x7)) )>0 ) then

	-- Yes, this square is pseudo-attackable.  Now, check for real attack
	inc = g_vectorDelta[1+index].delta;
        while(true) do
	  from = from + inc;
	  if (from == target) then
		return true;
	  end
	  if (g_board[1+from] ~= 0) then
		break;
	  end
	end
    end

    return false;
end
--

--
function IsSquareAttackable(target, color)
	-- Attackable by pawns?
   local inc = iif( color>0 , -16 , 16 );
   local pawn = bit.bor( iif(color>0 , colorWhite , colorBlack) , 1 );
   local index = 0;
   local square = 0;
   local i = 0;

   if (g_board[1+target - (inc - 1)] == pawn) then
	return true;
   end
   if (g_board[1+target - (inc + 1)] == pawn) then
	return true;
   end

	-- Attackable by pieces?
   for i = 2, 6, 1 do
        index = bit.lshift( bit.bor(color , i) , 4 );
        square = g_pieceList[1+index];
	while (square ~= 0) do
		if (IsSquareAttackableFrom(target, square)) then
			return true;
		end
		index = index + 1;
		square = g_pieceList[1+index];
	end
   end
   return false;
end
--

--
function IsHashMoveValid(hashMove)
    local from = bit.band( hashMove, 0xFF );
    local to = bit.band( bit.rshift(hashMove, 8) , 0xFF );
    local dir = to - from;
    local ourPiece = g_board[1+from];
    local pieceType = bit.band( ourPiece, 0x7 );
    local row = 0;

    if (pieceType < piecePawn or pieceType > pieceKing) then
	return false;
    end

    -- Can't move a piece we don't control
    if (g_toMove ~= bit.band(ourPiece, 0x8)) then
        return false;
    end

    -- Can't move to a square that has something of the same color
    if (g_board[1+to] ~= 0 and (g_toMove == bit.band(g_board[1+to] , 0x8))) then
        return false;
    end

    if (pieceType == piecePawn) then
        if ( bit.band( hashMove, moveflagEPC )>0 ) then
            return false;
        end

        -- Valid moves are push, capture, double push, promotions
        if ((g_toMove == colorWhite) ~= (dir < 0))  then
            -- Pawns have to move in the right direction
            return false;
        end

        row = bit.band( to , 0xF0 );
        if (((row == 0x90 and (g_toMove == 0)) or
             (row == 0x20 and g_toMove>0)) ~= (bit.band(hashMove , moveflagPromotion)>0) ) then
            -- Handle promotions
            return false;
        end

        if (dir == -16 or dir == 16) then
            -- White/Black push
            return (g_board[1+to] == 0);
        else
	 if (dir == -15 or dir == -17 or dir == 15 or dir == 17) then
            -- White/Black capture
            return (g_board[1+to] ~= 0);
         else
            if (dir == -32) then
                -- Double white push
		if (row ~= 0x60) then
		  return false;
		end
		if (g_board[1+to] ~= 0) then
		  return false;
		end
		if (g_board[1+(from - 16)] ~= 0) then
		  return false;
		end

            else
              if (dir == 32) then
                -- Double black push
		if (row ~= 0x50) then
		  return false;
		end
		if (g_board[1+to] ~= 0) then
		  return false;
		end
		if (g_board[1+(from + 16)] ~= 0) then
		  return false;
		end
              else
                  return false;
              end
            end
	 end
        end

        return true;

    else
        -- This validates that this piece type can actually make the attack
        if ( bit.rshift( hashMove, 16)>0 ) then
		return false;
	end
        return IsSquareAttackableFrom(to, from);
    end
end
--

--
function IsRepDraw()
    local i = g_moveCount - 5;
    local stop = g_moveCount - 1 - g_move50;
    stop = iif( stop < 0 , 0 , stop );

    while ( i >= stop ) do
        if (g_repMoveStack[1+i] == g_hashKeyLow) then
            return true;
	end
	i = i - 2;
    end
    return false;
end
--


function MovePicker(mp, hashMove, depth, killer1, killer2)

    mp.hashMove = hashMove;
    mp.depth = depth;
    mp.killer1 = killer1;
    mp.killer2 = killer2;

    mp.moves = {}			-- new Array();
    mp.losingCaptures = nil;
    mp.moveCount = 0;
    mp.atMove = -1;
    mp.moveScores = nil;
    mp.stage = 0;

end

function nextMove(mp)

    local i = 0;
    local j = 0;
    local captured = 0;
    local pieceType = 0;
    local bestMove = 0;
    local tmpMove = 0;
    local tmpScore = 0;
    local candidateMove = 0;

    mp.atMove = mp.atMove + 1;

         if (mp.atMove == mp.moveCount) then

            mp.stage = mp.stage + 1;
            if (mp.stage == 1) then
                if ((mp.hashMove ~= nil) and IsHashMoveValid(mp.hashMove)) then
                    mp.moves[1] = mp.hashMove;
                    mp.moveCount = 1;
                end
                if (mp.moveCount ~= 1) then
                    mp.hashMove = nil;
                    mp.stage = mp.stage + 1;
                end
            end

            if (mp.stage == 2) then
                GenerateCaptureMoves(mp.moves);

                mp.moveCount = table.getn( mp.moves );
                mp.moveScores = {}		-- new Array(this.moveCount);
                -- Move ordering
		for i = mp.atMove,  mp.moveCount-1, 1 do
                    captured = bit.band( g_board[1+ bit.band( bit.rshift(mp.moves[1+i] , 8) , 0xFF)] , 0x7 );
                    pieceType = bit.band( g_board[1+ bit.band( mp.moves[1+i] , 0xFF)] , 0x7 );
                    mp.moveScores[1+i] = bit.lshift(captured, 5) - pieceType;
                end
                -- No moves, onto next stage
                if (mp.atMove == mp.moveCount) then
			mp.stage = mp.stage + 1;
		end
            end

            if (mp.stage == 3) then
                if (IsHashMoveValid(mp.killer1) and (mp.killer1 ~= mp.hashMove)) then
                    mp.moves[1+table.getn(mp.moves)] = mp.killer1;
                    mp.moveCount = table.getn(mp.moves);
                else
                    mp.killer1 = 0;
                    mp.stage = mp.stage + 1;
                end
            end

            if (mp.stage == 4) then
                if (IsHashMoveValid(mp.killer2) and (mp.killer2 ~= mp.hashMove)) then
                    mp.moves[1+table.getn(mp.moves)] = mp.killer2;
                    mp.moveCount = table.getn(mp.moves);
                else
                    mp.killer2 = 0;
                    mp.stage = mp.stage + 1;
                end
            end

            if (mp.stage == 5) then
                GenerateAllMoves(mp.moves);
                mp.moveCount = table.getn(mp.moves);
                -- Move ordering
		for i = mp.atMove,  mp.moveCount-1, 1 do
                	mp.moveScores[1+i] = ScoreMove(mp.moves[1+i]);
		end
                -- No moves, onto next stage
                if (mp.atMove == mp.moveCount) then
			mp.stage = mp.stage + 1;
		end
            end

            if (mp.stage == 6) then
                -- Losing captures
                if (mp.losingCaptures ~= nil) then
                    for i = 0, table.getn( mp.losingCaptures )-1, 1 do
                        mp.moves[1+table.getn(mp.moves)] = mp.losingCaptures[1+i];
                    end
                    for i = mp.atMove,  mp.moveCount-1, 1 do
			mp.moveScores[1+i] = ScoreMove(mp.moves[1+i]);
		    end
                    mp.moveCount = table.getn(mp.moves);
                end
                -- No moves, onto next stage
                if (mp.atMove == mp.moveCount) then
			mp.stage = mp.stage + 1;
		end
            end

            if (mp.stage == 7) then
                return 0;
	    end
        end

        bestMove = mp.atMove;
        for j = mp.atMove + 1, mp.moveCount-1, 1 do
	    if(mp.moveScores[1+j]==nil) then
		break
	    end
            if (mp.moveScores[1+j] > mp.moveScores[1+bestMove]) then
                bestMove = j;
            end
        end

        if (bestMove ~= mp.atMove) then
            tmpMove = mp.moves[1+mp.atMove];
            mp.moves[1+mp.atMove] = mp.moves[1+bestMove];
            mp.moves[1+bestMove] = tmpMove;

            tmpScore = mp.moveScores[1+mp.atMove];
            mp.moveScores[1+mp.atMove] = mp.moveScores[1+bestMove];
            mp.moveScores[1+bestMove] = tmpScore;
        end

        candidateMove = mp.moves[1+mp.atMove];
        if ((mp.stage > 1 and candidateMove == mp.hashMove) or
            (mp.stage > 3 and candidateMove == mp.killer1) or
            (mp.stage > 4 and candidateMove == mp.killer2)) then

            return nextMove(mp);
        end

        if (mp.stage == 2 and (not See(candidateMove))) then
            if (mp.losingCaptures == nil) then
                mp.losingCaptures = {}			-- new Array();
            end
            mp.losingCaptures[1+ table.getn( mp.losingCaptures )] = candidateMove;
            return nextMove(mp);
        end
    return mp.moves[1+mp.atMove];
end
--

--
function AllCutNode(ply, depth, beta, allowNull)

    local hashMove = nil;
    local hashNode = nil;
    local hashValue = 0;
    local razorMargin = 2500 + 200 * ply;
    local razorBeta = 0;
    local v = 0;
    local r = 0;
    local value = 0;
    local moveMade = false;
    local realEval = 0;
    local inCheck = false;
    local currentMove = 0;
    local plyToSearch = 0;
    local doFullSearch = true;
    local value = 0;
    local reduced = 0;
    local histTo = 0;
    local histPiece = 0;
    local h = 0;
    local mp = {}

    if (ply <= 0) then
        return QSearch(beta - 1, beta, 0);
    end

    if (os.clock() - g_startTime > g_timeout) then
            -- Time cutoff
            g_searchValid = false;
            return beta - 1;

    end

    if(g_finCnt>g_maxfinCnt) then
	   -- Limit for moves
           g_searchValid = false;
           return beta - 1;
    end

    g_nodeCount = g_nodeCount + 1;

    if (IsRepDraw()) then
        return 0;
    end

    -- Mate distance pruning
    if (minEval + depth >= beta) then
       return beta;
    end

    if ((maxEval - (depth + 1)) < beta) then
	return (beta - 1);
    end

    hashNode = g_hashTable[1+ bit.band( g_hashKeyLow, g_hashMask )];

    if ((hashNode ~= nil) and (hashNode.lock == g_hashKeyHigh)) then
        hashMove = hashNode.bestMove;

        if (hashNode.hashDepth >= ply) then
            hashValue = hashNode.value;

		-- Fixup mate scores
	    if (hashValue >= maxMateBuffer) then
		hashValue = hashValue - depth;
	    else
		if (hashValue <= minMateBuffer) then
		   hashValue = hashValue + depth;
		end
	    end

	    if (hashNode.flags == hashflagExact) then
                return hashValue;
	    end
            if (hashNode.flags == hashflagAlpha and hashValue < beta) then
                return hashValue;
	    end
            if (hashNode.flags == hashflagBeta and hashValue >= beta) then
                return hashValue;
	    end
        end
    end

    -- TODO - positional gain?

    if ((not g_inCheck) and allowNull and (beta > minMateBuffer) and (beta < maxMateBuffer)) then
        -- Try some razoring
        if (hashMove == nil and ply < 4) then

            if (g_baseEval < beta - razorMargin) then
                razorBeta = beta - razorMargin;
                v = QSearch(razorBeta - 1, razorBeta, 0);
                if (v < razorBeta) then
                    return v;
		end
            end
        end

        -- TODO - static null move

        -- Null move
        -- Disable null move if potential zugzwang (no big pieces)
        if (ply > 1 and g_baseEval >= beta - iif(ply >= 4, 2500, 0) and
            (g_pieceCount[1+ bit.bor(pieceBishop, g_toMove)] ~= 0 or
             g_pieceCount[1+ bit.bor(pieceKnight, g_toMove)] ~= 0 or
             g_pieceCount[1+ bit.bor(pieceRook, g_toMove)] ~= 0 or
             g_pieceCount[1+ bit.bor(pieceQueen, g_toMove)] ~= 0)) then
            r = 3 + iif(ply >= 5, 1, ply / 4);
            if (g_baseEval - beta > 1500) then
		r = r + 1;
	    end

	    g_toMove = 8 - g_toMove;
	    g_baseEval = -g_baseEval;
	    g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristBlackLow );
	    g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristBlackHigh );

	    value = -AllCutNode(ply - r, depth + 1, -(beta - 1), false);

	    g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristBlackLow );
	    g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristBlackHigh );
	    g_toMove = 8 - g_toMove;
	    g_baseEval = -g_baseEval;

            if (value >= beta) then
	            return beta;
	    end
        end
    end

    moveMade = false;
    realEval = minEval;
    inCheck = g_inCheck;

    MovePicker(mp, hashMove, depth, g_killers[1+depth][1], g_killers[1+depth][1+1]);

    while(true) do

      currentMove = nextMove(mp);
      if (currentMove == 0) then
            break;
      end


      plyToSearch = ply - 1;

      if (MakeMove(currentMove)) then

        doFullSearch = true;

        if (g_inCheck) then
            -- Check extensions
            plyToSearch = plyToSearch + 1;
        else

            -- Late move reductions
            if (mp.stage == 5 and mp.atMove > 5 and ply >= 3) then
            	reduced = plyToSearch - iif(mp.atMove > 14, 2, 1);
		value = -AllCutNode(reduced, depth + 1, -(beta - 1), true);
                doFullSearch = (value >= beta);
            end
        end

        if (doFullSearch) then
            value = -AllCutNode(plyToSearch, depth + 1, -(beta  - 1), true);
        end


        moveMade = true;

        UnmakeMove(currentMove);

        if (not g_searchValid) then

            return beta - 1;
        end

        if (value > realEval) then

            if (value >= beta) then
		histTo = bit.band( bit.rshift(currentMove, 8) , 0xFF );
		if (g_board[1+histTo] == 0) then
		    histPiece = bit.band( g_board[1+ bit.band(currentMove , 0xFF)] , 0xF );
		    h = historyTable[1+histPiece][1+histTo];
		    h = h + (ply * ply)
		    if (h > 32767) then
		        h = bit.rshift( h, 1 );
		    end
		    historyTable[1+histPiece][1+histTo] = h;

		    if (g_killers[1+depth][1] ~= currentMove) then
		        g_killers[1+depth][1+1] = g_killers[1+depth][1];
		        g_killers[1+depth][1] = currentMove;
		    end
		end

                StoreHash(value, hashflagBeta, ply, currentMove, depth);
                return value;
            end

            realEval = value;
            hashMove = currentMove;
        end

      end
    end

    if (not moveMade) then
        -- If we have no valid moves it's either stalemate or checkmate
        if (g_inCheck) then
            return (minEval + depth);            -- Checkmate.
        else
            return 0;           -- Stalemate
	end
    end

    StoreHash(realEval, hashflagAlpha, ply, hashMove, depth);

    return realEval;
end
--

--
function AlphaBeta(ply, depth, alpha, beta)

    local moveMade = false;
    local realEval = 0;
    local inCheck = false;

    local oldAlpha = alpha;
    local hashMove = nil;

    local hashMove = nil;
    local hashFlag = hashflagAlpha;
    local hashNode = nil;
    local currentMove = 0;
    local value = 0;
    local histTo = 0;
    local histPiece = 0;
    local plyToSearch = ply - 1;
    local mp = {}

    if (ply <= 0) then
        return QSearch(alpha, beta, 0);
    end

    g_nodeCount = g_nodeCount + 1;

    if (depth > 0 and IsRepDraw()) then
        return 0;
    end

    -- Mate distance pruning
    alpha = iif( (alpha < minEval + depth) , alpha , minEval + depth );
    beta = iif( (beta > maxEval - (depth + 1)) , beta , maxEval - (depth + 1) );
    if (alpha >= beta) then
       return alpha;
    end


    hashNode = g_hashTable[1+ bit.band( g_hashKeyLow, g_hashMask )];
    if (hashNode ~= nil and hashNode.lock == g_hashKeyHigh) then
        hashMove = hashNode.bestMove;
    end

    inCheck = g_inCheck;
    moveMade = false;
    realEval = minEval;

    MovePicker(mp, hashMove, depth, g_killers[1+depth][1], g_killers[1+depth][1+1]);

    while(true) do

      currentMove = nextMove(mp);

      if (currentMove == 0) then
            break;
      end

      plyToSearch = ply - 1;

      if (MakeMove(currentMove)) then

        if (g_inCheck) then
            plyToSearch = plyToSearch + 1;		-- Check extensions
        end

        if (moveMade) then

            value = -AllCutNode(plyToSearch, depth + 1, -alpha, true);

            if (value > alpha) then
                value = -AlphaBeta(plyToSearch, depth + 1, -beta, -alpha);
            end
        else
            value = -AlphaBeta(plyToSearch, depth + 1, -beta, -alpha);
	end

        moveMade = true;

        UnmakeMove(currentMove);

        if (not g_searchValid) then
            return alpha;
        end

        if (value > realEval) then
            if (value >= beta) then
                histTo = bit.band( bit.rshift(currentMove, 8) , 0xFF );
                if (g_board[1+histTo] == 0) then
                    histPiece = bit.band( g_board[1+ bit.band( currentMove, 0xFF )] , 0xF );
		    h = historyTable[1+histPiece][1+histTo];
		    h = h + (ply * ply)
		    if (h > 32767) then
		        h = bit.rshift( h, 1 );
		    end
		    historyTable[1+histPiece][1+histTo] = h;

                    if (g_killers[1+depth][1] ~= currentMove) then
                        g_killers[1+depth][1+1] = g_killers[1+depth][1];
                        g_killers[1+depth][1] = currentMove;
                    end
                end

                StoreHash(value, hashflagBeta, ply, currentMove, depth);
                return value;
            end

            if (value > oldAlpha) then
                hashFlag = hashflagExact;
                alpha = value;
            end

            realEval = value;
            hashMove = currentMove;

        end

      end
    end

    if (not moveMade) then
        -- If we have no valid moves it's either stalemate or checkmate
        if (inCheck) then
            return (minEval + depth);	-- Checkmate.
        else
            return 0;			-- Stalemate
	end
    end

    StoreHash(realEval, hashFlag, ply, hashMove, depth);

    return realEval;
end
--

--
function InitializePieceList()

 local i = 0;
 local j = 0;
 local piece = 0;

 for i=0, 15, 1 do
        g_pieceCount[1+i] = 0;
        for j=0, 15, 1 do
            		-- 0 is used as the terminator for piece lists
        	g_pieceList[1+ bit.bor( bit.lshift(i, 4), j)] = 0;
        end
 end

 for i=0, 255, 1 do
        g_pieceIndex[1+i] = 0;
        if ( bit.band( g_board[1+i], bit.bor(colorWhite, colorBlack) )>0 ) then
		piece = bit.band( g_board[1+i], 0xF );

		g_pieceList[1+bit.bor( bit.lshift(piece, 4), g_pieceCount[1+piece])] = i;
		g_pieceIndex[1+i] = g_pieceCount[1+piece];
		g_pieceCount[1+piece] = g_pieceCount[1+piece] + 1;
        end
 end
end
--



-- SetSeeds for Zobrist...
mt={}

mt.N = 624;
mt.M = 397;
mt.MAG01 = {0x0, 0x9908b0df};

mt.mt = {}		-- new Array(N);
mt.mti = mt.N + 1;

mt.setSeed = function(N0)
	local i = 0;
	local s = 0;
	mt.mt[1]= N0;
	for i=1, mt.N-1, 1 do
		s = bit.bxor( mt.mt[1+(i - 1)] ,bit.rshift(mt.mt[1+(i - 1)], 30) );
		mt.mt[1+i] = bit.lshift( (1812433253 * bit.rshift(bit.band(s, 0xffff0000), 16)), 16)
			+ 1812433253 * bit.band(s, 0x0000ffff) + i;
	end
	mt.mti = mt.N;
	return;
	end

mt.next = function (bits)

	local x = 0;
	local y = 0;
	local k = 0;

	if (mt.mti >= mt.N) then

		for k=0,(mt.N - mt.M)-1,1 do
			x = bit.bor( bit.band(mt.mt[1+k], 0x80000000) , bit.band(mt.mt[1+(k + 1)], 0x7fffffff) );
			mt.mt[1+k] = bit.bxor( bit.bxor( mt.mt[1+(k + mt.M)] , bit.rshift(x, 1) ,
			mt.MAG01[1+bit.band(x, 0x1)] ) );
		end

		for k = mt.N - mt.M, (mt.N - 1)-1, 1 do
			x = bit.bor( bit.band(mt.mt[1+k], 0x80000000) , bit.band(mt.mt[1+(k + 1)], 0x7fffffff) );
			mt.mt[1+k] = bit.bxor( bit.bxor( mt.mt[1+k + (mt.M - mt.N)] , bit.rshift(x, 1) ,
			mt.MAG01[1+bit.band(x, 0x1)] ) );
		end
		x = bit.bor( bit.band(mt.mt[1+(mt.N - 1)], 0x80000000) , bit.band(mt.mt[1], 0x7fffffff) );
		mt.mt[1+(mt.N - 1)] = bit.bxor( bit.bxor( mt.mt[1+(mt.M - 1)] ,
			bit.rshift(x, 1) , mt.MAG01[1+bit.band(x, 0x1)] ) );
		mt.mti = 0;
	end

	y = mt.mt[1+mt.mti];
	mt.mti = mt.mti + 1;
	y = bit.bxor( y , bit.rshift( y, 11 ) );
	y = bit.bxor( y , bit.band( bit.lshift(y, 7) , 0x9d2c5680 ) );
	y = bit.bxor( y , bit.band( bit.lshift(y, 15) , 0xefc60000 ) );
	y = bit.bxor( y , bit.rshift( y, 18 ) );
	y = bit.band( bit.rshift(y, (32 - bits)) , 0xFFFFFFFF );
	return y;
	end

--

--
function ResetGame()
    local i = 0;
    local j = 0;
    local k = 0;
    local row = 0;
    local col = 0;
    local square = 0;
    local pieceDeltas = {}
    local index = 0;
    local dir = 0;
    local target = 0;
    local flip = -1;


    mt.setSeed(0x1BADF00D);

    g_killers = {}		--new Array(128);
    for i = 0, 127, 1 do
        g_killers[1+i] = {0, 0};
    end

    g_hashTable = {}		--new Array(g_hashSize);

    for i=0, 31, 1 do
	historyTable[1+i] = {}	--new Array(256);
	for j=0, 255, 1 do
		historyTable[1+i][1+j] = 0;
	end
    end

    g_zobristLow = {}	-- new Array(256);
    g_zobristHigh = {}	-- new Array(256);

    for i=0, 255, 1 do
        g_zobristLow[1+i] = {}		-- new Array(16);
        g_zobristHigh[1+i] = {}		-- new Array(16);
	for j = 0, 15, 1 do
		g_zobristLow[1+i][1+j] = mt.next(32);
		g_zobristHigh[1+i][1+j] = mt.next(32);
        end
    end
    g_zobristBlackLow = mt.next(32);
    g_zobristBlackHigh = mt.next(32);

    for row = 0, 7, 1 do
        for col = 0, 7, 1 do
            square = MakeSquare(row, col);
            flipTable[1+square] = MakeSquare(7 - row, col);
        end
    end

    pieceSquareAdj[1+piecePawn] = MakeTable(pawnAdj);
    pieceSquareAdj[1+pieceKnight] = MakeTable(knightAdj);
    pieceSquareAdj[1+pieceBishop] = MakeTable(bishopAdj);
    pieceSquareAdj[1+pieceRook] = MakeTable(rookAdj);
    pieceSquareAdj[1+pieceQueen] = MakeTable(emptyAdj);
    pieceSquareAdj[1+pieceKing] = MakeTable(kingAdj);


    pieceDeltas = { {}, {}, g_knightDeltas, g_bishopDeltas, g_rookDeltas, g_queenDeltas, g_queenDeltas };

    for i = 0, 255, 1 do
        g_vectorDelta[1+i] = {};			-- new Object()
        g_vectorDelta[1+i].delta = 0;
        g_vectorDelta[1+i].pieceMask = {}		-- new Array(2);
        g_vectorDelta[1+i].pieceMask[1+0] = 0;
        g_vectorDelta[1+i].pieceMask[1+1] = 0;
    end

    -- Initialize the vector delta table
    row = 0;
    while(row < 0x80) do
	col = 0;
        while(col < 0x8) do
            square = bit.bor(row, col);

            -- Pawn moves
            index = square - (square - 17) + 128;
            g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)] =
		bit.bor(g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)], bit.lshift(1, piecePawn) );
            index = square - (square - 15) + 128;
            g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)] =
		bit.bor(g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)], bit.lshift(1, piecePawn) );

            index = square - (square + 17) + 128;
            g_vectorDelta[1+index].pieceMask[1] =
		bit.bor( g_vectorDelta[1+index].pieceMask[1], bit.lshift(1, piecePawn) );
            index = square - (square + 15) + 128;
            g_vectorDelta[1+index].pieceMask[1] =
		bit.bor( g_vectorDelta[1+index].pieceMask[1], bit.lshift(1, piecePawn) );

            for i = pieceKnight, pieceKing, 1 do
		dir = 0
                while(dir < table.getn( pieceDeltas[1+i]) ) do
                    target = square + pieceDeltas[1+i][1+dir];
                    while (bit.band(target, 0x88)==0) do
                        index = square - target + 128;

                        g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)] =
				bit.bor( g_vectorDelta[1+index].pieceMask[1+bit.rshift(colorWhite, 3)], bit.lshift(1, i) );
                        g_vectorDelta[1+index].pieceMask[1] =
				bit.bor( g_vectorDelta[1+index].pieceMask[1+0], bit.lshift(1, i) );

                        flip = -1;
                        if (square < target) then
                            flip = 1;
                        end
                        if (bit.band(square, 0xF0) == bit.band(target, 0xF0)) then
                            -- On the same row
                            g_vectorDelta[1+index].delta = flip * 1;
                        else
			 if (bit.band(square, 0x0F) == bit.band(target, 0x0F)) then
                            -- On the same column
                            g_vectorDelta[1+index].delta = flip * 16;
                         else
			  if ((square % 15) == (target % 15)) then
                            g_vectorDelta[1+index].delta = flip * 15;
                          else
			   if ((square % 17) == (target % 17)) then
                            g_vectorDelta[1+index].delta = flip * 17;
                           end
			  end
			 end
			end

                        if (i == pieceKnight) then
                            g_vectorDelta[1+index].delta = pieceDeltas[1+i][1+dir];
                            break;
                        end

                        if (i == pieceKing) then
                            break;
			end

                        target = target + pieceDeltas[1+i][1+dir];
		    end


		    dir = dir + 1;
                end

            end
	    col = col + 1;
        end
	row = row + 0x10;
    end

end
--

--
function Search(maxPly)

    local alpha = minEval;
    local beta = maxEval;

    local bestMove = 0;
    local value = 0;
    local i = 1;
    local tmp = 0;

    g_globalPly = g_globalPly + 1;
    g_nodeCount = 0;
    g_qNodeCount = 0;
    g_searchValid = true;
    g_foundmove = 0;

    g_finCnt = 0;
    g_startTime = os.clock();

    while( i <= maxPly and g_searchValid ) do
        tmp = AlphaBeta(i, 0, alpha, beta);
        if (not g_searchValid) then
		break;
	end

        value = tmp;

        if (value > alpha and value < beta) then
            alpha = value - 500;
            beta = value + 500;

            if (alpha < minEval) then
		alpha = minEval;
	    end
            if (beta > maxEval) then
		beta = maxEval;
	    end
        else
	  if (alpha ~= minEval) then
            alpha = minEval;
            beta = maxEval;
            i = i - 1;
	  end
        end

        if (g_hashTable[1+bit.band(g_hashKeyLow, g_hashMask)] ~= nil) then
            bestMove = g_hashTable[1+bit.band(g_hashKeyLow, g_hashMask)].bestMove;
        end

	finishPlyCallback(bestMove, value, i);

	i = i + 1;
    end

    finishMoveCallback(bestMove, value, i - 1);

end
--

--
function PawnEval(color)
    local pieceIdx = bit.lshift( bit.bor(color, 1) , 4 );
    local from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;

    while (from ~= 0) do
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
end
--

--
function Mobility(color)
    local result = 0;
    local from = 0;
    local mob = 0;
    local pieceIdx = 0;
    local enemy = iif(color == 8, 0x10, 0x8 );
    local mobUnit = iif(color == 8, g_mobUnit[1], g_mobUnit[1+1] );

    -- Knight mobility
    mob = -3;
    pieceIdx = bit.lshift( bit.bor(color, 2), 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;

    while (from ~= 0) do
        mob = mob + mobUnit[1+g_board[1+(from + 31)]];
        mob = mob + mobUnit[1+g_board[1+(from + 33)]];
        mob = mob + mobUnit[1+g_board[1+(from + 14)]];
        mob = mob + mobUnit[1+g_board[1+(from - 14)]];
        mob = mob + mobUnit[1+g_board[1+(from - 31)]];
        mob = mob + mobUnit[1+g_board[1+(from - 33)]];
        mob = mob + mobUnit[1+g_board[1+(from + 18)]];
        mob = mob + mobUnit[1+g_board[1+(from - 18)]];
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
    result = result + (65 * mob);

    -- Bishop mobility
    mob = -4;
    pieceIdx = bit.lshift( bit.bor(color, 3), 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;
    while (from ~= 0) do
        mob = AdjMob( from, -15, mob, enemy );
	mob = AdjMob( from, -17, mob, enemy );
        mob = AdjMob( from, 15, mob, enemy );
	mob = AdjMob( from, 17, mob, enemy );
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
    result = result + ( 50 * mob );

    -- Rook mobility
    mob = -4;
    pieceIdx = bit.lshift( bit.bor(color, 4) , 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;
    while (from ~= 0) do
        mob = AdjMob( from, -1, mob, enemy );
        mob = AdjMob( from, 1, mob, enemy );
        mob = AdjMob( from, -16, mob, enemy );
        mob = AdjMob( from, 16, mob, enemy );
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
    result = result + ( 25 * mob );

    -- Queen mobility
    mob = -2;
    pieceIdx = bit.lshift( bit.bor(color, 5), 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;
    while (from ~= 0) do
        mob = AdjMob( from, -15, mob, enemy );
	mob = AdjMob( from, -17, mob, enemy );
        mob = AdjMob( from, 15, mob, enemy );
	mob = AdjMob( from, 17, mob, enemy );
        mob = AdjMob( from, -1, mob, enemy );
        mob = AdjMob( from, 1, mob, enemy );
        mob = AdjMob( from, -16, mob, enemy );
        mob = AdjMob( from, 16, mob, enemy );
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
    result = result + ( 22 * mob );

    return result;
end
--

--
function AdjMob(from, dto, mob, enemy )
local to=from + dto;
local mb=mob;
while (g_board[1+to] == 0) do
	to = to + dto;
	mb = mb + 1;
end
if ( bit.band(g_board[1+to], enemy)>0 ) then
	mb = mb + 1;
end
return mb;
end
--

--
function Evaluate()
    local curEval = g_baseEval;
    local mobility = Mobility(8) - Mobility(0);

    local evalAdjust = 0;
    -- Black queen gone, then cancel white's penalty for king movement
    if (g_pieceList[1+ bit.lshift(pieceQueen, 4)] == 0) then
        evalAdjust = evalAdjust -
	 pieceSquareAdj[1+pieceKing][1+g_pieceList[1+ bit.lshift( bit.bor(colorWhite, pieceKing), 4)]];
    end
    -- White queen gone, then cancel black's penalty for king movement
    if (g_pieceList[1+ bit.lshift( bit.bor(colorWhite, pieceQueen), 4)] == 0) then
        evalAdjust = evalAdjust +
	 pieceSquareAdj[1+pieceKing][1+flipTable[1+g_pieceList[1+bit.lshift(pieceKing, 4)]]];
    end

    -- Black bishop pair
    if (g_pieceCount[1+pieceBishop] >= 2) then
        evalAdjust = evalAdjust - 500;
    end
    -- White bishop pair
    if (g_pieceCount[1+ bit.bor(pieceBishop, colorWhite)] >= 2) then
        evalAdjust = evalAdjust + 500;
    end

    if (g_toMove == 0) then
        -- Black
        curEval = curEval - mobility;
        curEval = curEval - evalAdjust;
    else
        curEval = curEval + mobility;
        curEval = curEval + evalAdjust;
    end

    return curEval;
end
--

--
function ScoreMove(move)
    local moveTo = bit.band( bit.rshift(move, 8), 0xFF );
    local captured = bit.band( g_board[1+moveTo] , 0x7 );
    local piece = g_board[1+ bit.band(move, 0xFF) ];
    local score = 0;
    local pieceType = bit.band( piece, 0x7 );
    if (captured ~= 0) then
        score = bit.lshift(captured, 5) - pieceType;
    else
        score = historyTable[1+ bit.band(piece, 0xF) ][1+moveTo];
    end
    return score;
end
--

--
function QSearch(alpha, beta, ply)

    g_qNodeCount = g_qNodeCount + 1;

    local realEval = iif( g_inCheck, (minEval + 1), Evaluate() );

    if (realEval >= beta) then
        return realEval;
    end

    if (realEval > alpha) then
        alpha = realEval;
    end

    local moves = {}		-- new Array();
    local moveScores = {}	-- new Array();
    local wasInCheck = g_inCheck;
    local i = 0;
    local j = 0;
    local captured = 0;
    local pieceType = 0;
    local bestMove = 0;
    local tmpMove = 0;
    local tmpScore = 0;
    local value = 0;
    local checking = false;
    local brk = false;

    if (wasInCheck) then
        -- TODO: Fast check escape generator and fast checking moves generator
        GenerateCaptureMoves(moves);
        GenerateAllMoves(moves);

        for i=0, table.getn( moves )-1, 1 do
		moveScores[1+i] = ScoreMove(moves[1+i]);
	end
    else
        GenerateCaptureMoves(moves);

 	for i=0, table.getn( moves )-1, 1 do
            captured = bit.band( g_board[1+ bit.band( bit.rshift(moves[1+i], 8), 0xFF)] , 0x7 );
            pieceType = bit.band( g_board[1+ bit.band( moves[1+i] , 0xFF )] , 0x7 );

            moveScores[1+i] = bit.lshift(captured, 5) - pieceType;
	end

    end

    for i=0, table.getn( moves )-1, 1 do

        bestMove = i;
	for j = table.getn( moves )-1, i+1, -1 do
          if (moveScores[1+j] > moveScores[1+bestMove]) then
       		bestMove = j;
	  end
	end

	tmpMove = moves[1+i];
	moves[1+i] = moves[1+bestMove];
	moves[1+bestMove] = tmpMove;

	tmpScore = moveScores[1+i];
	moveScores[1+i] = moveScores[1+bestMove];
	moveScores[1+bestMove] = tmpScore;

	if( (wasInCheck or See(moves[1+i])) and MakeMove(moves[1+i])) then

	  value = -QSearch(-beta, -alpha, ply - 1);

          UnmakeMove(moves[1+i]);

          if (value > realEval) then
            if (value >= beta) then
                return value;
            end
            if (value > alpha) then
                alpha = value;
            end
            realEval = value;
          end

	end

    end


    if ((ply == 0) and (not wasInCheck)) then
	moves = {}
	GenerateAllMoves(moves);

	for i=0, table.getn( moves )-1, 1 do
            moveScores[1+i] = ScoreMove(moves[1+i]);
        end

	for i=0, table.getn( moves )-1, 1 do
            bestMove = i;
            for j = table.getn( moves )-1, i+1, -1 do

                if (moveScores[1+j] > moveScores[1+bestMove]) then
                    bestMove = j;
                end
            end

            tmpMove = moves[1+i];
            moves[1+i] = moves[1+bestMove];
            moves[1+bestMove] = tmpMove;

            tmpScore = moveScores[1+i];
            moveScores[1+i] = moveScores[1+bestMove];
            moveScores[1+bestMove] = tmpScore;

	    brk = false;

            if (not MakeMove(moves[1+i])) then
                brk = true;
	    else

                checking = g_inCheck;
                UnmakeMove(moves[1+i]);

		if (not checking) then
                   brk = true;
		else

            	  if (not See(moves[1+i])) then
                     brk = true;
		  end

                end
            end


	    if(not brk) then

              MakeMove(moves[1+i]);

              value = -QSearch(-beta, -alpha, ply - 1);

              UnmakeMove(moves[1+i]);

              if (value > realEval) then
                 if (value >= beta) then
                    return value;
		 end

                 if (value > alpha) then
                    alpha = value;
		 end

                 realEval = value;
              end
	   end
	end
    end

    return realEval;
end
--

--
function UndoHistory(ep, castleRights, inCheck, baseEval, hashKeyLow, hashKeyHigh, move50, captured)
    local ud = {}
    ud.ep = ep;
    ud.castleRights = castleRights;
    ud.inCheck = inCheck;
    ud.baseEval = baseEval;
    ud.hashKeyLow = hashKeyLow;
    ud.hashKeyHigh = hashKeyHigh;
    ud.move50 = move50;
    ud.captured = captured;
    return ud;
end
--

--
function MakeMove(move)

    local me = bit.rshift( g_toMove, 3 );
    local otherColor = 8 - g_toMove;

    local flags = bit.band( move , 0xFF0000 );
    local to = bit.band( bit.rshift(move , 8) , 0xFF );
    local from = bit.band( move , 0xFF );
    local diff = to - from;
    local captured = g_board[1+to];
    local piece = g_board[1+from];
    local epcEnd = to;
    local rook = 0;
    local rookIndex = 0;
    local newPiece = 0;
    local pawnType = 0;
    local promoteType = 0;
    local kingPos = 0;
    local theirKingPos = 0;
    local capturedType = 0;
    local lastPieceSquare = 0;
    local lastPawnSquare = 0;

    g_finCnt = g_finCnt + 1;

    if ( bit.band(flags , moveflagEPC)>0 ) then
        epcEnd = iif( me>0 , (to + 0x10) , (to - 0x10) );
        captured = g_board[1+epcEnd];
        g_board[1+epcEnd] = pieceEmpty;
    end

    g_moveUndoStack[1+g_moveCount] = UndoHistory(g_enPassentSquare, g_castleRights, g_inCheck, g_baseEval, g_hashKeyLow, g_hashKeyHigh, g_move50, captured);
    g_moveCount = g_moveCount + 1;

    g_enPassentSquare = -1;

    if (flags>0) then
        if ( bit.band( flags , moveflagCastleKing )>0 ) then
            if (IsSquareAttackable(from + 1, otherColor) or
            	IsSquareAttackable(from + 2, otherColor)) then
                g_moveCount = g_moveCount - 1;
                return false;
            end

            rook = g_board[1+(to + 1)];

            g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+(to + 1)][1+bit.band(rook, 0xF)] );
            g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+(to + 1)][1+bit.band(rook, 0xF)] );
            g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+(to - 1)][1+bit.band(rook, 0xF)] );
            g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+(to - 1)][1+bit.band(rook, 0xF)] );

            g_board[1+(to - 1)] = rook;
            g_board[1+(to + 1)] = pieceEmpty;

            g_baseEval = g_baseEval -
		pieceSquareAdj[1+ bit.band(rook, 0x7)][1+ iif(me == 0, flipTable[1+(to + 1)], (to + 1))];
            g_baseEval = g_baseEval +
		pieceSquareAdj[1+ bit.band(rook, 0x7)][1+ iif(me == 0, flipTable[1+(to - 1)], (to - 1))];

            rookIndex = g_pieceIndex[1+(to + 1)];
            g_pieceIndex[1+(to - 1)] = rookIndex;
            g_pieceList[1+ bit.bor( bit.lshift(bit.band(rook, 0xF) , 4) , rookIndex)] = to - 1;

        else
	  if ( bit.band( flags , moveflagCastleQueen)>0 ) then
            if (IsSquareAttackable(from - 1, otherColor) or
            	IsSquareAttackable(from - 2, otherColor)) then
                g_moveCount = g_moveCount - 1;
                return false;
            end

            rook = g_board[1+(to - 2)];

            g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+(to -2)][1+bit.band(rook, 0xF)] );
            g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+(to - 2)][1+bit.band(rook, 0xF)] );
            g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+(to + 1)][1+bit.band(rook, 0xF)] );
            g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+(to + 1)][1+bit.band(rook, 0xF)] );

            g_board[1+(to + 1)] = rook;
            g_board[1+(to - 2)] = pieceEmpty;

            g_baseEval = g_baseEval -
		pieceSquareAdj[1+ bit.band(rook, 0x7)][1+ iif(me == 0, flipTable[1+(to - 2)], (to - 2))];
            g_baseEval = g_baseEval +
		pieceSquareAdj[1+ bit.band(rook, 0x7)][1+ iif(me == 0, flipTable[1+(to + 1)], (to + 1))];

            rookIndex = g_pieceIndex[1+(to - 2)];
            g_pieceIndex[1+(to + 1)] = rookIndex;
            g_pieceList[1+ bit.bor( bit.lshift(bit.band(rook , 0xF) , 4) , rookIndex )] = to + 1;

	  end
        end
    end

    if (captured>0) then
        -- Remove our piece from the piece list
        capturedType = bit.band( captured , 0xF );

        g_pieceCount[1+capturedType] = g_pieceCount[1+capturedType] - 1;
        lastPieceSquare = g_pieceList[1+ bit.bor( bit.lshift(capturedType, 4) , g_pieceCount[1+capturedType] )];

	g_pieceIndex[1+lastPieceSquare] = g_pieceIndex[1+epcEnd];
        g_pieceList[1+ bit.bor( bit.lshift(capturedType , 4) , g_pieceIndex[1+lastPieceSquare])] = lastPieceSquare;
        g_pieceList[1+ bit.bor( bit.lshift(capturedType , 4) , g_pieceCount[1+capturedType])] = 0;


        g_baseEval = g_baseEval + materialTable[1+ bit.band(captured, 0x7)];
        g_baseEval = g_baseEval + pieceSquareAdj[1+ bit.band(captured, 0x7)][1+ iif(me>0, flipTable[1+epcEnd] , epcEnd )];

        g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+epcEnd][1+capturedType] );
        g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+epcEnd][1+capturedType] );
        g_move50 = 0;
    else
	if (bit.band(piece, 0x7) == piecePawn) then
        	if (diff < 0) then
		  diff = -diff;
		end
        	if (diff > 16) then
           	  g_enPassentSquare = iif( me>0 , (to + 0x10) , (to - 0x10) );
        	end
        	g_move50 = 0;
	end
    end

    g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+from][1+bit.band(piece, 0xF)] );
    g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+from][1+bit.band(piece, 0xF)] );
    g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+to][1+bit.band(piece, 0xF)] );
    g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+to][1+bit.band(piece, 0xF)] );
    g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristBlackLow );
    g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristBlackHigh );

    g_castleRights = bit.band( g_castleRights, bit.band( g_castleRightsMask[1+from], g_castleRightsMask[1+to] ) );

    g_baseEval = g_baseEval - pieceSquareAdj[1+bit.band( piece, 0x7)][1+ iif(me == 0 , flipTable[1+from] , from)];

    -- Move our piece in the piece list
    g_pieceIndex[1+to] = g_pieceIndex[1+from];
    g_pieceList[1+ bit.bor( bit.lshift(bit.band(piece, 0xF) , 4) , g_pieceIndex[1+to] )] = to;

    if (bit.band(flags, moveflagPromotion)>0) then

        newPiece = bit.band( piece, bit.bnot(0x7) );
        if ( bit.band( flags, moveflagPromoteKnight)>0  ) then
            newPiece = bit.bor( newPiece, pieceKnight );
        else
	 if ( bit.band(flags, moveflagPromoteQueen)>0 ) then
            newPiece = bit.bor( newPiece, pieceQueen );
	 else
	  if ( bit.band( flags, moveflagPromoteBishop)>0 ) then
            newPiece = bit.bor( newPiece, pieceBishop );
          else
            newPiece = bit.bor( newPiece, pieceRook );
	  end
	 end
 	end

        g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+to][1+bit.band(piece , 0xF)] );
        g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+to][1+bit.band(piece , 0xF)] );
        g_board[1+to] = newPiece;
        g_hashKeyLow = bit.bxor( g_hashKeyLow, g_zobristLow[1+to][1+bit.band(newPiece , 0xF)] );
        g_hashKeyHigh = bit.bxor( g_hashKeyHigh, g_zobristHigh[1+to][1+bit.band(newPiece , 0xF)] );

        g_baseEval = g_baseEval + pieceSquareAdj[1+bit.band(newPiece, 0x7)][1+ iif(me == 0, flipTable[1+to], to)];
        g_baseEval = g_baseEval - materialTable[1+piecePawn];
        g_baseEval = g_baseEval + materialTable[1+bit.band(newPiece, 0x7)];

        pawnType = bit.band( piece, 0xF );
        promoteType = bit.band( newPiece, 0xF );

        g_pieceCount[1+pawnType] = g_pieceCount[1+pawnType] - 1;

        lastPawnSquare = g_pieceList[1+ bit.bor( bit.lshift(pawnType, 4) , g_pieceCount[1+pawnType] )];
        g_pieceIndex[1+lastPawnSquare] = g_pieceIndex[1+to];
        g_pieceList[1+ bit.bor(bit.lshift(pawnType, 4) , g_pieceIndex[1+lastPawnSquare])] = lastPawnSquare;
        g_pieceList[1+ bit.bor( bit.lshift(pawnType, 4) , g_pieceCount[1+pawnType] )] = 0;
        g_pieceIndex[1+to] = g_pieceCount[1+promoteType];
        g_pieceList[1+ bit.bor( bit.lshift(promoteType , 4) , g_pieceIndex[1+to] )] = to;
        g_pieceCount[1+promoteType] = g_pieceCount[1+promoteType] + 1;
    else
        g_board[1+to] = g_board[1+from];

        g_baseEval = g_baseEval + pieceSquareAdj[1+bit.band(piece, 0x7)][1+ iif(me == 0, flipTable[1+to], to)];
    end
    g_board[1+from] = pieceEmpty;

    g_toMove = otherColor;
    g_baseEval = -g_baseEval;

    if ((bit.band(piece, 0x7)>0) == ((pieceKing>0) or g_inCheck)) then
        if (IsSquareAttackable(g_pieceList[1+ bit.lshift( bit.bor(pieceKing,(8-g_toMove)),4)], otherColor)) then
            UnmakeMove(move);
            return false;
        end
    else
        kingPos = g_pieceList[1+ bit.lshift( bit.bor(pieceKing,(8-g_toMove)),4)];

        if (ExposesCheck(from, kingPos)) then
            UnmakeMove(move);
	        return false;
        end

        if (epcEnd ~= to) then
            if (ExposesCheck(epcEnd, kingPos)) then
                UnmakeMove(move);
                return false;
            end
        end
    end

    g_inCheck = false;

    if (flags <= moveflagEPC) then
        theirKingPos = g_pieceList[1+ bit.lshift( bit.bor(pieceKing, g_toMove) , 4)];

        -- First check if the piece we moved can attack the enemy king
        g_inCheck = IsSquareAttackableFrom(theirKingPos, to);

        if (not g_inCheck) then
            -- Now check if the square we moved from exposes check on the enemy king
            g_inCheck = ExposesCheck(from, theirKingPos);

            if (not g_inCheck) then
                -- Finally, ep. capture can cause another square to be exposed
                if (epcEnd ~= to) then
                    g_inCheck = ExposesCheck(epcEnd, theirKingPos);
                end
            end
        end
    else
        -- Castle or promotion, slow check
        g_inCheck = IsSquareAttackable(g_pieceList[1+ bit.lshift( bit.bor(pieceKing, g_toMove), 4)], 8-g_toMove);
    end

    g_repMoveStack[1+(g_moveCount - 1)] = g_hashKeyLow;
    g_move50 = g_move50 + 1;

    return true;
end
--

--
function UnmakeMove(move)

    g_toMove = 8 - g_toMove;
    g_baseEval = -g_baseEval;

    g_moveCount = g_moveCount - 1;

    local otherColor = 8 - g_toMove;
    local me = bit.rshift( g_toMove, 3 );
    local them = bit.rshift( otherColor, 3 );

    local flags = bit.band( move, 0xFF0000 );
    local captured = g_moveUndoStack[1+g_moveCount].captured;
    local to = bit.band( bit.rshift(move, 8) , 0xFF );
    local from = bit.band( move , 0xFF );

    local piece = g_board[1+to];
    local rook = 0;
    local rookIndex = 0;
    local epcEnd = 0;
    local pawnType = 0;
    local promoteType = 0;
    local lastPromoteSquare = 0;
    local captureType = 0;

    g_enPassentSquare = g_moveUndoStack[1+g_moveCount].ep;
    g_castleRights = g_moveUndoStack[1+g_moveCount].castleRights;
    g_inCheck = g_moveUndoStack[1+g_moveCount].inCheck;
    g_baseEval = g_moveUndoStack[1+g_moveCount].baseEval;
    g_hashKeyLow = g_moveUndoStack[1+g_moveCount].hashKeyLow;
    g_hashKeyHigh = g_moveUndoStack[1+g_moveCount].hashKeyHigh;
    g_move50 = g_moveUndoStack[1+g_moveCount].move50;

    if (flags>0) then
        if ( bit.band(flags, moveflagCastleKing)>0 ) then
            rook = g_board[1+(to - 1)];
            g_board[1+(to + 1)] = rook;
            g_board[1+(to - 1)] = pieceEmpty;

            rookIndex = g_pieceIndex[1+(to - 1)];
            g_pieceIndex[1+(to + 1)] = rookIndex;
            g_pieceList[1+ bit.bor( bit.lshift(bit.band(rook , 0xF) , 4) , rookIndex )] = to + 1;

        else
	 if ( bit.band(flags, moveflagCastleQueen)>0 ) then
            rook = g_board[1+(to + 1)];
            g_board[1+(to - 2)] = rook;
            g_board[1+(to + 1)] = pieceEmpty;

            rookIndex = g_pieceIndex[1+(to + 1)];
            g_pieceIndex[1+(to - 2)] = rookIndex;
            g_pieceList[1+ bit.bor( bit.lshift(bit.band(rook, 0xF) , 4) , rookIndex )] = to - 2;
	 end
        end
    end

    if ( bit.band(flags, moveflagPromotion)>0 ) then
        piece = bit.bor( bit.band(g_board[1+to] , bit.bnot(0x7)) , piecePawn );
        g_board[1+from] = piece;

        pawnType = bit.band( g_board[1+from] , 0xF );
        promoteType = bit.band( g_board[1+to] , 0xF );

        g_pieceCount[1+promoteType] = g_pieceCount[1+promoteType] - 1;

        lastPromoteSquare = g_pieceList[1+ bit.bor( bit.lshift(promoteType, 4) , g_pieceCount[1+promoteType] )];
        g_pieceIndex[1+lastPromoteSquare] = g_pieceIndex[1+to];
        g_pieceList[1+ bit.bor( bit.lshift(promoteType, 4), g_pieceIndex[1+lastPromoteSquare])] = lastPromoteSquare;
        g_pieceList[1+ bit.bor( bit.lshift(promoteType, 4), g_pieceCount[1+promoteType] )] = 0;
        g_pieceIndex[1+to] = g_pieceCount[1+pawnType];
        g_pieceList[1+ bit.bor( bit.lshift(pawnType, 4), g_pieceIndex[1+to] )] = to;
        g_pieceCount[1+pawnType] = g_pieceCount[1+pawnType] + 1;
    else
        g_board[1+from] = g_board[1+to];
    end

    epcEnd = to;
    if (bit.band(flags, moveflagEPC)>0) then
        if (g_toMove == colorWhite) then
            epcEnd = to + 0x10;
        else
            epcEnd = to - 0x10;
	end
        g_board[1+to] = pieceEmpty;
    end

    g_board[1+epcEnd] = captured;

	-- Move our piece in the piece list
    g_pieceIndex[1+from] = g_pieceIndex[1+to];
    g_pieceList[1+ bit.bor(  bit.lshift(bit.band(piece , 0xF) , 4) , g_pieceIndex[1+from] )] = from;

    if (captured>0) then
		-- Restore our piece to the piece list
        captureType = bit.band( captured, 0xF );
        g_pieceIndex[1+epcEnd] = g_pieceCount[1+captureType];
        g_pieceList[1+ bit.bor( bit.lshift(captureType , 4) , g_pieceCount[1+captureType] )] = epcEnd;
        g_pieceCount[1+captureType] = g_pieceCount[1+captureType] + 1;
    end

end
--

--
function ExposesCheck(from, kingPos)
    local index = kingPos - from + 128;
    local delta = 0;
    local pos = 0;
    local piece = 0;
    local backwardIndex = 0;
    -- If a queen can't reach it, nobody can!
    if ( bit.band(g_vectorDelta[1+index].pieceMask[1] , bit.lshift(1,pieceQueen)) ~= 0) then
        delta = g_vectorDelta[1+index].delta;
        pos = kingPos + delta;
        while (g_board[1+pos] == 0) do
	  pos = pos + delta;
        end

        piece = g_board[1+pos];
        if ( bit.band( bit.band(piece, bit.bxor(g_board[1+kingPos], 0x18)) , 0x18) == 0) then
            return false;
	end

        -- Now see if the piece can actually attack the king
        backwardIndex = pos - kingPos + 128;
        return ( bit.band(g_vectorDelta[1+backwardIndex].pieceMask[1+ bit.band(bit.rshift(piece, 3), 1)] , bit.lshift(1, bit.band(piece, 0x7))) ~= 0 );
    end
    return false;
end
--

--

function IsSquareOnPieceLine(target, from)
    local index = from - target + 128;
    local piece = g_board[1+from];
    return (bit.band(g_vectorDelta[1+index].pieceMask[1+ bit.band( bit.rshift(piece, 3) , 1)] , bit.lshift(1, bit.band(piece, 0x7))) > 0 );
end

--

--
function GetMoveSAN(move, validMoves)

	local i = 0;
	local from = bit.band( move, 0xFF );
	local to = bit.band( bit.rshift(move, 8) , 0xFF );
	local moveFrom = 0;
	local moveTo = 0;

	if ( bit.band(move , moveflagCastleKing)>0) then
		return "O-O";
	end
	if ( bit.band(move, moveflagCastleQueen)>0) then
		return "O-O-O";
	end

	local pieceType = bit.band( g_board[1+from] , 0x7 );
	local result = string.upper( PieceCharList[1+pieceType] );

	local dupe = false;
	local rowDiff = true;
	local colDiff = true;
	local posmoves = {}

	if (validMoves == nil) then
		validMoves = GenerateValidMoves();
	end

	for i = 0, table.getn(validMoves)-1,1 do
		moveFrom = bit.band( validMoves[1+i] , 0xFF );
		moveTo = bit.band( bit.rshift(validMoves[1+i], 8) , 0xFF );
		if (moveFrom ~= from and moveTo == to and
			(bit.band(g_board[1+moveFrom], 0x7) == pieceType)) then
			dupe = true;
			if (bit.band(moveFrom, 0xF0) == bit.band(from, 0xF0)) then
				rowDiff = false;
			end
			if (bit.band(moveFrom, 0x0F) == bit.band(from, 0x0F)) then
				colDiff = false;
			end
		end
	end

	if (dupe) then
		if (colDiff) then
			result = result .. string.sub( FormatSquare(from), 1, 1 );
		else
		 if (rowDiff) then
			result = result .. string.sub( FormatSquare(from), 2, 2 );
		 else
			result = result .. FormatSquare(from);
		 end
		end
	else
	 if ((pieceType == piecePawn) and (g_board[1+to] ~= 0)) then
		result = result .. string.sub( FormatSquare(from), 1, 1 );
	 end
	end

	if ((g_board[1+to] ~= 0) or (bit.band(move, moveflagEPC)>0)) then
		result = result .. "x";
	end

	result = result .. FormatSquare(to);

	if ( bit.band( move, moveflagPromotion )>0 ) then
		if (bit.band( move, moveflagPromoteBishop )>0 ) then
		  result = result .. "=B";
		else
		 if ( bit.band( move, moveflagPromoteKnight )>0 ) then
		    result = result .. "=N";
		 else
		  if ( bit.band( move, moveflagPromoteQueen )>0 ) then
		     result = result .. "=Q";
		  else
		     result = result .. "=R";
		  end
		 end
		end
	end

	MakeMove(move);


	if (g_inCheck) then
	    posmoves = GenerateValidMoves();
	    result = result .. iif(table.getn( posmoves )==0 , "#" , "+" );
	end
	UnmakeMove(move);

	return result;
end
--


--
function GenerateMove(from, to)
    return bit.bor( from, bit.lshift(to, 8) );
end
--

--
function GenerateMove2(from, to, flags)
    return bit.bor( from , bit.bor( bit.lshift(to, 8), flags ) );
end
--

--
function GenerateValidMoves()
    local moveList = {}		-- new Array();
    local allMoves = {}		-- new Array();
    GenerateCaptureMoves(allMoves);
    GenerateAllMoves(allMoves);
    local i = 0;

    for i = table.getn(allMoves)-1, 0, -1 do
        if (MakeMove(allMoves[1+i])) then
            moveList[1+ table.getn(moveList)] = allMoves[1+i];
            UnmakeMove(allMoves[1+i]);
        end
    end

    return moveList;
end
--

--
function GenerateAllMoves(moveStack)

    local from = 0;
    local piece = 0;
    local pieceIdx = 0;
    local castleRights = 0;

	-- Pawn quiet moves
    pieceIdx = bit.lshift( bit.bor(g_toMove , 1) , 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;
    while (from ~= 0) do
        GeneratePawnMoves(moveStack, from);
        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end

    -- Knight quiet moves
	pieceIdx = bit.lshift( bit.bor(g_toMove , 2) , 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 1, from, 31, nil);
		MSt(moveStack, 1, from, 33, nil);
		MSt(moveStack, 1, from, 14, nil);
		MSt(moveStack, 1, from, -14, nil);
		MSt(moveStack, 1, from, -31, nil);
		MSt(moveStack, 1, from, -33, nil);
		MSt(moveStack, 1, from, 18, nil);
		MSt(moveStack, 1, from, -18, nil);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- Bishop quiet moves
	pieceIdx = bit.lshift( bit.bor(g_toMove, 3), 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 2, from, -15, nil);
		MSt(moveStack, 2, from, -17, nil);
		MSt(moveStack, 2, from, 15, nil);
		MSt(moveStack, 2, from, 17, nil);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- Rook quiet moves
	pieceIdx = bit.lshift( bit.bor(g_toMove, 4), 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 2, from, -1, nil);
		MSt(moveStack, 2, from, 1, nil);
		MSt(moveStack, 2, from, 16, nil);
		MSt(moveStack, 2, from, -16, nil);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- Queen quiet moves
	pieceIdx = bit.lshift( bit.bor(g_toMove, 5), 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 2, from, -15, nil);
		MSt(moveStack, 2, from, -17, nil);
		MSt(moveStack, 2, from, 15, nil);
		MSt(moveStack, 2, from, 17, nil);
		MSt(moveStack, 2, from, -1, nil);
		MSt(moveStack, 2, from, 1, nil);
		MSt(moveStack, 2, from, 16, nil);
		MSt(moveStack, 2, from, -16, nil);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- King quiet moves

		pieceIdx = bit.lshift( bit.bor(g_toMove, 6), 4 );
		from = g_pieceList[1+pieceIdx];
		MSt(moveStack, 1, from, -15, nil);
		MSt(moveStack, 1, from, -17, nil);
		MSt(moveStack, 1, from, 15, nil);
		MSt(moveStack, 1, from, 17, nil);
		MSt(moveStack, 1, from, -1, nil);
		MSt(moveStack, 1, from, 1, nil);
		MSt(moveStack, 1, from, -16, nil);
		MSt(moveStack, 1, from, 16, nil);

        if (not g_inCheck) then
            castleRights = g_castleRights;
            if ( g_toMove == 0 ) then
                castleRights = bit.rshift( castleRights, 2 );
	    end
            if ( bit.band( castleRights, 1 )>0 ) then
                -- Kingside castle
                if (g_board[1+(from + 1)] == pieceEmpty and g_board[1+(from + 2)] == pieceEmpty) then
                    moveStack[1+table.getn(moveStack)] = GenerateMove2(from, from + 0x02, moveflagCastleKing);
                end
            end
            if ( bit.band( castleRights, 2 )>0 ) then
                -- Queenside castle
                if (g_board[1+(from - 1)] == pieceEmpty and g_board[1+(from - 2)] == pieceEmpty and
			 g_board[1+(from - 3)] == pieceEmpty) then
                    moveStack[1+table.getn(moveStack)] = GenerateMove2(from, from - 0x02, moveflagCastleQueen);
                end
            end
        end

end
--

--
function MSt( moveStack, usage, from, dt, enemy )
local to = from + dt;
if( usage == 1 ) then
	if((enemy==nil and g_board[1+to] == 0) or (enemy~=nil and bit.band(g_board[1+to], enemy)>0)) then
		moveStack[1+table.getn(moveStack)] = GenerateMove(from, to);
	end
else
 if( usage == 2 ) then
	while (g_board[1+to] == 0 ) do
		moveStack[1+table.getn(moveStack)] = GenerateMove(from, to);
		to = to + dt;
	end
 else
  if( usage == 3 ) then

	while (g_board[1+to] == 0 ) do
		to = to + dt;

	end

	if (bit.band(g_board[1+to], enemy)>0) then
		moveStack[1+table.getn(moveStack)] = GenerateMove(from, to);
	end

  end
 end
end

end
--

--
function GenerateCaptureMoves(moveStack)
    local from = 0;
    local to = 0;
    local piece = 0;
    local pieceIdx = 0;
    local pawn = 0;
    local inc = iif((g_toMove == 8) , -16 , 16 );
    local enemy = iif(g_toMove == 8 , 0x10 , 0x8 );

    -- Pawn captures
    pieceIdx = bit.lshift( bit.bor(g_toMove, 1) , 4 );
    from = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;
    while (from ~= 0) do
        to = from + inc - 1;
        if ( bit.band(g_board[1+to] , enemy )>0 ) then
            MovePawnTo(moveStack, from, to);
        end

        to = from + inc + 1;
        if ( bit.band( g_board[1+to] , enemy)>0 ) then
            MovePawnTo(moveStack, from, to);
        end

        from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end

    if (g_enPassentSquare ~= -1) then
        inc = iif( (g_toMove == colorWhite), -16 , 16 );
        pawn = bit.bor( g_toMove , piecePawn );

        from = g_enPassentSquare - (inc + 1);

        if (bit.band(g_board[1+from] , 0xF) == pawn) then
            moveStack[1+table.getn(moveStack)] = GenerateMove2(from, g_enPassentSquare, moveflagEPC);
        end

        from = g_enPassentSquare - (inc - 1);
        if (bit.band(g_board[1+from] , 0xF) == pawn) then
            moveStack[1+table.getn(moveStack)] = GenerateMove2(from, g_enPassentSquare, moveflagEPC);
        end
    end

    -- Knight captures
	pieceIdx = bit.lshift( bit.bor(g_toMove , 2) , 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;

	while (from ~= 0) do
		MSt(moveStack, 1, from, 31, enemy);
		MSt(moveStack, 1, from, 33, enemy);
		MSt(moveStack, 1, from, 14, enemy);
		MSt(moveStack, 1, from, -14, enemy);
		MSt(moveStack, 1, from, -31, enemy);
		MSt(moveStack, 1, from, -33, enemy);
		MSt(moveStack, 1, from, 18, enemy);
		MSt(moveStack, 1, from, -18, enemy);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- Bishop captures
	pieceIdx = bit.lshift( bit.bor(g_toMove , 3) , 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;

	while (from ~= 0) do
		MSt(moveStack, 3, from, -15, enemy);
		MSt(moveStack, 3, from, -17, enemy);
		MSt(moveStack, 3, from, 15, enemy);
		MSt(moveStack, 3, from, 17, enemy);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- Rook captures
	pieceIdx = bit.lshift( bit.bor(g_toMove , 4) , 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 3, from, -1, enemy);
		MSt(moveStack, 3, from, 1, enemy);
		MSt(moveStack, 3, from, -16, enemy);
		MSt(moveStack, 3, from, 16, enemy);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end


	-- Queen captures
	pieceIdx = bit.lshift( bit.bor(g_toMove , 5) , 4 );
	from = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
	while (from ~= 0) do
		MSt(moveStack, 3, from, -15, enemy);
		MSt(moveStack, 3, from, -17, enemy);
		MSt(moveStack, 3, from, 15, enemy);
		MSt(moveStack, 3, from, 17, enemy);
		MSt(moveStack, 3, from, -1, enemy);
		MSt(moveStack, 3, from, 1, enemy);
		MSt(moveStack, 3, from, -16, enemy);
		MSt(moveStack, 3, from, 16, enemy);
		from = g_pieceList[1+pieceIdx];
		pieceIdx = pieceIdx + 1;
	end

	-- King captures

		pieceIdx = bit.lshift( bit.bor(g_toMove , 6) , 4 );
		from = g_pieceList[1+pieceIdx];
		MSt(moveStack, 1, from, -15, enemy);
		MSt(moveStack, 1, from, -17, enemy);
		MSt(moveStack, 1, from, 15, enemy);
		MSt(moveStack, 1, from, 17, enemy);
		MSt(moveStack, 1, from, -1, enemy);
		MSt(moveStack, 1, from, 1, enemy);
		MSt(moveStack, 1, from, -16, enemy);
		MSt(moveStack, 1, from, 16, enemy);

end
--

--
function MovePawnTo(moveStack, start, square)
    local row = bit.band( square, 0xF0 );
    if ((row == 0x90) or (row == 0x20)) then
        moveStack[1+table.getn(moveStack)] = GenerateMove2(start, square, bit.bor(moveflagPromotion , moveflagPromoteQueen));
        moveStack[1+table.getn(moveStack)] = GenerateMove2(start, square, bit.bor(moveflagPromotion , moveflagPromoteKnight));
        moveStack[1+table.getn(moveStack)] = GenerateMove2(start, square, bit.bor(moveflagPromotion , moveflagPromoteBishop));
        moveStack[1+table.getn(moveStack)] = GenerateMove2(start, square, moveflagPromotion);

    else
        moveStack[1+table.getn(moveStack)] = GenerateMove2(start, square, 0);
    end
end
--

--
function GeneratePawnMoves(moveStack, from)
    local piece = g_board[1+from];
    local color = bit.band(piece , colorWhite );
    local inc = iif((color == colorWhite) , -16 , 16 );
    local to = from + inc;
	-- Quiet pawn moves

	if (g_board[1+to] == 0) then
		MovePawnTo(moveStack, from, to, pieceEmpty);

		-- Check if we can do a 2 square jump
		if (((bit.band(from, 0xF0) == 0x30) and color ~= colorWhite) or
		    ((bit.band(from, 0xF0) == 0x80) and color == colorWhite)) then
			to = to + inc;
			if (g_board[1+to] == 0) then
				moveStack[1+table.getn(moveStack)] = GenerateMove(from, to);
			end
		end
	end
end
--

--
function See(move)
    local from = bit.band( move , 0xFF );
    local to = bit.band( bit.rshift(move, 8) , 0xFF );

    local fromPiece = g_board[1+from];
    local us = iif( bit.band(fromPiece, colorWhite)>0 , colorWhite , 0 );
    local them = 8 - us;
    local themAttacks = {}		-- new Array();
    local usAttacks = {}		-- new Array();

    local fromValue = g_seeValues[1+ bit.band(fromPiece, 0xF)];
    local toValue = g_seeValues[1+ bit.band(g_board[1+to], 0xF)];
    local seeValue = toValue - fromValue;
    local inc = iif( bit.band(fromPiece , colorWhite)>0 , -16 , 16 );
    local captureDeficit = fromValue - toValue;
    local pieceType = 0;
    local pieceValue = 0;
    local i = 0;
    local capturingPieceSquare = 0;
    local capturingPieceValue = 1000;
    local capturingPieceIndex = -1;

    if (fromValue <= toValue) then
        return true;
    end

    if ( bit.rshift(move, 16)>0 ) then
        -- Castles, promotion, ep are always good
        return true;
    end


    -- Pawn attacks
    -- If any opponent pawns can capture back, this capture is probably not worthwhile (as we must be using knight or above).
    		 -- Note: this is capture direction from to, so reversed from normal move direction
    if ((bit.band(g_board[1+ (to + inc + 1)] , 0xF) == bit.bor(piecePawn , them)) or
        (bit.band(g_board[1+ (to + inc - 1)] , 0xF) == bit.bor(piecePawn , them))) then
        return false;
    end



    -- Knight attacks
    -- If any opponent knights can capture back, and the deficit we have to make up is greater than the knights value,
    -- it's not worth it.  We can capture on this square again, and the opponent doesn't have to capture back.

    SeeAddKnightAttacks(to, them, themAttacks);
    if ((table.getn(themAttacks) ~= 0) and (captureDeficit > g_seeValues[1+pieceKnight])) then
        return false;
    end

    -- Slider attacks
    g_board[1+from] = 0;
    for pieceType = pieceBishop, pieceQueen, 1 do
        if (SeeAddSliderAttacks(to, them, themAttacks, pieceType)) then
            if (captureDeficit > g_seeValues[1+pieceType]) then
                g_board[1+from] = fromPiece;
                return false;
            end
        end
    end

    -- Pawn defenses
    -- At this point, we are sure we are making a "losing" capture.  The opponent can not capture back with a
    -- pawn.  They cannot capture back with a minor/major and stand pat either.  So, if we can capture with
    -- a pawn, it's got to be a winning or equal capture.
    if ((bit.band(g_board[1+(to - inc + 1)] , 0xF) == bit.bor(piecePawn , us)) or
        (bit.band(g_board[1+(to - inc - 1)] , 0xF) == bit.bor(piecePawn , us))) then
        g_board[1+from] = fromPiece;
        return true;
    end

    -- King attacks
    SeeAddSliderAttacks(to, them, themAttacks, pieceKing);

    -- Our attacks
    SeeAddKnightAttacks(to, us, usAttacks);
    for pieceType = pieceBishop, pieceKing, 1 do
        SeeAddSliderAttacks(to, us, usAttacks, pieceType);
    end

    g_board[1+from] = fromPiece;

    -- We are currently winning the amount of material of the captured piece, time to see if the opponent
    -- can get it back somehow.  We assume the opponent can capture our current piece in this score, which
    -- simplifies the later code considerably.

    while (true) do
        capturingPieceValue = 1000;
        capturingPieceIndex = -1;

        -- Find the least valuable piece of the opponent that can attack the square
        for i = 0, table.getn(themAttacks)-1, 1 do
            if (themAttacks[1+i] ~= 0) then
                pieceValue = g_seeValues[1+ bit.band(g_board[1+themAttacks[1+i]] , 0x7)];
                if (pieceValue < capturingPieceValue) then
                    capturingPieceValue = pieceValue;
                    capturingPieceIndex = i;
                end
            end
        end

        if (capturingPieceIndex == -1) then
            -- Opponent can't capture back, we win
            return true;
        end

        -- Now, if seeValue < 0, the opponent is winning.  If even after we take their piece,
        -- we can't bring it back to 0, then we have lost this battle.
        seeValue = seeValue + capturingPieceValue;
        if (seeValue < 0) then
            return false;
        end

        capturingPieceSquare = themAttacks[1+capturingPieceIndex];
        themAttacks[1+capturingPieceIndex] = 0;

        -- Add any x-ray attackers
        SeeAddXrayAttack(to, capturingPieceSquare, us, usAttacks, themAttacks);

        -- Our turn to capture
        capturingPieceValue = 1000;
        capturingPieceIndex = -1;

        -- Find our least valuable piece that can attack the square
        for i = 0, table.getn(usAttacks)-1, 1 do
            if (usAttacks[1+i] ~= 0) then
                pieceValue = g_seeValues[1+ bit.band( g_board[1+usAttacks[1+i]] , 0x7 )];
                if (pieceValue < capturingPieceValue) then
                    capturingPieceValue = pieceValue;
                    capturingPieceIndex = i;
                end
            end
        end

        if (capturingPieceIndex == -1) then
            -- We can't capture back, we lose :(
            return false;
        end

        -- Assume our opponent can capture us back, and if we are still winning, we can stand-pat
        -- here, and assume we've won.
        seeValue = seeValue - capturingPieceValue;
        if (seeValue >= 0) then
            return true;
        end

        capturingPieceSquare = usAttacks[1+capturingPieceIndex];
        usAttacks[1+capturingPieceIndex] = 0;

        -- Add any x-ray attackers
        SeeAddXrayAttack(to, capturingPieceSquare, us, usAttacks, themAttacks);
    end
end
--

--
function SeeAddXrayAttack(target, square, us, usAttacks, themAttacks)
    local index = square - target + 128;
    local delta = -g_vectorDelta[1+index].delta;
    if (delta == 0) then
        return;
    end
    square = square + delta;
    while (g_board[1+square] == 0) do
        square = square + delta;
    end

    if ((bit.band(g_board[1+square] , 0x18)>0) and IsSquareOnPieceLine(target, square)) then
        if (bit.band(g_board[1+square] , 8) == us) then
            usAttacks[1+table.getn(usAttacks)] = square;
        else
            themAttacks[1+table.getn(themAttacks)] = square;
        end
    end
end
--

-- target = attacking square, us = color of knights to look for, attacks = array to add squares to
function SeeAddKnightAttacks(target, us, attacks)
    local pieceIdx = bit.lshift( bit.bor(us , pieceKnight) , 4 );
    local attackerSq = g_pieceList[1+pieceIdx];
    pieceIdx = pieceIdx + 1;

    while (attackerSq ~= 0) do
        if (IsSquareOnPieceLine(target, attackerSq)) then
            attacks[1+table.getn(attacks)] = attackerSq;
        end
        attackerSq = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end
end
--

--
function SeeAddSliderAttacks(target, us, attacks, pieceType)
    local pieceIdx = bit.lshift( bit.bor(us, pieceType) , 4 );
    local attackerSq = g_pieceList[1+pieceIdx];

    local hit = false;
    pieceIdx = pieceIdx + 1;

    while (attackerSq ~= 0) do
        if (IsSquareAttackableFrom(target, attackerSq)) then
            attacks[1+table.getn(attacks)] = attackerSq;
            hit = true;
        end
        attackerSq = g_pieceList[1+pieceIdx];
	pieceIdx = pieceIdx + 1;
    end

    return hit;
end
--

--
function FormatMove(move)
    local result = FormatSquare(bit.band(move, 0xFF)) .. FormatSquare(bit.band( bit.rshift(move, 8), 0xFF));
    if (bit.band(move, moveflagPromotion)>0) then
        if ( bit.band( move, moveflagPromoteBishop )>0 ) then
		result = result .. "b";
        else
	 if ( bit.band( move, moveflagPromoteKnight )>0 ) then
		result = result .. "n";
         else
	   if ( bit.band(move, moveflagPromoteQueen)>0 ) then
		result = result .. "q";
           else
		result = result .. "r";
	   end
	 end
	end
    end
    return result;
end
--

--
function GetMoveFromString(moveString)
    local i = 0;
    local moves = GenerateValidMoves();
    for i = 0, table.getn(moves)-1, 1 do
        if (FormatMove(moves[1+i]) == moveString) then
            return moves[1+i];
        end
    end
    print("busted! ->" .. moveString .. " fen:" + GetFen());
end
--

--
function PVFromHash(move, ply)
    local pvString = "";
    local hashNode = 0;

    if(ply ~= 0) then

      pvString = " " .. GetMoveSAN(move);
      MakeMove(move);

      hashNode = g_hashTable[1+ bit.band(g_hashKeyLow, g_hashMask)];
      if ((hashNode ~= nil) and (hashNode.lock == g_hashKeyHigh) and (hashNode.bestMove ~= nil)) then
        pvString = pvString .. PVFromHash(hashNode.bestMove, ply - 1);
      end

      UnmakeMove(move);
    end
    return pvString;
end
--

-- To display
function BuildPVMessage(bestMove, value, ply)

    local totalNodes = g_nodeCount + g_qNodeCount;
    return "Ply:" .. ply .. " Score:" .. string.format("%d", value ) ..
	" Nodes:" .. string.format("%d", totalNodes ) .. " " .. PVFromHash(bestMove, 15);
end
--

-- Called on Ply finish
function finishPlyCallback(bestMove, value, ply)
    if (bestMove ~= nil and bestMove ~= 0) then
        print(BuildPVMessage(bestMove, value, ply));
    end
end
--

-- Called on Move ready to answer
function finishMoveCallback(bestMove, value, ply)
    if (bestMove ~= nil and bestMove ~= 0) then
        MakeMove(bestMove);
        print(FormatMove(bestMove));

        g_foundmove = bestMove;
    end
end
--

-- Produces a chess game   Lua vs Lua
function autogame()

local mv=0;
local col=-1;

 while(true) do

	col = -col;
	if(col>0) then
	  mv = mv + 1;
	  print( "Move: " .. string.format("%d",mv) .. ". ");
	end

	Search(8);

	if(g_foundmove == 0) then
		break;
	end
 end

end

--
--
-- Here we start
--
InitializeEval();

ResetGame();

InitializeFromFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

autogame();