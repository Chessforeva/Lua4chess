--
-- Fruit 2.1 chess engine by Fabien Letouzey, 2004-2005.
-- At http://www.fruitchess.com,  http://wbec-ridderkerk.nl/
--
-- Port to Lua language by http://chessforeva.blogspot.com, 2011
-- 
-- Lua is a scripting language, this means: not a strong chess
-- But this is a smart AI anyway.
--
-- There is no opening book. lua library for chess openings is available at
-- Chessforeva's site. Or develop it.
--
-- Samples and all the usage is obvious down at the end.
-- Free usage and much thanks to Fabien!
--

require "bit";

-- colour.h

-- constants

 UseMcache = true;      -- to use files for faster performance (saves some memory variables),
                        -- set "false" for normal lua, needed for very slow lua case
 TRUE = 1;
 FALSE = 0;

 UseTable = true;   -- const bool
 MaterialTableSize = 64 * 1024;         -- const size of Material hashing (array elements to use)
 PawnTableSize = 64 * 1024;             -- const size of Pawn hashing (array elements to use)

 UseTrans = true;   -- const bool
 TransSize = 64 * 1024;                 -- const size of transp-table (array elements to use)
   -- it is not a memory hash size, because there is no memory allocation at all

 bestmv = "";      -- string contains best move
 bestmv2 = "";     -- string contains pgn-format of the move

 ShowInfo = false;  -- set true to show thinking!

 iDbg01 = false;  -- internal for debugging

 ColourNone = -1; -- const int
 White = 0;       -- const int
 Black = 1;       -- const int
 ColourNb = 2;    -- const int

 WhiteFlag = bit.lshift(1,White);   -- const int
 BlackFlag = bit.lshift(1,Black);   -- const int
 WxorB = bit.bxor(White,Black);
 bnot1 = bit.bnot(1);
 bnot3 = bit.bnot(3);
 bnotF = bit.bnot(0xF);

 V07777 = 4095;                     -- const int
 bnotV07777 = bit.bnot( V07777 );   -- const int
 bnotV77 = bit.bnot(0x77);          -- const int

-- should be true, or error otherwise

function ASSERT(id,logic)
 if( not logic ) then
   print("ASSERT FAIL on id=" .. string.format("%d",id));
 end
end


-- (if ? then : else) substitute

function iif(ask, ontrue, onfalse)
 if( ask ) then
  return ontrue;
 end
 return onfalse;
end

-- convert bytes (little endian) to a 32-bit two's complement integer (not used)
function bytes_to_int(b1, b2, b3, b4)
 if(b3==nil) then
   b3 = 0;
 end
 if(b4==nil) then
   b4 = 0;
 end
 local n = b1 + (b2*256) + (b3*65536) + (b4*16777216);
 if(n > 2147483647) then
   return (n - 4294967296);
 end
 return n;
end


-- constructor to provide string as a parm
function string_t()
 local b = {};
 b.v = "";
 return b;
end
-- constructor to provide int as a parm
function int_t ()
  local b = {};
  b.v = 0;
  return b;
end

-- my_fatal()

function my_fatal( errmess )  -- for error case
   print( "my-error: "..errmess );
end

function COLOUR_IS_OK(colour)
 return (bit.band(colour,bnot1)==0);
end

function COLOUR_IS_WHITE(colour)
 return (colour==White);
end

function COLOUR_IS_BLACK(colour)
 return (colour~=White);
end

function COLOUR_FLAG(colour)
 return (colour+1);
end

function COLOUR_IS(piece,colour)
 return (FLAG_IS(piece,colour+1));
end

function FLAG_IS(piece,flag)
 return (bit.band(piece,flag)~=0);
end

function COLOUR_OPP(colour)
 return bit.bxor(colour,WxorB);
end

-- end of colour.h


-- piece.h

-- constants

 WhitePawnFlag = bit.lshift(1,2);   -- const int
 BlackPawnFlag = bit.lshift(1,3);   -- const int
 KnightFlag    = bit.lshift(1,4);   -- const int
 BishopFlag    = bit.lshift(1,5);   -- const int
 RookFlag      = bit.lshift(1,6);   -- const int
 KingFlag      = bit.lshift(1,7);   -- const int

 PawnFlags  = bit.bor(WhitePawnFlag, BlackPawnFlag);   -- const int
 QueenFlags = bit.bor(BishopFlag, RookFlag);          -- const int

 PieceNone64 = 0; -- const int
 WhitePawn64 = WhitePawnFlag;  -- const int
 BlackPawn64 = BlackPawnFlag;  -- const int
 Knight64    = KnightFlag;     -- const int
 Bishop64    = BishopFlag;     -- const int
 Rook64      = RookFlag;       -- const int
 Queen64     = QueenFlags;     -- const int
 King64      = KingFlag;       -- const int

 PieceNone256   = 0; -- const int
 WhitePawn256   =  bit.bor(WhitePawn64,WhiteFlag);  -- const int
 BlackPawn256   =  bit.bor(BlackPawn64,BlackFlag);  -- const int
 WhiteKnight256 =  bit.bor(Knight64,WhiteFlag);     -- const int
 BlackKnight256 =  bit.bor(Knight64,BlackFlag);     -- const int
 WhiteBishop256 =  bit.bor(Bishop64,WhiteFlag);     -- const int
 BlackBishop256 =  bit.bor(Bishop64,BlackFlag);     -- const int
 WhiteRook256   =  bit.bor(Rook64,WhiteFlag);       -- const int
 BlackRook256   =  bit.bor(Rook64,BlackFlag);       -- const int
 WhiteQueen256  =  bit.bor(Queen64,WhiteFlag);      -- const int
 BlackQueen256  =  bit.bor(Queen64,BlackFlag);      -- const int
 WhiteKing256   =  bit.bor(King64,WhiteFlag);       -- const int
 BlackKing256   =  bit.bor(King64,BlackFlag);       -- const int
 PieceNb        = 256; -- const int

 WhitePawn12   =  0; -- const int
 BlackPawn12   =  1; -- const int
 WhiteKnight12 =  2; -- const int
 BlackKnight12 =  3; -- const int
 WhiteBishop12 =  4; -- const int
 BlackBishop12 =  5; -- const int
 WhiteRook12   =  6; -- const int
 BlackRook12   =  7; -- const int
 WhiteQueen12  =  8; -- const int
 BlackQueen12  =  9; -- const int
 WhiteKing12   = 10; -- const int
 BlackKing12   = 11; -- const int

-- "constants"

 PawnMake = { WhitePawn256, BlackPawn256 };   -- const int[ColourNb]

 PieceFrom12 = {  WhitePawn256, BlackPawn256, WhiteKnight256, BlackKnight256,
   WhiteBishop256, BlackBishop256, WhiteRook256, BlackRook256,
   WhiteQueen256,  BlackQueen256, WhiteKing256, BlackKing256 };  -- const int[12]

 PieceString = "PpNnBbRrQqKk";   -- const char[12+1]

 PawnMoveInc = { 16, -16 };  -- const int[ColourNb]

 KnightInc = { -33, -31, -18, -14, 14, 18, 31, 33, 0 };  -- const int[8+1]

 BishopInc = { -17, -15, 15, 17, 0 };  -- const int[4+1]

 RookInc = { -16, -1, 1, 16, 0 };  -- const int[4+1]

 QueenInc = { -17, -16, -15, -1, 1, 15, 16, 17, 0 };  -- const[8+1]

 KingInc = { -17, -16, -15, -1, 1, 15, 16, 17, 0 };  -- const[8+1]


-- variables

 PieceTo12 = {};    -- int[PieceNb]
 PieceOrder = {};   -- int[PieceNb]
 PieceInc = {};     -- const

-- macros

function PAWN_OPP(pawn)
 return bit.bxor(pawn,bit.bxor(WhitePawn256,BlackPawn256));
end

function PIECE_COLOUR(piece)
 return (bit.band(piece,3)-1);
end

function PIECE_TYPE(piece)
 return bit.band(piece,bnot3);
end

function PIECE_IS_PAWN(piece)
 return (bit.band(piece,PawnFlags)~=0);
end

function PIECE_IS_KNIGHT(piece)
 return (bit.band(piece,KnightFlag)~=0);
end

function PIECE_IS_BISHOP(piece)
 return (bit.band(piece,QueenFlags)==BishopFlag);
end

function PIECE_IS_ROOK(piece)
 return (bit.band(piece,QueenFlags)==RookFlag);
end

function PIECE_IS_QUEEN(piece)
 return (bit.band(piece,QueenFlags)==QueenFlags);
end

function PIECE_IS_KING(piece)
 return (bit.band(piece,KingFlag)~=0);
end

function PIECE_IS_SLIDER(piece)
 return (bit.band(piece,QueenFlags)~=0);
end


-- end of piece.h



-- square.h


-- constants

 FileNb = 16;   -- const int
 RankNb = 16;   -- const int

 SquareNb = FileNb*RankNb;   -- const int

 FileInc = 1;   -- const int
 RankInc = 16;  -- const int

 FileNone = 0;   -- const int

 FileA = 0x4;   -- const int
 FileB = 0x5;   -- const int
 FileC = 0x6;   -- const int
 FileD = 0x7;   -- const int
 FileE = 0x8;   -- const int
 FileF = 0x9;   -- const int
 FileG = 0xA;   -- const int
 FileH = 0xB;   -- const int

 RankNone = 0;   -- const int

 Rank1 = 0x4;   -- const int
 Rank2 = 0x5;   -- const int
 Rank3 = 0x6;   -- const int
 Rank4 = 0x7;   -- const int
 Rank5 = 0x8;   -- const int
 Rank6 = 0x9;   -- const int
 Rank7 = 0xA;   -- const int
 Rank8 = 0xB;   -- const int

 SquareNone = 0;   -- const int

 A1=0x44; B1=0x45; C1=0x46; D1=0x47; E1=0x48; F1=0x49; G1=0x4A; H1=0x4B;   -- const int
 A2=0x54; B2=0x55; C2=0x56; D2=0x57; E2=0x58; F2=0x59; G2=0x5A; H2=0x5B;   -- const int
 A3=0x64; B3=0x65; C3=0x66; D3=0x67; E3=0x68; F3=0x69; G3=0x6A; H3=0x6B;   -- const int
 A4=0x74; B4=0x75; C4=0x76; D4=0x77; E4=0x78; F4=0x79; G4=0x7A; H4=0x7B;   -- const int
 A5=0x84; B5=0x85; C5=0x86; D5=0x87; E5=0x88; F5=0x89; G5=0x8A; H5=0x8B;   -- const int
 A6=0x94; B6=0x95; C6=0x96; D6=0x97; E6=0x98; F6=0x99; G6=0x9A; H6=0x9B;   -- const int
 A7=0xA4; B7=0xA5; C7=0xA6; D7=0xA7; E7=0xA8; F7=0xA9; G7=0xAA; H7=0xAB;   -- const int
 A8=0xB4; B8=0xB5; C8=0xB6; D8=0xB7; E8=0xB8; F8=0xB9; G8=0xBA; H8=0xBB;   -- const int

 Dark  = 0;   -- const int
 Light = 1;   -- const int

-- variables

 SquareTo64 = {};        -- int[SquareNb]
 SquareIsPromote = {};   -- bool[SquareNb]


-- "constants"

  SquareFrom64 = {
   A1, B1, C1, D1, E1, F1, G1, H1,
   A2, B2, C2, D2, E2, F2, G2, H2,
   A3, B3, C3, D3, E3, F3, G3, H3,
   A4, B4, C4, D4, E4, F4, G4, H4,
   A5, B5, C5, D5, E5, F5, G5, H5,
   A6, B6, C6, D6, E6, F6, G6, H6,
   A7, B7, C7, D7, E7, F7, G7, H7,
   A8, B8, C8, D8, E8, F8, G8, H8,
};   -- const int[64]

  RankMask = { 0, 0xF };          -- const int[ColourNb]
  PromoteRank = { 0xB0, 0x40 };   -- const int[ColourNb]

-- macros

function SQUARE_IS_OK(square)
 return (bit.band(square-0x44,bnotV77)==0);
end

function SQUARE_MAKE(file,rank)
 return bit.bor(bit.lshift(rank,4),file);
end

function SQUARE_FILE(square)
 return bit.band(square,0xF);
end

function SQUARE_RANK(square)
 return bit.rshift(square,4);
end

function SQUARE_EP_DUAL(square)
 return bit.bxor(square,16);
end

function SQUARE_COLOUR(square)
 return bit.band( bit.bxor(square,bit.rshift(square,4)),1);
end

function SQUARE_FILE_MIRROR(square)
 return bit.bxor(square,0x0F);
end

function SQUARE_RANK_MIRROR(square)
 return bit.bxor(square,0xF0);
end

function FILE_OPP(file)
 return bit.bxor(file,0xF);
end

function RANK_OPP(rank)
 return bit.bxor(rank,0xF);
end

function PAWN_RANK(square,colour)
 return bit.bxor(SQUARE_RANK(square),RankMask[1+colour]);
end

function PAWN_PROMOTE(square,colour)
 return bit.bor(PromoteRank[1+colour],bit.band(square,0xF));
end


-- end of square.h


-- board.h

-- constants

 Empty = 0;       -- const int
 Edge = Knight64; -- const int   HACK: uncoloured knight

 WP = WhitePawn256;   -- const int
 WN = WhiteKnight256; -- const int
 WB = WhiteBishop256; -- const int
 WR = WhiteRook256;   -- const int
 WQ = WhiteQueen256;  -- const int
 WK = WhiteKing256;   -- const int

 BP = BlackPawn256;   -- const int
 BN = BlackKnight256; -- const int
 BB = BlackBishop256; -- const int
 BR = BlackRook256;   -- const int
 BQ = BlackQueen256;  -- const int
 BK = BlackKing256;   -- const int

 FlagsNone = 0;   -- const int
 FlagsWhiteKingCastle  = bit.lshift(1,0) ;   -- const int
 FlagsWhiteQueenCastle = bit.lshift(1,1) ;   -- const int
 FlagsBlackKingCastle  = bit.lshift(1,2) ;   -- const int
 FlagsBlackQueenCastle = bit.lshift(1,3) ;   -- const int

 StackSize = 4096; -- const int

-- macros

function KING_POS(board,colour)
 return board.piece[1+colour][1+0];
end

-- types

function board_t ()
   local b = {};
   b.square = { 0, 0 };  -- int[SquareNb]
   b.pos = { 0, 0 };     -- int[SquareNb]

   b.piece = {};   -- int[ColourNb][32] only 17 are needed
   b.piece[1+0] = {0};
   b.piece[1+1] = {0};

   b.piece_size = { 0, 0 };  -- int[ColourNb]

   b.pawn = {};       -- int[ColourNb][16] only 9 are needed
   b.pawn[1+0] = {0};
   b.pawn[1+1] = {0};

   b.pawn_size = { 0, 0 };  -- int[ColourNb]

   b.piece_nb = 0;   -- int
   b.number = {};    -- int[16] only 12 are needed

   b.pawn_file = {}; -- int[ColourNb][FileNb];
   b.pawn_file[1+0] = {0};
   b.pawn_file[1+1] = {0};

   b.turn = 0;       -- int
   b.flags = 0;      -- int
   b.ep_square = 0;  -- int
   b.ply_nb = 0;     -- int
   b.sp = 0;         -- int  TODO: MOVE ME?

   b.cap_sq = 0;     -- int

   b.opening = 0;    -- int
   b.endgame = 0;    -- int

   b.key = 0;           -- uint64
   b.pawn_key = 0;      -- uint64
   b.material_key = 0;  -- uint64

   b.stack = {0};        -- uint64[StackSize];
   b.movenumb = 0;     -- int
   return b;
end


-- end of board.h


-- move.h

-- constants

 MoveNone = 0;  -- const int   HACK: a1a1 cannot be a legal move
 Movenil = 11; -- const int   HACK: a1d2 cannot be a legal move

 MoveNormal    =  bit.lshift(0,14);   -- const int
 MoveCastle    =  bit.lshift(1,14);   -- const int
 MovePromote   =  bit.lshift(2,14);   -- const int
 MoveEnPassant =  bit.lshift(3,14);   -- const int
 MoveFlags     =  bit.lshift(3,14);   -- const int

 MovePromoteKnight =  bit.bor(MovePromote,bit.lshift(0,12));   -- const int
 MovePromoteBishop =  bit.bor(MovePromote,bit.lshift(1,12));   -- const int
 MovePromoteRook   =  bit.bor(MovePromote,bit.lshift(2,12));   -- const int
 MovePromoteQueen  =  bit.bor(MovePromote,bit.lshift(3,12));   -- const int

 MoveAllFlags = bit.lshift(0xF,12);   -- const int

 nilMoveString = "nil"; -- const char[] "0000" in UCI

 PromotePiece = { Knight64, Bishop64, Rook64, Queen64 };   -- int[4]

-- macros

function MOVE_MAKE(from,to)
 return bit.bor( bit.lshift(SquareTo64[1+from],6) , SquareTo64[1+to]);
end

function MOVE_MAKE_FLAGS(from,to,flags)  return bit.bor( bit.lshift(SquareTo64[1+from],6), bit.bor(SquareTo64[1+to],flags));
end

function MOVE_FROM(move)
 return SquareFrom64[1+ bit.band(bit.rshift(move,6), 63)];
end

function MOVE_TO(move)
 return SquareFrom64[1+ bit.band(move, 63)];
end

function MOVE_IS_SPECIAL(move)
 return ( bit.band(move,MoveFlags)~=MoveNormal );
end

function MOVE_IS_PROMOTE(move)
 return ( bit.band(move,MoveFlags)==MovePromote );
end

function MOVE_IS_EN_PASSANT(move)
 return ( bit.band(move,MoveFlags)==MoveEnPassant );
end

function MOVE_IS_CASTLE(move)
 return ( bit.band(move,MoveFlags)==MoveCastle );
end

function MOVE_PIECE(move,board)
 return ((board).square[1+MOVE_FROM(move)]);
end


-- end of move.h



-- attack.h

-- types
function attack_t ()
   local b = {};
   b.dn = 0;   -- int
   b.ds = {};  -- int[2+1]
   b.di = {};  -- int[2+1]
   return b;
end


-- variables

  DeltaIncLine = {};      -- int[DeltaNb]
  DeltaIncAll = {};       -- int[DeltaNb]

  DeltaMask = {};         -- int[DeltaNb]
  IncMask = {};           -- int[IncNb]

  PieceCode = {};         -- int[PieceNb]
  PieceDeltaSize = {};    -- int[4][256]      4kB
  PieceDeltaDelta = {};   -- int[4][256][4]  16kB


-- macros

function IS_IN_CHECK(board,colour)
 return is_attacked(board,KING_POS(board,colour),COLOUR_OPP(colour));
end

function DELTA_INC_LINE(delta)
 return DeltaIncLine[1+DeltaOffset+delta];
end

function DELTA_INC_ALL(delta)
 return DeltaIncAll[1+DeltaOffset+delta];
end

function DELTA_MASK(delta)
 return DeltaMask[1+DeltaOffset+delta];
end

function INC_MASK(inc)
 return IncMask[1+IncOffset+inc];
end

function PSEUDO_ATTACK(piece,delta)
 return (bit.band(piece,DELTA_MASK(delta))~=0);
end

function PIECE_ATTACK(board,piece,from,to)
 return PSEUDO_ATTACK(piece,to-from) and line_is_empty(board,from,to);
end


function SLIDER_ATTACK(piece,inc)
 return (bit.band(piece,INC_MASK(inc))~=0);
end

function ATTACK_IN_CHECK(attack)
 return (attack.dn~=0);
end


-- end of attack.h


-- trans.h

-- constants

  UseModulo = false;        -- const bool
  DateSize = 16;            -- const int
  DepthNone = -128;         -- const int
  ClusterSize = 4;          -- const int, not a hash size

-- types

function entry_t()
   local b = {};
   b.lock = 0;        -- uint32
   b.move = 0;        -- uint16
   b.depth = 0;       -- sint8
   b.date = 0;        -- uint8
   b.move_depth = 0;  -- sint8
   b.flags = 0;       -- uint8
   b.min_depth = 0;   -- sint8
   b.max_depth = 0;   -- sint8
   b.min_value = 0;   -- sint16
   b.max_value = 0;   -- sint16
   return b;
end


function trans_t ()
   local b = {};
   b.table = {};           -- entry_t*
   b.size = 0;             -- uint32
   b.mask = 0;             -- uint32
   b.date = 0;             -- int
   b.age = {};             -- int[DateSize]
   b.used = 0;             -- uint32
   b.read_nb = 0;          -- sint64
   b.read_hit = 0;         -- sint64
   b.write_nb = 0;         -- sint64
   b.write_hit = 0;        -- sint64
   b.write_collision = 0;  -- sint64
   return b;
end


function trans_rtrv()
   local b = {};
   b.trans_move = 0;        -- int
   b.trans_min_depth = 0;   -- int
   b.trans_max_depth = 0;   -- int
   b.trans_min_value = 0;   -- int
   b.trans_max_value = 0;   -- int
   return b;
end

-- variables

 Trans = trans_t ();      -- trans_t [1]
 TransRv = trans_rtrv();  -- retriever

-- end of trans.h




-- hash.h

-- macros

function uint32(i)
 return bit.band(i, 0xFFFFFFFF);
end

function KEY_INDEX(key)
 return uint32(key);
end

function KEY_LOCK(key)          -- no 64 bits, so, we use the original key
 return key;                    -- uint32(bit.rshift(key,32));
end

-- constants

 RandomPiece     =   0; -- 12 * 64   const int
 RandomCastle    = 768; -- 4         const int
 RandomEnPassant = 772; -- 8         const int
 RandomTurn      = 780; -- 1         const int


-- end of hash.h


-- list.h

-- constants

 ListSize = 256;   -- const int

 UseStrict = true;   -- const bool

-- types

function list_t ()
   local b = {};
   b.size = 0;    -- int
   b.move = {};	  -- int[ListSize]
   b.value = {};  -- short int[ListSize]
   return b;
end

function alist_t ()
   local b = {};
   b.size = 0;       -- int
   b.square = {};    -- int[15]
   return b;
end

function alists_t ()
   local b = {};
   b.alist = {};             --alist_t [ColourNb][1]
   b.alist[1+0] = alist_t ();
   b.alist[1+1] = alist_t ();
   return b;
end


-- macros

function LIST_ADD(list,mv)
 list.move[1+list.size]=mv;
 list.size = list.size + 1;
end

function LIST_CLEAR(list)
 list.move = {};
 list.size = 0;
end


-- end of list.h


-- material.h

-- constants

   MAT_NONE = 0; MAT_KK = 1; MAT_KBK = 2; MAT_KKB = 3; MAT_KNK = 4; MAT_KKN = 5;
   MAT_KPK = 6; MAT_KKP = 7; MAT_KQKQ = 8; MAT_KQKP = 9; MAT_KPKQ = 10;
   MAT_KRKR = 11; MAT_KRKP = 12; MAT_KPKR = 13; MAT_KBKB = 14; MAT_KBKP = 15;
   MAT_KPKB = 16; MAT_KBPK = 17; MAT_KKBP = 18; MAT_KNKN = 19; MAT_KNKP = 20;
   MAT_KPKN = 21; MAT_KNPK = 22; MAT_KKNP = 23; MAT_KRPKR = 24; MAT_KRKRP = 25;
   MAT_KBPKB = 26; MAT_KBKBP = 27; MAT_NB = 28;

 DrawNodeFlag    =  bit.lshift(1,0);  -- const int
 DrawBishopFlag  =  bit.lshift(1,1);  -- const int
 MatRookPawnFlag =  bit.lshift(1,0);  -- const int
 MatBishopFlag   =  bit.lshift(1,1);  -- const int
 MatKnightFlag   =  bit.lshift(1,2);  -- const int
 MatKingFlag     =  bit.lshift(1,3);  -- const int


-- constants

  PawnPhase   = 0;   -- const int
  KnightPhase = 1;   -- const int
  BishopPhase = 1;   -- const int
  RookPhase   = 2;   -- const int
  QueenPhase  = 4;   -- const int
  TotalPhase = (PawnPhase * 16) + (KnightPhase * 4) +
               (BishopPhase * 4) + RookPhase * 4 + (QueenPhase * 2);   -- const int

-- constants and variables

  MaterialWeight = 256; -- 100% const int

  PawnOpening   = 80;    -- was 100 const int
  PawnEndgame   = 90;    -- was 100 const int
  KnightOpening = 325;   -- const int
  KnightEndgame = 325;   -- const int
  BishopOpening = 325;   -- const int
  BishopEndgame = 325;   -- const int
  RookOpening   = 500;   -- const int
  RookEndgame   = 500;   -- const int
  QueenOpening  = 1000;  -- const int
  QueenEndgame  = 1000;  -- const int

  BishopPairOpening = 50;   -- const int
  BishopPairEndgame = 50;   -- const int

-- types

function material_info_t ()
   local b = {};
   b.lock = 0;	        -- uint32
   b.recog = 0;         -- uint8
   b.flags = 0;         -- uint8
   b.cflags = { 0, 0 }; -- uint8[ColourNb]
   b.mul = { 0, 0 };    -- uint8[ColourNb]
   b.phase = 0;         -- sint16
   b.opening = 0;       -- sint16
   b.endgame = 0;       -- sint16
   return b;
end

function material_t ()
   local b = {};
   b.table = {};         -- entry_t*
   b.size = 0;           -- uint32
   b.mask = 0;           -- uint32
   b.used = 0;           -- uint32

   b.read_nb = 0;          -- sint64
   b.read_hit = 0;         -- sint64
   b.write_nb = 0;         -- sint64
   b.write_collision = 0;  -- sint64
   return b;
end

-- variables

  Material = material_t();   -- material_t[1]

-- material_info_copy ()

function material_info_copy ( dst, src )

   dst.lock = src.lock;
   dst.recog = src.recog;

   dst.cflags[1+0] = src.cflags[1+0];
   dst.cflags[1+1] = src.cflags[1+1];

   dst.mul[1+0] = src.mul[1+0];
   dst.mul[1+1] = src.mul[1+1];

   dst.phase = src.phase;
   dst.opening = src.opening;
   dst.endgame = src.endgame;

   dst.flags = src.flags;

end


-- end of material.h



-- move_do.h


-- types

function undo_t ()
   local b = {};
   b.capture = false;   -- bool

   b.capture_square = 0;  -- int
   b.capture_piece = 0;   -- int
   b.capture_pos = 0;     -- int

   b.pawn_pos = 0;        -- int

   b.turn = 0;      -- int
   b.flags = 0;     -- int
   b.ep_square = 0; -- int
   b.ply_nb = 0;    -- int

   b.cap_sq = 0;    -- int

   b.opening = 0;   -- int
   b.endgame = 0;   -- int

   b.key = 0;           -- uint64
   b.pawn_key = 0;      -- uint64
   b.material_key = 0;  -- uint64

   return b;
end

-- variables

  CastleMask = {};   -- int[SquareNb]

-- end of move_do.h



-- pawn.h


-- constants

  BackRankFlag =  bit.lshift(1,0);   -- const int

-- types


function pawn_t ()
   local b = {};
   b.table = {};        -- entry_t*
   b.size = 0;           -- uint32
   b.mask = 0;           -- uint32
   b.used = 0;           -- uint32

   b.read_nb = 0;          -- sint64
   b.read_hit = 0;         -- sint64
   b.write_nb = 0;         -- sint64
   b.write_collision = 0;  -- sint64
   return b;
end

function pawn_info_t ()
   local b = {};
   b.lock = 0;                -- uint32
   b.opening = 0;             -- sint16
   b.endgame = 0;             -- sint16
   b.flags = { 0, 0 };        -- uint8[ColourNb]
   b.passed_bits = { 0, 0 };  -- uint8[ColourNb]
   b.single_file = { 0, 0 };  -- uint8[ColourNb]
   b.pad = 0;                 -- uint16
   return b;
end

-- pawn_info_copy ()

function pawn_info_copy ( dst, src )
   dst.lock = src.lock;
   dst.opening = src.opening;
   dst.endgame = src.endgame;
   dst.flags[1+0] = src.flags[1+0];
   dst.flags[1+1] = src.flags[1+1];
   dst.passed_bits[1+0] = src.passed_bits[1+0];
   dst.passed_bits[1+1] = src.passed_bits[1+1];
   dst.single_file[1+0] = src.single_file[1+0];
   dst.single_file[1+1] = src.single_file[1+1];
   dst.pad  = src.pad ;
end

-- constants and variables

  Pawn = pawn_t();           -- pawn_t[1]

  DoubledOpening = 10;       -- const int
  DoubledEndgame = 20;       -- const int

  IsolatedOpening = 10;      -- const int
  IsolatedOpeningOpen = 20;  -- const int
  IsolatedEndgame = 20;      -- const int

  BackwardOpening = 8;       -- const int
  BackwardOpeningOpen = 16;  -- const int
  BackwardEndgame = 10;      -- const int

  CandidateOpeningMin = 5;   -- const int
  CandidateOpeningMax = 55;  -- const int
  CandidateEndgameMin = 10;  -- const int
  CandidateEndgameMax = 110; -- const int

  Bonus = {};   -- int[RankNb]

-- variables

  BitEQ = {};   -- int[16]
  BitLT = {};   -- int[16]
  BitLE = {};   -- int[16]
  BitGT = {};   -- int[16]
  BitGE = {};   -- int[16]

  BitFirst = {};  -- int[0x100]
  BitLast = {};   -- int[0x100]
  BitCount = {};  -- int[0x100]
  BitRev = {};    -- int[0x100]


  BitRank1 = {};  -- int[RankNb]
  BitRank2 = {};  -- int[RankNb]
  BitRank3 = {};  -- int[RankNb]


-- end of pawn.h


-- pst.h

-- constants

  Opening = 0;   -- const int
  Endgame = 1;   -- const int
  StageNb = 2;   -- const int

-- constants

 pA1= 0; pB1= 1; pC1= 2; pD1= 3; pE1= 4; pF1= 5; pG1= 6; pH1= 7;     -- const int
 pA2= 8; pB2= 9; pC2=10; pD2=11; pE2=12; pF2=13; pG2=14; pH2=15;     -- const int
 pA3=16; pB3=17; pC3=18; pD3=19; pE3=20; pF3=21; pG3=22; pH3=23;     -- const int
 pA4=24; pB4=25; pC4=26; pD4=27; pE4=28; pF4=29; pG4=30; pH4=31;     -- const int
 pA5=32; pB5=33; pC5=34; pD5=35; pE5=36; pF5=37; pG5=38; pH5=39;     -- const int
 pA6=40; pB6=41; pC6=42; pD6=43; pE6=44; pF6=45; pG6=46; pH6=47;     -- const int
 pA7=48; pB7=49; pC7=50; pD7=51; pE7=52; pF7=53; pG7=54; pH7=55;     -- const int
 pA8=56; pB8=57; pC8=58; pD8=59; pE8=60; pF8=61; pG8=62; pH8=63;     -- const int

-- constants and variables

 PieceActivityWeight = 256; -- 100%   const int
 KingSafetyWeight = 256;    -- 100%  const int
 PawnStructureWeight = 256; -- 100%  const int
 PassedPawnWeight = 256;    -- 100%  const int

 PawnFileOpening = 5;        -- const int
 KnightCentreOpening = 5;    -- const int
 KnightCentreEndgame = 5;    -- const int
 KnightRankOpening = 5;      -- const int
 KnightBackRankOpening = 0;  -- const int
 KnightTrapped = 100;        -- const int
 BishopCentreOpening = 2;    -- const int
 BishopCentreEndgame = 3;    -- const int
 BishopBackRankOpening = 10; -- const int
 BishopDiagonalOpening = 4;  -- const int
 RookFileOpening = 3;        -- const int
 QueenCentreOpening = 0;     -- const int
 QueenCentreEndgame = 4;     -- const int
 QueenBackRankOpening = 5;   -- const int
 KingCentreEndgame = 12;     -- const int
 KingFileOpening = 10;       -- const int
 KingRankOpening = 10;       -- const int

-- "constants"

 PawnFile = { -3, -1, 0, 1, 1, 0, -1, -3 };      -- const int[8]

 KnightLine = { -4, -2, 0, 1, 1, 0, -2, -4 };    -- const int[8]

 KnightRank = { -2, -1, 0, 1, 2, 3, 2, 1 };    -- const int[8]

 BishopLine = { -3, -1, 0, 1, 1, 0, -1, -3 };    -- const int[8]

 RookFile = { -2, -1, 0, 1, 1, 0, -1, -2 };      -- const int[8]

 QueenLine = { -3, -1, 0, 1, 1, 0, -1, -3 };     -- const int[8]

 KingLine = { -3, -1, 0, 1, 1, 0, -1, -3 };      -- const int[8]

 KingFile = { 3, 4, 2, 0, 0, 2, 4, 3 };      -- const int[8]

 KingRank = { 1, 0, -2, -3, -4, -5, -6, -7 };      -- const int[8]

-- variables

 Pst = {};      -- sint16 [12][64][StageNb]


-- end of pst.h




-- random.h

-- "constants"

  Random64 = {};    -- uint64[RandomNb]  array of const fixed randoms
  R64_i = 0;        -- length
  RandomNb = 781;   -- max size

-- end of random.h




-- search.h

-- types

function my_timer_t ()
   local b = {};
   b.start_real = 0.0;	 -- double
   b.elapsed_real = 0.0; -- double
   b.running = false;    -- bool
   return b;
end

function search_input_t ()
   local b = {};
   b.board = board_t();          -- board_t[1]
   b.list = list_t();            -- list_t[1]
   b.infinite = false;           -- bool
   b.depth_is_limited = false;   -- bool
   b.depth_limit = 0;            -- int
   b.time_is_limited = false;    -- bool
   b.time_limit_1 = 0.0;         -- double
   b.time_limit_2 = 0.0;         -- double
   return b;
end

function search_info_t ()
   local b = {};
   b.can_stop = false;   -- bool
   b.stop = false;       -- bool
   b.check_nb = 0;       -- int
   b.check_inc = 0;      -- int
   b.last_time = 0.0;    -- double
   return b;
end

function search_root_t ()
   local b = {};
   b.list = list_t();  -- list_t[1]
   b.depth = 0;      -- int
   b.move = 0;       -- int
   b.move_pos = 0;   -- int
   b.move_nb = 0;    -- int
   b.last_value = 0; -- int
   b.bad_1 = false;  -- bool
   b.bad_2 = false;  -- bool
   b.change = false; -- bool
   b.easy = false;   -- bool
   b.flag = false;   -- bool
   return b;
end

function search_best_t ()
   local b = {};
   b.move = 0;    -- int
   b.value = 0;   -- int
   b.flags = 0;   -- int
   b.depth = 0;   -- int
   b.pv = {};     -- int[HeightMax];
   return b;
end

function search_current_t ()
   local b = {};
   b.board = board_t();       -- board_t[1]
   b.timer = my_timer_t();    -- my_timer_t[1]
   b.mate = 0;         -- int
   b.depth = 0;        -- int
   b.max_depth = 0;    -- int
   b.node_nb = 0;      -- sint64
   b.time = 0.0;       -- double
   b.speed = 0.0;      -- double
   return b;
end

-- variables

  setjmp = false;        -- c++ has setjmp-longjmp feature

-- constants

  DepthMax = 64;     -- const int
  HeightMax = 256;   -- const int

  SearchNormal = 0;  -- const int
  SearchShort  = 1;  -- const int

  SearchUnknown = 0; -- const int
  SearchUpper   = 1; -- const int
  SearchLower   = 2; -- const int
  SearchExact   = 3; -- const int

  UseShortSearch = true;    -- const bool
  ShortSearchDepth = 1;     -- const int

  DispBest = true;          -- const bool
  DispDepthStart = true;    -- const bool
  DispDepthEnd = true;      -- const bool
  DispRoot = true;          -- const bool
  DispStat = true;          -- const bool

  UseEasy = true;           -- const bool  singular move
  EasyThreshold = 150;      -- const int
  EasyRatio = 0.20;         -- const

  UseEarly = true;          -- const bool  early iteration end
  EarlyRatio = 0.60;        -- const

  UseBad = true;            -- const bool
  BadThreshold = 50;        -- const int
  UseExtension = true;      -- const bool

-- variables

  SearchInput = search_input_t();      -- search_input_t[1]
  SearchInfo = search_info_t();        -- search_info_t[1]
  SearchRoot = search_root_t();        -- search_root_t[1]
  SearchCurrent = search_current_t();  -- search_current_t[1]
  SearchBest = search_best_t();        -- search_best_t[1]



-- constants and variables

-- main search

  UseDistancePruning = true;   -- const bool

-- transposition table

  TransDepth = 1;    -- const int

  UseMateValues = true; -- use mate values from shallower searches?   -- const bool

-- nil move

  Usenil = true;     -- const bool
  UsenilEval = true; -- const bool
  nilDepth = 2;      -- const int
  nilReduction = 3;  -- const int

  UseVer = true;         -- const bool
  UseVerEndgame = true;  -- const bool
  VerReduction = 5;      -- const int   was 3

-- move ordering

  UseIID = true;      -- const bool
  IIDDepth = 3;       -- const int
  IIDReduction = 2;   -- const int

-- extensions

  ExtendSingleReply = true;   -- const bool

-- history pruning

  UseHistory = true;       -- const bool
  HistoryDepth = 3;        -- const int
  HistoryMoveNb = 3;       -- const int
  HistoryValue = 9830;     -- const int 60%
  HistoryReSearch = true;  -- const bool

-- futility pruning

  UseFutility = false;     -- const bool
  FutilityMargin = 100;    -- const int

-- quiescence search

  UseDelta = false;        -- const bool
  DeltaMargin = 50;        -- const int

  CheckNb = 1;             -- const int
  CheckDepth = 0;          -- const int   1 - CheckNb

-- misc

  NodeAll = -1;   -- const int
  NodePV  =  0;   -- const int
  NodeCut = 1;   -- const int


-- end of search.h



-- fen.h

-- "constants"

 StartFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";   -- const char

-- variables

 Strict = false;   -- const bool

-- end of fen.h



-- protocol.h

-- constants

 VERSION = "Fruit 2.1 by Fabien Letouzey, port to Lua by Chessforeva";
 NormalRatio = 1.0;   -- const
 PonderRatio = 1.25;   -- const

-- variables

 Init = false;       -- bool

-- end of protocol.h



-- sort.h

-- types

function sort_t ()
   local b = {};
   b.depth = 0;         -- int
   b.height = 0;        -- int
   b.trans_killer = 0;  -- int
   b.killer_1 = 0;      -- int
   b.killer_2 = 0;      -- int
   b.gen = 0;           -- int
   b.test = 0;          -- int
   b.pos = 0;           -- int
   b.value = 0;         -- int
   b.board = {};        -- board_t *
   b.attack = {};       -- const attack_t *
   b.list = list_t();   -- list_t[1]
   b.bad = list_t();    -- list_t[1]
   return b;
end


-- constants

  KillerNb = 2;   -- const int

  HistorySize = 12 * 64;   -- const int
  HistoryMax = 16384;      -- const int

  TransScore   = 32766;   -- const int
  GoodScore    =  4000;   -- const int
  KillerScore  =     4;   -- const int
  HistoryScore = -24000;   -- const int
  BadScore     = -28000;   -- const int

  CODE_SIZE = 256;         -- const int


   GEN_ERROR = 0;
   GEN_LEGAL_EVASION = 1;
   GEN_TRANS = 2;
   GEN_GOOD_CAPTURE = 3;
   GEN_BAD_CAPTURE = 4;
   GEN_KILLER = 5;
   GEN_QUIET = 6;
   GEN_EVASION_QS = 7;
   GEN_CAPTURE_QS = 8;
   GEN_CHECK_QS = 9;
   GEN_END = 10;

   TEST_ERROR = 0;
   TEST_NONE = 1;
   TEST_LEGAL = 2;
   TEST_TRANS_KILLER = 3;
   TEST_GOOD_CAPTURE = 4;
   TEST_BAD_CAPTURE = 5;
   TEST_KILLER = 6;
   TEST_QUIET = 7;
   TEST_CAPTURE_QS = 8;
   TEST_CHECK_QS = 9;


-- variables

 PosLegalEvasion = 0;   -- int
 PosSEE = 0;            -- int

 PosEvasionQS = 0;      -- int
 PosCheckQS = 0;        -- int
 PosCaptureQS = 0;      -- int

 Code = {};             -- int[CODE_SIZE]

 Killer = {};           -- uint16[HeightMax][KillerNb]

 History = {};          -- uint16[HistorySize]
 HistHit = {};          -- uint16[HistorySize]
 HistTot = {};          -- uint16[HistorySize]



-- end of sort.h



-- value.h

-- variables

  ValuePiece = { 0, 0 };   -- int[PieceNb]

-- constants

 ValuePawn   = 100;   -- was 100   const int
 ValueKnight = 325;   -- was 300   const int
 ValueBishop = 325;   -- was 300   const int
 ValueRook   = 500;   -- was 500   const int
 ValueQueen  = 1000;  -- was 900   const int
 ValueKing   = 10000; -- was 10000 const int

 ValueNone    = -32767;          -- const int
 ValueDraw    = 0;               -- const int
 ValueMate    = 30000;           -- const int
 ValueInf     = ValueMate;       -- const int
 ValueEvalInf = ValueMate - 256; -- const int handle mates upto 255 plies


-- end of value.h


-- eval.h

-- constants and variables

 KnightUnit = 4;   -- const int
 BishopUnit = 6;   -- const int
 RookUnit = 7;     -- const int
 QueenUnit = 13;   -- const int

 MobMove = 1;      -- const int
 MobAttack = 1;    -- const int
 MobDefense = 0;   -- const int

 KnightMobOpening = 4; -- const int
 KnightMobEndgame = 4; -- const int
 BishopMobOpening = 5; -- const int
 BishopMobEndgame = 5; -- const int
 RookMobOpening = 2;   -- const int
 RookMobEndgame = 4;   -- const int
 QueenMobOpening = 1;  -- const int
 QueenMobEndgame = 2;  -- const int
 KingMobOpening = 0;   -- const int
 KingMobEndgame = 0;   -- const int

 UseOpenFile = true;   -- const bool
 RookSemiOpenFileOpening = 10;  -- const int
 RookSemiOpenFileEndgame = 10;  -- const int
 RookOpenFileOpening = 20;      -- const int
 RookOpenFileEndgame = 20;      -- const int
 RookSemiKingFileOpening = 10;  -- const int
 RookKingFileOpening = 20;      -- const int

 UseKingAttack = true;     -- const bool
 KingAttackOpening = 20;   -- const int

 UseShelter = true;    -- const bool
 ShelterOpening = 256; -- 100%  const int
 UseStorm = true;      -- const bool
 StormOpening = 10;    -- const int

 Rook7thOpening = 20;   -- const int
 Rook7thEndgame = 40;   -- const int
 Queen7thOpening = 10;  -- const int
 Queen7thEndgame = 20;  -- const int

 TrappedBishop = 100;   -- const int

 BlockedBishop = 50;   -- const int
 BlockedRook = 50;     -- const int

 PassedOpeningMin = 10;   -- const int
 PassedOpeningMax = 70;   -- const int
 PassedEndgameMin = 20;   -- const int
 PassedEndgameMax = 140;  -- const int

 UnstoppablePasser = 800; -- const int
 FreePasser = 60;         -- const int

 AttackerDistance = 5;    -- const int
 DefenderDistance = 20;   -- const int

-- "constants"

 KingAttackWeight = { 0, 0, 128, 192, 224, 240, 248, 252, 254, 255, 256, 256 ,256, 256, 256, 256 };  -- const int[16]

-- variables

 MobUnit = {};        -- int[ColourNb][PieceNb]
 MobUnit[1+0] = {};
 MobUnit[1+1] = {};

 KingAttackUnit = {}  -- int[PieceNb]

-- macros

function THROUGH(piece)
 return (piece==Empty);
end

-- end of eval.h



-- hash.h

-- variables

 Castle64 = {};   -- int[16]

-- end of hash.h




-- vector.h

-- "constants"

 IncNone = 0;          -- const int
 IncNb = (2*17) + 1;   -- const int
 IncOffset = 17;       -- const int

 DeltaNone = 0;           -- const int
 DeltaNb = (2*119) + 1;   -- const int
 DeltaOffset = 119;       -- const int

-- variables

 Distance = {};   -- int[DeltaNb]

-- macros

function DISTANCE(square_1,square_2)
 return Distance[1+DeltaOffset+(square_2-square_1)];
end

-- end of vector.h


-- option.h

-- types

function opt_t_def( var, declare, init, type, extra, val )
   local b = {};
   b.var = var;          -- string
   b.declare = declare;  -- bool
   b.init = init;        -- string
   b.type = type;        -- string
   b.extra = extra;      -- string
   b.val = val;          -- string
   return b;
end

-- variables

 Option = {};

-- end of option.h


--
-- Programs C
--


-- attack.cpp

-- functions

-- attack_init()

function attack_init()  -- void

   local delta = 0;   -- int
   local inc = 0;     -- int
   local piece = 0;   -- int
   local dir = 0;     -- int
   local dist = 0;    -- int
   local size = 0;    -- int
   local king = 0;    -- int
   local from = 0;    -- int
   local to = 0;      -- int
   local pos = 0;     -- int
   local k = 0;
   local mcache = true;
   local mfile = nil;


   -- clear

   for delta = 0, DeltaNb-1, 1 do
      DeltaIncLine[1+delta] = IncNone;
      DeltaIncAll[1+delta] = IncNone;
      DeltaMask[1+delta] = 0;
   end

   for inc = 0, IncNb-1, 1 do
      IncMask[1+inc] = 0;
   end

   -- pawn attacks

   DeltaMask[1+DeltaOffset-17] = bit.bor( DeltaMask[1+DeltaOffset-17], BlackPawnFlag );
   DeltaMask[1+DeltaOffset-15] = bit.bor( DeltaMask[1+DeltaOffset-15], BlackPawnFlag );

   DeltaMask[1+DeltaOffset+15] = bit.bor( DeltaMask[1+DeltaOffset+15], WhitePawnFlag );
   DeltaMask[1+DeltaOffset+17] = bit.bor( DeltaMask[1+DeltaOffset+17], WhitePawnFlag );

   -- knight attacks

   for dir = 0, 7, 1 do

      delta = KnightInc[1+dir];
      ----ASSERT(3, delta_is_ok(delta));

      ----ASSERT(4, DeltaIncAll[1+DeltaOffset+delta]==IncNone);
      DeltaIncAll[1+DeltaOffset+delta] = delta;
      DeltaMask[1+DeltaOffset+delta] = bit.bor( DeltaMask[1+DeltaOffset+delta], KnightFlag );
   end

   -- bishop/queen attacks

   for dir = 0, 3, 1 do

      inc = BishopInc[1+dir];
      ----ASSERT(5, inc~=IncNone);

      IncMask[1+IncOffset+inc] = bit.bor( IncMask[1+IncOffset+inc], BishopFlag );

      for dist = 1, 7, 1 do

         delta = inc*dist;
         ----ASSERT(6, delta_is_ok(delta));

         ----ASSERT(7, DeltaIncLine[1+DeltaOffset+delta]==IncNone);
         DeltaIncLine[1+DeltaOffset+delta] = inc;
         ----ASSERT(8, DeltaIncAll[1+DeltaOffset+delta]==IncNone);
         DeltaIncAll[1+DeltaOffset+delta] = inc;
         DeltaMask[1+DeltaOffset+delta] = bit.bor( DeltaMask[1+DeltaOffset+delta], BishopFlag );
      end
   end

   -- rook/queen attacks

   for dir = 0, 3, 1 do

      inc = RookInc[1+dir];
      ----ASSERT(9, inc~=IncNone);

      IncMask[1+IncOffset+inc] = bit.bor( IncMask[1+IncOffset+inc], RookFlag );

      for dist = 1, 7, 1 do

         delta = inc*dist;
         ----ASSERT(10, delta_is_ok(delta));

         ----ASSERT(11, DeltaIncLine[1+DeltaOffset+delta]==IncNone);
         DeltaIncLine[1+DeltaOffset+delta] = inc;
         ----ASSERT(12, DeltaIncAll[1+DeltaOffset+delta]==IncNone);
         DeltaIncAll[1+DeltaOffset+delta] = inc;
         DeltaMask[1+DeltaOffset+delta] = bit.bor( DeltaMask[1+DeltaOffset+delta], RookFlag );
      end
   end

   -- king attacks

   for dir = 0, 7, 1 do

      delta = KingInc[1+dir];
      ----ASSERT(13, delta_is_ok(delta));

      DeltaMask[1+DeltaOffset+delta] = bit.bor( DeltaMask[1+DeltaOffset+delta], KingFlag );
   end

   -- PieceCode[]

   for piece = 0, PieceNb-1, 1 do
      PieceCode[1+piece] = -1;
   end

   PieceCode[1+WN] = 0;
   PieceCode[1+WB] = 1;
   PieceCode[1+WR] = 2;
   PieceCode[1+WQ] = 3;

   PieceCode[1+BN] = 0;
   PieceCode[1+BB] = 1;
   PieceCode[1+BR] = 2;
   PieceCode[1+BQ] = 3;

   -- PieceDeltaSize[][] & PieceDeltaDelta[][][]


  if( UseMcache ) then
   -- will be fast on next starting
   mfile = io.open("mem_dat1.txt", "r")

   if(mfile==nil) then
     mfile = io.open("mem_dat1.txt", "w")   -- then create
     mcache = false;
   end
  end

   for piece = 0, 3, 1 do

      PieceDeltaSize[1+piece] = {};
      PieceDeltaDelta[1+piece] = {}

      for delta = 0, 255, 1 do

         PieceDeltaSize[1+piece][1+delta] = 0;
         PieceDeltaDelta[1+piece][1+delta] = {};

         if(UseMcache and mcache) then
            size = mfile:read("*number");
            PieceDeltaSize[1+piece][1+delta] = size;
            for k=0, size-1, 1 do
              PieceDeltaDelta[1+piece][1+delta][1+k] = mfile:read("*number");
            end
            PieceDeltaDelta[1+piece][1+delta][1+size] = DeltaNone;
         end
      end
   end

   if((not UseMcache) or (not mcache)) then

    for king = 0, SquareNb-1, 1 do

      if (SQUARE_IS_OK(king)) then

         for from = 0, SquareNb-1, 1 do

            if (SQUARE_IS_OK(from)) then

               -- knight
               pos = 0;
               while (true) do
                  inc=KnightInc[1+pos];
                  if(inc == IncNone) then
                    break;
                  end
                  to = from + inc;
                  if (SQUARE_IS_OK(to)  and  DISTANCE(to,king) == 1) then
                     add_attack(0,king-from,to-from);
                  end
                  pos = pos + 1;
               end

               -- bishop
               pos = 0;
               while (true) do
                  inc=BishopInc[1+pos];
                  if(inc == IncNone) then
                    break;
                  end
                  to = from+inc;
                  while( SQUARE_IS_OK(to) ) do
                     if (DISTANCE(to,king) == 1) then
                        add_attack(1,king-from,to-from);
                        break;
                     end
                     to = to + inc;
                  end
                  pos = pos + 1;
               end

               -- rook
               pos = 0;
               while (true) do
                  inc=RookInc[1+pos];
                  if(inc == IncNone) then
                    break;
                  end
                  to = from+inc;
                  while( SQUARE_IS_OK(to) ) do
                     if (DISTANCE(to,king) == 1) then
                        add_attack(2,king-from,to-from);
                        break;
                     end
                     to = to + inc;
                  end
                  pos = pos + 1;
               end

               -- queen
               pos = 0;
               while (true) do
                  inc=QueenInc[1+pos];
                  if(inc == IncNone) then
                    break;
                  end
                  to = from+inc;
                  while( SQUARE_IS_OK(to) ) do
                     if (DISTANCE(to,king) == 1) then
                        add_attack(3,king-from,to-from);
                        break;
                     end
                     to = to + inc;
                  end
                  pos = pos + 1;
               end
            end
         end
      end
    end

    for piece = 0, 3, 1 do
      for delta = 0, 255, 1 do
         size = PieceDeltaSize[1+piece][1+delta];
         ----ASSERT(14, size>=0 and size<3);
         PieceDeltaDelta[1+piece][1+delta][1+size] = DeltaNone;
         if(UseMcache and (not mcache)) then
           mfile:write( size );
           mfile:write( "\n" );
           for k=0, size-1, 1 do
              mfile:write( PieceDeltaDelta[1+piece][1+delta][1+k] );
		      mfile:write( "\n" );
           end
         end
      end
    end

   end --

   if(mfile~=nil) then
     mfile:close();
   end

end

-- add_attack()

function add_attack(piece, king, target)  -- void

   local size = 0;   -- int
   local i = 0;      -- int


   ----ASSERT(15, piece>=0 and piece<4);
   ----ASSERT(16, delta_is_ok(king));
   ----ASSERT(17, delta_is_ok(target));

   size = PieceDeltaSize[1+piece][1+DeltaOffset+king];
   ----ASSERT(18, size>=0 and size<3);

   for i = 0, size-1, 1 do
      if (PieceDeltaDelta[1+piece][1+DeltaOffset+king][1+i] == target) then
        return;    -- already in the table
      end
   end

   if (size < 2)  then
      PieceDeltaDelta[1+piece][1+DeltaOffset+king][1+size] = target;
      size = size + 1;
      PieceDeltaSize[1+piece][1+DeltaOffset+king] = size;
   end
end

-- is_attacked()

function is_attacked( board, to, colour)  -- bool

   local inc = 0;    -- int
   local pawn = 0;   -- int
   local ptr = 0;    -- int
   local from = 0;   -- int
   local piece = 0;  -- int
   local delta = 0;  -- int
   local sq = 0;     -- int

   ----ASSERT(19, board.sp~=nil);
   ----ASSERT(20, SQUARE_IS_OK(to));
   ----ASSERT(21, COLOUR_IS_OK(colour));

   -- pawn attack

   inc = PawnMoveInc[1+colour];
   pawn = PawnMake[1+colour];

   if (board.square[1+to-(inc-1)] == pawn) then
     return true;
   end
   if (board.square[1+to-(inc+1)] == pawn) then
     return true;
   end

   -- piece attack

   ptr = 0;
   while(true) do
      from = board.piece[1+colour][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];
      delta = to - from;

      if (PSEUDO_ATTACK(piece,delta)) then

         inc = DELTA_INC_ALL(delta);
         ----ASSERT(22, inc~=IncNone);

         sq = from;
         while(true) do

           sq = sq + inc;
           if (sq == to) then
             return true;
           end
           if (board.square[1+sq] ~= Empty) then
             break;
           end
         end
      end
      ptr = ptr + 1;
   end

   return false;

end

-- line_is_empty()

function line_is_empty( board, from, to )  -- bool

   local delta = 0;  -- int
   local inc = 0;    -- int
   local sq = 0;     -- int

   ----ASSERT(23, board.sp~=nil);
   ----ASSERT(24, SQUARE_IS_OK(from));
   ----ASSERT(25, SQUARE_IS_OK(to));

   delta = to - from;
   ----ASSERT(26, delta_is_ok(delta));

   inc = DELTA_INC_ALL(delta);
   ----ASSERT(27, inc~=IncNone);

   sq = from;
   while(true) do

     sq = sq + inc;
     if (sq == to) then
       return true;
     end
     if (board.square[1+sq] ~= Empty) then
       break;
     end
   end

   return false;  -- blocker
end

-- is_pinned()

function is_pinned( board, square, colour)  -- bool

   local from = 0;  -- int
   local to = 0;    -- int
   local inc = 0;   -- int
   local sq = 0;    -- int
   local piece = 0; -- int

   ----ASSERT(28, board.sp~=nil);
   ----ASSERT(29, SQUARE_IS_OK(square));
   ----ASSERT(30, COLOUR_IS_OK(colour));

   from = square;
   to = KING_POS(board,colour);

   inc = DELTA_INC_LINE(to-from);
   if (inc == IncNone) then
     return false;  -- not a line
   end

   sq = from;
   while(true) do
     sq = sq + inc;
     if (board.square[1+sq] ~= Empty) then
       break;
     end
   end

   if (sq ~= to) then
     return false; -- blocker
   end

   sq = from;
   while(true) do
     sq = sq - inc;
     piece = board.square[1+sq];
     if ( piece~= Empty) then
       break;
     end
   end

   return COLOUR_IS(piece,COLOUR_OPP(colour)) and SLIDER_ATTACK(piece,inc);
end

-- attack_is_ok()

function attack_is_ok( attack )  -- bool

   local i = 0;   -- int
   local sq = 0;  -- int
   local inc = 0; -- int

   if (attack.dn == nil) then
     return false;
   end

   -- checks

   if (attack.dn < 0 or attack.dn > 2) then
     return false;
   end

   for i = 0, attack.dn-1, 1 do
      sq = attack.ds[1+i];
      if (not SQUARE_IS_OK(sq)) then
        return false;
      end
      inc = attack.di[1+i];
      if (inc ~= IncNone  and  (not inc_is_ok(inc))) then
        return false;
      end
   end

   if (attack.ds[1+attack.dn] ~= SquareNone) then
     return false;
   end
   if (attack.di[1+attack.dn] ~= IncNone) then
     return false;
   end

   return true;
end

-- attack_set()

function attack_set( attack, board )  -- void

   local me = 0;    -- int
   local opp = 0;   -- int
   local ptr = 0;   -- int
   local from = 0;  -- int
   local to = 0;    -- int
   local inc = 0;   -- int
   local pawn = 0;  -- int
   local delta = 0; -- int
   local piece = 0; -- int
   local sq = 0;    -- int
   local cont = false;

   ----ASSERT(31, attack.dn~=nil);
   ----ASSERT(32, board.sp~=nil);

   -- init

   attack.dn = 0;

   me = board.turn;
   opp = COLOUR_OPP(me);

   to = KING_POS(board,me);

   -- pawn attacks

   inc = PawnMoveInc[1+opp];
   pawn = PawnMake[1+opp];

   from = to - (inc-1);
   if (board.square[1+from] == pawn) then
      attack.ds[1+attack.dn] = from;
      attack.di[1+attack.dn] = IncNone;
      attack.dn = attack.dn + 1;
   end

   from = to - (inc+1);
   if (board.square[1+from] == pawn) then
      attack.ds[1+attack.dn] = from;
      attack.di[1+attack.dn] = IncNone;
      attack.dn = attack.dn + 1;
   end

   -- piece attacks

   ptr = 1;	-- HACK: no king
   while(true) do
      from = board.piece[1+opp][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      delta = to - from;
      ----ASSERT(33, delta_is_ok(delta));

      if (PSEUDO_ATTACK(piece,delta)) then

         inc = IncNone;

         if (PIECE_IS_SLIDER(piece)) then

            -- check for blockers

            inc = DELTA_INC_LINE(delta);
            ----ASSERT(34, inc~=IncNone);

            sq = from;
            while(true) do
              sq = sq + inc;
              if (board.square[1+sq] ~= Empty) then
                break;
              end
            end

            if (sq ~= to) then
              cont = true;     -- blocker => next attacker
            end
         end

         if(cont) then
           cont = false;
         else
           attack.ds[1+attack.dn] = from;
           attack.di[1+attack.dn] = -inc; -- HACK
           attack.dn = attack.dn + 1;
         end
      end
      ptr = ptr + 1;
   end

   attack.ds[1+attack.dn] = SquareNone;
   attack.di[1+attack.dn] = IncNone;

   -- debug

   ----ASSERT(35, attack_is_ok(attack));
end

-- piece_attack_king()

function piece_attack_king( board, piece, from, king )  -- bool

   local code = 0;      -- int
   local delta_ptr = 0; -- int
   local delta = 0;     -- int
   local inc = 0;       -- int
   local to = 0;        -- int
   local sq = 0;        -- int

   --ASSERT(36, board.sp~=nil);
   --ASSERT(37, piece_is_ok(piece));
   --ASSERT(38, SQUARE_IS_OK(from));
   --ASSERT(39, SQUARE_IS_OK(king));

   code = PieceCode[1+piece];
   --ASSERT(40, code>=0 and code<4);

   if (PIECE_IS_SLIDER(piece)) then

      delta_ptr = 0;
      while(true) do

         delta = PieceDeltaDelta[1+code][1+DeltaOffset+(king-from)][1+delta_ptr];
         if(delta==DeltaNone) then
           break;
         end

         --ASSERT(41, delta_is_ok(delta));

         inc = DeltaIncLine[1+DeltaOffset+delta];
         --ASSERT(42, inc~=IncNone);

         to = from + delta;

         sq = from;
         while(true) do
           sq = sq + inc;

           if (sq == to and SQUARE_IS_OK(to)) then
              --ASSERT(43, DISTANCE(to,king)==1);
              return true;
           end

           if (board.square[1+sq] ~= Empty) then
             break;
           end
         end

         delta_ptr = delta_ptr + 1;
      end

   else -- non-slider

      delta_ptr = 0;
      while(true) do

         delta = PieceDeltaDelta[1+code][1+DeltaOffset+(king-from)][1+delta_ptr];
         if(delta==DeltaNone) then
           break;
         end

         --ASSERT(44, delta_is_ok(delta));

         to = from + delta;

         if (SQUARE_IS_OK(to)) then
            --ASSERT(45, DISTANCE(to,king)==1);
            return true;
         end

         delta_ptr = delta_ptr + 1;
      end
   end

   return false;
end

-- end of attack.cpp



-- board.cpp

-- functions

-- board_is_ok()

function board_is_ok( board ) -- const bool

   local sq = 0;     -- int
   local piece = 0;  -- int
   local colour = 0; -- int
   local size = 0;   -- int
   local pos = 0;    -- int

   if (board.sp == nil) then
     return false;
   end

   -- squares

   for sq = 0, SquareNb-1, 1 do

      piece = board.square[1+sq];
      pos = board.pos[1+sq];

      if (SQUARE_IS_OK(sq)) then

         -- inside square

         if (piece == Empty) then

            if (pos ~= -1) then
              return false;
            end
         else

            if (not piece_is_ok(piece)) then
              return false;
            end

            if (not PIECE_IS_PAWN(piece)) then
               colour = PIECE_COLOUR(piece);
               if (pos < 0  or  pos >= board.piece_size[1+colour]) then
                 return false;
               end
               if (board.piece[1+colour][1+pos] ~= sq) then
                 return false;
               end
            else -- pawn
               if (SquareIsPromote[1+sq]) then
                return false;
               end
               colour = PIECE_COLOUR(piece);
               if (pos < 0  or  pos >= board.pawn_size[1+colour]) then
                return false;
               end
               if (board.pawn[1+colour][1+pos] ~= sq) then
                return false;
               end
            end
         end

      else

         -- edge square

         if (piece ~= Edge) then
           return false;
         end
         if (pos ~= -1) then
           return false;
         end
      end
   end

   -- piece lists

   for colour = 0, 1, 1 do

      -- piece list

      size = board.piece_size[1+colour];
      if (size < 1  or  size > 16) then
        return false;
      end

      for pos = 0, size-1, 1 do

         sq = board.piece[1+colour][1+pos];
         if (not SQUARE_IS_OK(sq)) then
           return false;
         end
         if (board.pos[1+sq] ~= pos) then
           return false;
         end
         piece = board.square[1+sq];
         if (not COLOUR_IS(piece,colour)) then
           return false;
         end
         if (pos == 0  and  not PIECE_IS_KING(piece)) then
           return false;
         end
         if (pos ~= 0  and  PIECE_IS_KING(piece)) then
           return false;
         end
         if (pos ~= 0  and  PieceOrder[1+piece] > PieceOrder[1+board.square[1+board.piece[1+colour][1+pos-1]]]) then
            return false;
         end
      end

      sq = board.piece[1+colour][1+size];
      if (sq ~= SquareNone) then
        return false;
      end

      -- pawn list

      size = board.pawn_size[1+colour];
      if (size < 0  or  size > 8) then
        return false;
      end

      for pos = 0, size-1, 1 do

         sq = board.pawn[1+colour][1+pos];
         if (not SQUARE_IS_OK(sq)) then
           return false;
         end
         if (SquareIsPromote[1+sq]) then
           return false;
         end
         if (board.pos[1+sq] ~= pos) then
           return false;
         end
         piece = board.square[1+sq];
         if (not COLOUR_IS(piece,colour)) then
           return false;
         end
         if (not PIECE_IS_PAWN(piece)) then
           return false;
         end
      end

      sq = board.pawn[1+colour][1+size];
      if (sq ~= SquareNone) then
        return false;
      end

      -- piece total

      if (board.piece_size[1+colour] + board.pawn_size[1+colour] > 16) then
        return false;
      end
   end

   -- material

   if (board.piece_nb ~= board.piece_size[1+White] + board.pawn_size[1+White]
                        + board.piece_size[1+Black] + board.pawn_size[1+Black]) then
      return false;
   end

   if (board.number[1+WhitePawn12] ~= board.pawn_size[1+White]) then
     return false;
   end
   if (board.number[1+BlackPawn12] ~= board.pawn_size[1+Black]) then
     return false;
   end
   if (board.number[1+WhiteKing12] ~= 1) then
     return false;
   end
   if (board.number[1+BlackKing12] ~= 1) then
     return false;
   end

   -- misc

   if (not COLOUR_IS_OK(board.turn)) then
     return false;
   end

   if (board.ply_nb < 0) then
     return false;
   end

   if (board.sp < board.ply_nb) then
     return false;
   end

   if (board.cap_sq ~= SquareNone  and  (not SQUARE_IS_OK(board.cap_sq))) then
     return false;
   end

   if (board.opening ~= board_opening(board)) then
     return false;
   end
   if (board.endgame ~= board_endgame(board)) then
     return false;
   end

   -- we can not guarantee that the key is the same, it is just a random number
   --
   --if (board.key ~= hash_key(board)) then
   --  return false;
   --end
   --if (board.pawn_key ~= hash_pawn_key(board)) then
   --  return false;
   --end
   --if (board.material_key ~= hash_material_key(board)) then
   --  return false;
   --end

   return true;
end

-- board_clear()

function board_clear( board ) -- void

   local sq = 0;     -- int
   local sq_64 = 0;  -- int

   --ASSERT(46, board.sp~=nil);

   -- edge squares

   for sq = 0, SquareNb-1, 1 do
      board.square[1+sq] = Edge;
   end

   -- empty squares

   for sq_64 = 0, 63, 1 do
      sq = SquareFrom64[1+sq_64];
      board.square[1+sq] = Empty;
   end

   -- misc

   board.turn = ColourNone;
   board.flags = FlagsNone;
   board.ep_square = SquareNone;
   board.ply_nb = 0;
end

-- board_copy()

function board_copy( dst, src ) -- void

   local i = 0;  -- int

   --ASSERT(47, dst.sp~=nil );
   --ASSERT(48, board_is_ok(src));

   dst.square = {};
   for i = 0, table.getn(src.square)-1, 1 do
     dst.square[1+i] = src.square[1+i];
   end
   
   dst.pos = {};
   for i = 0, table.getn(src.pos)-1, 1 do
     dst.pos[1+i] = src.pos[1+i];
   end
   
   dst.piece = {};
   dst.piece[1+0] = {};
   dst.piece[1+1] = {};

   for i = 0, table.getn(src.piece[1+0])-1, 1 do
     dst.piece[1+0][1+i] = src.piece[1+0][1+i];
   end
   for i = 0, table.getn(src.piece[1+1])-1, 1 do
     dst.piece[1+1][1+i] = src.piece[1+1][1+i];
   end

   dst.piece_size = {};
   for i = 0, table.getn(src.piece_size)-1, 1 do
     dst.piece_size[1+i] = src.piece_size[1+i];
   end

   dst.pawn = {};
   dst.pawn[1+0] = {};
   dst.pawn[1+1] = {};

   for i = 0, table.getn(src.pawn[1+0])-1, 1 do
     dst.pawn[1+0][1+i] = src.pawn[1+0][1+i];
   end
   for i = 0, table.getn(src.pawn[1+1])-1, 1 do
     dst.pawn[1+1][1+i] = src.pawn[1+1][1+i];
   end

   dst.pawn_size = {};
   for i = 0, table.getn(src.pawn_size)-1, 1 do
     dst.pawn_size[1+i] = src.pawn_size[1+i];
   end

   dst.piece_nb = src.piece_nb;
   dst.number = {};
   for i = 0, table.getn(src.number)-1, 1 do
     dst.number[1+i] = src.number[1+i];
   end

   dst.pawn_file = {};
   dst.pawn_file[1+0] = {};
   dst.pawn_file[1+1] = {};

   for i = 0, table.getn(src.pawn_file[1+0])-1, 1 do
     dst.pawn_file[1+0][1+i] = src.pawn_file[1+0][1+i];
   end
   for i = 0, table.getn(src.pawn_file[1+1])-1, 1 do
     dst.pawn_file[1+1][1+i] = src.pawn_file[1+1][1+i];
   end


   dst.turn = src.turn;
   dst.flags = src.flags;
   dst.ep_square = src.ep_square
   dst.ply_nb = src.ply_nb;
   dst.sp = src.sp;

   dst.cap_sq = src.cap_sq;

   dst.opening = src.opening;
   dst.endgame = src.endgame;

   dst.key = src.key;
   dst.pawn_key = src.pawn_key;
   dst.material_key = src.material_key;

   dst.stack = {};
   for i = 0, table.getn(src.stack)-1, 1 do
     dst.stack[1+i] = src.stack[1+i];
   end

end


-- board_init_list()

function board_init_list( board ) -- void

   local sq_64 = 0;   -- int
   local sq = 0;      -- int
   local piece = 0;   -- int
   local colour = 0;  -- int
   local pos = 0;     -- int
   local i = 0;       -- int
   local size = 0;    -- int
   local square = 0;  -- int
   local order = 0;   -- int
   local file = 0;    -- int

   --ASSERT(49, board.sp~=nil);

   -- init

   for sq = 0, SquareNb-1, 1 do
      board.pos[1+sq] = -1;
   end

   board.piece_nb = 0;
   for piece = 0, 11, 1 do
     board.number[1+piece] = 0;
   end

   -- piece lists

   for colour = 0, 1, 1 do

      -- piece list

      pos = 0;

      for sq_64 = 0, 63, 1 do

         sq = SquareFrom64[1+sq_64];
         piece = board.square[1+sq];
         if (piece ~= Empty  and  (not piece_is_ok(piece))) then
           my_fatal("board_init_list(): illegal position\n");
         end

         if (COLOUR_IS(piece,colour)  and  (not PIECE_IS_PAWN(piece))) then

            if (pos >= 16) then
              my_fatal("board_init_list(): illegal position\n");
            end
            --ASSERT(50, pos>=0 and pos<16);

            board.pos[1+sq] = pos;
            board.piece[1+colour][1+pos] = sq;
            pos = pos + 1;

            board.piece_nb = board.piece_nb + 1;
            board.number[1+PieceTo12[1+piece]] = board.number[1+PieceTo12[1+piece]] + 1;
         end
      end

      if ( board.number[1+iif( COLOUR_IS_WHITE(colour), WhiteKing12, BlackKing12 ) ] ~= 1) then
        my_fatal("board_init_list(): illegal position\n");
      end

      --ASSERT(51, pos>=1 and pos<=16);
      board.piece[1+colour][1+pos] = SquareNone;
      board.piece_size[1+colour] = pos;

      -- MV sort

      size = board.piece_size[1+colour];

      for i = 1, size-1, 1 do

         square = board.piece[1+colour][1+i];
         piece = board.square[1+square];
         order = PieceOrder[1+piece];
         pos = i;
         while( pos > 0 ) do
            sq=board.piece[1+colour][1+pos-1];
            if( order <= PieceOrder[1+board.square[1+sq]] ) then
              break;
            end
            --ASSERT(52, pos>0 and pos<size);
            board.piece[1+colour][1+pos] = sq;
            --ASSERT(53, board.pos[1+sq]==pos-1);
            board.pos[1+sq] = pos;
            pos = pos - 1;
         end

         --ASSERT(54, pos>=0 and pos<size);
         board.piece[1+colour][1+pos] = square;
         --ASSERT(55, board.pos[1+square]==i);
         board.pos[1+square] = pos;
      end

      -- debug

      if (iDbg01) then

         for i = 0, board.piece_size[1+colour]-1, 1 do

            sq = board.piece[1+colour][1+i];
            --ASSERT(56, board.pos[1+sq]==i);

            if (i == 0) then  -- king
               --ASSERT(57, PIECE_IS_KING(board.square[1+sq]));
            else
               --ASSERT(58, not PIECE_IS_KING(board.square[1+sq]));
               --ASSERT(59, PieceOrder[1+board.square[1+board.piece[1+colour][1+i]]] <=                                                    PieceOrder[1+board.square[1+board.piece[1+colour][1+i-1]]]);
            end
         end
      end

      -- pawn list

      for file = 0, FileNb-1, 1 do
         board.pawn_file[1+colour][1+file] = 0;
      end

      pos = 0;

      for sq_64 = 0, 63, 1 do

         sq = SquareFrom64[1+sq_64];
         piece = board.square[1+sq];

         if (COLOUR_IS(piece,colour)  and  PIECE_IS_PAWN(piece)) then

            if (pos >= 8  or  SquareIsPromote[1+sq]) then
              my_fatal("board_init_list(): illegal position\n");
            end
            --ASSERT(60, pos>=0 and pos<8);

            board.pos[1+sq] = pos;
            board.pawn[1+colour][1+pos] = sq;
            pos = pos + 1;

            board.piece_nb = board.piece_nb + 1;
            board.number[1+PieceTo12[1+piece]] = board.number[1+PieceTo12[1+piece]] + 1;
            board.pawn_file[1+colour][1+SQUARE_FILE(sq)] =
              bit.bor( board.pawn_file[1+colour][1+SQUARE_FILE(sq)], BitEQ[1+PAWN_RANK(sq,colour)]);
         end
      end

      --ASSERT(61, pos>=0 and pos<=8);
      board.pawn[1+colour][1+pos] = SquareNone;
      board.pawn_size[1+colour] = pos;

      if (board.piece_size[1+colour] + board.pawn_size[1+colour] > 16) then
        my_fatal("board_init_list(): illegal position\n");
      end
   end

   -- last square

   board.cap_sq = SquareNone;

   -- PST

   board.opening = board_opening(board);
   board.endgame = board_endgame(board);

   -- hash key

   for i = 0, board.ply_nb-1, 1 do
     board.stack[1+i] = 0; -- HACK
   end
   board.sp = board.ply_nb;

   board.key = hash_key(board);
   board.pawn_key = hash_pawn_key(board);
   board.material_key = hash_material_key(board);

   -- legality

   if (not board_is_legal(board)) then
     my_fatal("board_init_list(): illegal position\n");
   end

   -- debug

   --ASSERT(62, board_is_ok(board));
end

-- board_is_legal()

function board_is_legal( board ) -- bool

   --ASSERT(63, board.sp~=nil);

   return (not IS_IN_CHECK(board,COLOUR_OPP(board.turn)));
end

-- board_is_check()

function board_is_check( board ) -- bool

   --ASSERT(64, board.sp~=nil);

   return IS_IN_CHECK(board,board.turn);
end

-- board_is_mate()

function board_is_mate( board ) -- bool

   local attack = attack_t();   -- attack_t[1]

   --ASSERT(65, board.sp~=nil);

   attack_set(attack,board);

   if (not ATTACK_IN_CHECK(attack)) then
     return false; -- not in check => not mate
   end

   if (legal_evasion_exist(board,attack)) then
     return false; -- legal move => not mate
   end

   return true; -- in check and no legal move => mate
end

-- board_is_stalemate()

function board_is_stalemate( board )  -- bool

   local list = list_t();   -- list_t[1];
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(66, board.sp~=nil);

   -- init

   if (IS_IN_CHECK(board,board.turn)) then
     return false; -- in check => not stalemate
   end

   -- move loop

   gen_moves(list,board);

   for i = 0, list.size-1, 1 do
      move = list.move[1+i];
      if (pseudo_is_legal(move,board)) then
        return false; -- legal move => not stalemate
      end
   end

   return true; -- in check and no legal move => mate
end

-- board_is_repetition()

function board_is_repetition( board )  -- bool

   local i = 0;   -- int

   --ASSERT(67, board.sp~=nil);

   -- 50-move rule

   if (board.ply_nb >= 100) then -- potential draw

      if (board.ply_nb > 100) then
        return true;
      end

      --ASSERT(68, board.ply_nb==100);
      return (not board_is_mate(board));
   end

   -- position repetition

   --ASSERT(69, board.sp>=board.ply_nb);

   for i = 4, board.ply_nb-1, 2 do
      if (board.stack[1+board.sp-i] == board.key) then
        return true;
      end
   end

   return false;
end

-- board_opening()

function board_opening( board )  -- int

   local opening = 0;   -- int
   local colour = 0;    -- int
   local ptr = 0;       -- int
   local sq = 0;        -- int
   local piece = 0;     -- int

   --ASSERT(70, board.sp~=nil);

   opening = 0;
   for colour = 0, 1, 1 do

      ptr = 0;
      while(true) do
        sq = board.piece[1+colour][1+ptr];
        if(sq==SquareNone) then
          break;
        end
        piece = board.square[1+sq];
        opening = opening + Pget( PieceTo12[1+piece], SquareTo64[1+sq], Opening );
        ptr = ptr + 1;
      end

      ptr = 0;
      while(true) do
        sq = board.pawn[1+colour][1+ptr];
        if(sq==SquareNone) then
          break;
        end
        piece = board.square[1+sq];
        opening = opening + Pget( PieceTo12[1+piece], SquareTo64[1+sq], Opening );
        ptr = ptr + 1;
      end

   end

   return opening;
end

-- board_endgame()

function board_endgame( board )  -- int

   local endgame = 0;   -- int
   local colour = 0;    -- int
   local ptr = 0;       -- int
   local sq = 0;        -- int
   local piece = 0;     -- int

   --ASSERT(71, board.sp~=nil);

   endgame = 0;
   for colour = 0, 1, 1 do

      ptr = 0;
      while(true) do
        sq = board.piece[1+colour][1+ptr];
        if(sq==SquareNone) then
          break;
        end
        piece = board.square[1+sq];
        endgame = endgame + Pget( PieceTo12[1+piece], SquareTo64[1+sq], Endgame );
        ptr = ptr + 1;
      end

      ptr = 0;
      while(true) do
        sq = board.pawn[1+colour][1+ptr];
        if(sq==SquareNone) then
          break;
        end
        piece = board.square[1+sq];
        endgame = endgame + Pget( PieceTo12[1+piece], SquareTo64[1+sq], Endgame );
        ptr = ptr + 1;
      end

   end

   return endgame;
end

-- end of board.cpp




-- eval.cpp

-- functions

-- eval_init()

function eval_init()

   local colour = 0;   -- int
   local piece = 0;    -- int

   -- UCI options

   PieceActivityWeight = (option_get_int("Piece Activity") * 256 + 50) / 100;
   KingSafetyWeight    = (option_get_int("King Safety")    * 256 + 50) / 100;
   PassedPawnWeight    = (option_get_int("Passed Pawns")   * 256 + 50) / 100;

   -- mobility table

   for colour = 0, 1, 1 do
      MobUnit[1+colour] = {};
      for piece = 0, PieceNb-1, 1 do
         MobUnit[1+colour][1+piece] = 0;
      end
   end

   MobUnit[1+White][1+Empty] = MobMove;

   MobUnit[1+White][1+BP] = MobAttack;
   MobUnit[1+White][1+BN] = MobAttack;
   MobUnit[1+White][1+BB] = MobAttack;
   MobUnit[1+White][1+BR] = MobAttack;
   MobUnit[1+White][1+BQ] = MobAttack;
   MobUnit[1+White][1+BK] = MobAttack;

   MobUnit[1+White][1+WP] = MobDefense;
   MobUnit[1+White][1+WN] = MobDefense;
   MobUnit[1+White][1+WB] = MobDefense;
   MobUnit[1+White][1+WR] = MobDefense;
   MobUnit[1+White][1+WQ] = MobDefense;
   MobUnit[1+White][1+WK] = MobDefense;

   MobUnit[1+Black][1+Empty] = MobMove;

   MobUnit[1+Black][1+WP] = MobAttack;
   MobUnit[1+Black][1+WN] = MobAttack;
   MobUnit[1+Black][1+WB] = MobAttack;
   MobUnit[1+Black][1+WR] = MobAttack;
   MobUnit[1+Black][1+WQ] = MobAttack;
   MobUnit[1+Black][1+WK] = MobAttack;

   MobUnit[1+Black][1+BP] = MobDefense;
   MobUnit[1+Black][1+BN] = MobDefense;
   MobUnit[1+Black][1+BB] = MobDefense;
   MobUnit[1+Black][1+BR] = MobDefense;
   MobUnit[1+Black][1+BQ] = MobDefense;
   MobUnit[1+Black][1+BK] = MobDefense;

   -- KingAttackUnit[]

   for piece = 0, PieceNb-1, 1 do
      KingAttackUnit[1+piece] = 0;
   end

   KingAttackUnit[1+WN] = 1;
   KingAttackUnit[1+WB] = 1;
   KingAttackUnit[1+WR] = 2;
   KingAttackUnit[1+WQ] = 4;

   KingAttackUnit[1+BN] = 1;
   KingAttackUnit[1+BB] = 1;
   KingAttackUnit[1+BR] = 2;
   KingAttackUnit[1+BQ] = 4;
end

function opening_t()
  local b = {};
  b.v = 0;
  return b;
end

function endgame_t()
  local b = {};
  b.v = 0;
  return b;
end

-- evalpos()

function evalpos( board )  -- int

   local opening = opening_t();   -- int
   local endgame = endgame_t();   -- int
   local mat_info = material_info_t();  -- material_info_t[1]
   local pawn_info = pawn_info_t();     -- pawn_info_t[1]
   local mul = { 0, 0 };   -- int[ColourNb]
   local phase = 0;  -- int
   local eval1 = 0;   -- int
   local wb = 0;     -- int
   local bb = 0;     -- int

   --ASSERT(84, board.sp~=nil);

   --ASSERT(85, board_is_legal(board));
   --ASSERT(86, not board_is_check(board)); -- exceptions are extremely rare

   -- material

   material_get_info(mat_info,board);

   opening.v = opening.v + mat_info.opening;
   endgame.v = endgame.v + mat_info.endgame;

   mul[1+White] = mat_info.mul[1+White];
   mul[1+Black] = mat_info.mul[1+Black];

   -- PST

   opening.v = opening.v + board.opening;
   endgame.v = endgame.v + board.endgame;

   -- pawns

   pawn_get_info(pawn_info,board);

   opening.v = opening.v + pawn_info.opening;
   endgame.v = endgame.v + pawn_info.endgame;

   -- draw

   eval_draw(board,mat_info,pawn_info,mul);

   if (mat_info.mul[1+White] < mul[1+White]) then
     mul[1+White] = mat_info.mul[1+White];
   end
   if (mat_info.mul[1+Black] < mul[1+Black]) then
     mul[1+Black] = mat_info.mul[1+Black];
   end

   if (mul[1+White] == 0  and  mul[1+Black] == 0) then
     return ValueDraw;
   end

   -- eval

   eval_piece(board,mat_info,pawn_info,opening,endgame);
   eval_king(board,mat_info,opening,endgame);
   eval_passer(board,pawn_info,opening,endgame);
   eval_pattern(board,opening,endgame);

   -- phase mix

   phase = mat_info.phase;
   eval1 = ((opening.v * (256 - phase)) + (endgame.v * phase)) / 256;

   -- drawish bishop endgames

   if ( bit.band( mat_info.flags, DrawBishopFlag ) ~= 0) then

      wb = board.piece[1+White][1+1];
      --ASSERT(87, PIECE_IS_BISHOP(board.square[1+wb]));

      bb = board.piece[1+Black][1+1];
      --ASSERT(88, PIECE_IS_BISHOP(board.square[1+bb]));

      if (SQUARE_COLOUR(wb) ~= SQUARE_COLOUR(bb)) then
         if (mul[1+White] == 16) then
           mul[1+White] = 8; -- 1/2
         end
         if (mul[1+Black] == 16) then
           mul[1+Black] = 8; -- 1/2
         end
      end
   end

   -- draw bound

   if (eval1 > ValueDraw) then
      eval1 = (eval1 * mul[1+White]) / 16;
   else
      if (eval1 < ValueDraw) then
        eval1 = (eval1 * mul[1+Black]) / 16;
      end
   end

   -- value range

   if (eval1 < -ValueEvalInf) then
     eval1 = -ValueEvalInf;
   end
   if (eval1 > ValueEvalInf) then
     eval1 = ValueEvalInf;
   end

   --ASSERT(89, eval1>=-ValueEvalInf and eval1<=ValueEvalInf);

   -- turn

   if (COLOUR_IS_BLACK(board.turn)) then
     eval1 = -eval1;
   end

   --ASSERT(90, not value_is_mate(eval1));

   return eval1;
end

-- eval_draw()

function eval_draw( board, mat_info, pawn_info, mul ) -- int

   local colour = 0;    -- int
   local me = 0;        -- int
   local opp = 0;       -- int
   local pawn = 0;      -- int
   local king = 0;      -- int
   local pawn_file = 0; -- int
   local prom = 0;      -- int
   local list = {};     -- int list[7+1]
   local ifelse = false;

   --ASSERT(91, board.sp~=nil);
   --ASSERT(92, mat_info.lock~=nil);
   --ASSERT(93, pawn_info.lock~=nil);
   --ASSERT(94, mul[1+0]~=nil);

   -- draw patterns

   for colour = 0, 1, 1 do

      me = colour;
      opp = COLOUR_OPP(me);

      -- KB*P+K* draw

      if ( bit.band( mat_info.cflags[1+me], MatRookPawnFlag ) ~= 0 ) then

         pawn = pawn_info.single_file[1+me];

         if (pawn ~= SquareNone) then   -- all pawns on one file

            pawn_file = SQUARE_FILE(pawn);

            if (pawn_file == FileA  or  pawn_file == FileH) then

               king = KING_POS(board,opp);
               prom = PAWN_PROMOTE(pawn,me);

               if (DISTANCE(king,prom) <= 1  and ( not bishop_can_attack(board,prom,me))) then
                  mul[1+me] = 0;
               end
            end
         end
      end

      -- K(B)P+K+ draw

      if ( bit.band( mat_info.cflags[1+me], MatBishopFlag ) ~= 0) then

         pawn = pawn_info.single_file[1+me];

         if (pawn ~= SquareNone) then   -- all pawns on one file

            king = KING_POS(board,opp);

            if (SQUARE_FILE(king)  == SQUARE_FILE(pawn)
              and  PAWN_RANK(king,me) >  PAWN_RANK(pawn,me)
              and  (not bishop_can_attack(board,king,me))) then
               mul[1+me] = 1;  -- 1/16
            end
         end
      end

      -- KNPK* draw

      if ( bit.band( mat_info.cflags[1+me], MatKnightFlag ) ~= 0 ) then

         pawn = board.pawn[1+me][1+0];
         king = KING_POS(board,opp);

         if (SQUARE_FILE(king)  == SQUARE_FILE(pawn)
           and  PAWN_RANK(king,me) >  PAWN_RANK(pawn,me)
           and  PAWN_RANK(pawn,me) <= Rank6) then
            mul[1+me] = 1;  -- 1/16
         end
      end
   end

   -- recognisers, only heuristic draws herenot

   ifelse = true;

   if (ifelse and mat_info.recog == MAT_KPKQ) then

      -- KPKQ (white)

      draw_init_list(list,board,White);

      if (draw_kpkq(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KQKP) then

      -- KPKQ (black)

      draw_init_list(list,board,Black);

      if (draw_kpkq(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KPKR) then

      -- KPKR (white)

      draw_init_list(list,board,White);

      if (draw_kpkr(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KRKP) then

      -- KPKR (black)

      draw_init_list(list,board,Black);

      if (draw_kpkr(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KPKB) then

      -- KPKB (white)

      draw_init_list(list,board,White);

      if (draw_kpkb(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KBKP) then

      -- KPKB (black)

      draw_init_list(list,board,Black);

      if (draw_kpkb(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KPKN) then

      -- KPKN (white)

      draw_init_list(list,board,White);

      if (draw_kpkn(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KNKP) then

      -- KPKN (black)

      draw_init_list(list,board,Black);

      if (draw_kpkn(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KNPK) then

      -- KNPK (white)

      draw_init_list(list,board,White);

      if (draw_knpk(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KKNP) then

      -- KNPK (black)

      draw_init_list(list,board,Black);

      if (draw_knpk(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KRPKR) then

      -- KRPKR (white)

      draw_init_list(list,board,White);

      if (draw_krpkr(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KRKRP) then

      -- KRPKR (black)

      draw_init_list(list,board,Black);

      if (draw_krpkr(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KBPKB) then

      -- KBPKB (white)

      draw_init_list(list,board,White);

      if (draw_kbpkb(list,board.turn)) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KBKBP) then

      -- KBPKB (black)

      draw_init_list(list,board,Black);

      if (draw_kbpkb(list,COLOUR_OPP(board.turn))) then
         mul[1+White] = 1; -- 1/16;
         mul[1+Black] = 1; -- 1/16;
      end

      ifelse = false;
   end
end

--
function add_line( board, me, from, dx )

 local to = from + dx;
 local capture = 0;
 local mob = 0;

 while(true) do
   capture=board.square[1+to];
   if(capture~=Empty) then
     break;
   end
   mob = mob + MobMove;
   to = to + dx;
 end

 mob = mob + MobUnit[1+me][1+capture];

 return mob;
end


-- eval_piece()

function eval_piece( board, mat_info, pawn_info, opening, endgame )  -- int

   local colour = 0;   -- int
   local op = { 0, 0 };      -- int[ColourNb]
   local eg = { 0, 0 };      -- int[ColourNb]
   local me = 0;       -- int
   local opp = 0;      -- int
   local opp_flag = 0; -- int
   local ptr = 0;      -- int
   local from = 0;     -- int
   local to = 0;       -- int
   local piece = 0;    -- int
   local mob = 0;      -- int
   local capture = 0;  -- int
   local unit = {};     -- int[]
   local rook_file = 0;  -- int
   local king_file = 0;  -- int
   local king = 0;     -- int
   local delta = 0;    -- int
   local ptype = 0;

   --ASSERT(95, board.sp~=nil);
   --ASSERT(96, mat_info.lock~=nil);
   --ASSERT(97, pawn_info.lock~=nil);
   --ASSERT(98, opening.v~=nil);
   --ASSERT(99, endgame~=nil);

   -- eval

   for colour = 0, 1, 1 do

      me = colour;
      opp = COLOUR_OPP(me);

      opp_flag = COLOUR_FLAG(opp);

      unit = MobUnit[1+me];

      -- piece loop

      ptr = 1;            -- HACK: no king
      while(true) do
         from = board.piece[1+me][1+ptr];
         if(from==SquareNone) then
           break;
         end

         piece = board.square[1+from];

         ptype = PIECE_TYPE(piece);

         if(ptype == Knight64) then

            -- mobility

            mob = -KnightUnit;

            mob = mob + unit[1+board.square[1+from-33]];
            mob = mob + unit[1+board.square[1+from-31]];
            mob = mob + unit[1+board.square[1+from-18]];
            mob = mob + unit[1+board.square[1+from-14]];
            mob = mob + unit[1+board.square[1+from+14]];
            mob = mob + unit[1+board.square[1+from+18]];
            mob = mob + unit[1+board.square[1+from+31]];
            mob = mob + unit[1+board.square[1+from+33]];

            op[1+me] = op[1+me] + (mob * KnightMobOpening);
            eg[1+me] = eg[1+me] + (mob * KnightMobEndgame);

         end

         if(ptype == Bishop64) then

            -- mobility

            mob = -BishopUnit;

            mob = mob + add_line( board, me, from, -17 );
            mob = mob + add_line( board, me, from, -15 );
            mob = mob + add_line( board, me, from, 15 );
            mob = mob + add_line( board, me, from, 17 );

            op[1+me] = op[1+me] + (mob * BishopMobOpening);
            eg[1+me] = eg[1+me] + (mob * BishopMobEndgame);

         end

         if(ptype == Rook64) then

            -- mobility

            mob = -RookUnit;

            mob = mob + add_line( board, me, from, -16 );
            mob = mob + add_line( board, me, from, -1 );
            mob = mob + add_line( board, me, from, 1 );
            mob = mob + add_line( board, me, from, 16 );

            op[1+me] = op[1+me] + (mob * RookMobOpening);
            eg[1+me] = eg[1+me] + (mob * RookMobEndgame);

            -- open file

            if (UseOpenFile) then

               op[1+me] = op[1+me] - (RookOpenFileOpening / 2);
               eg[1+me] = eg[1+me] - (RookOpenFileEndgame / 2);


               rook_file = SQUARE_FILE(from);

               if (board.pawn_file[1+me][1+rook_file] == 0) then   -- no friendly pawn

                  op[1+me] = op[1+me] + RookSemiOpenFileOpening;
                  eg[1+me] = eg[1+me] + RookSemiOpenFileEndgame;

                  if (board.pawn_file[1+opp][1+rook_file] == 0) then  -- no enemy pawn

                     op[1+me] = op[1+me] + RookOpenFileOpening - RookSemiOpenFileOpening;
                     eg[1+me] = eg[1+me] + RookOpenFileEndgame - RookSemiOpenFileEndgame;

                  end

                  if ( bit.band( mat_info.cflags[1+opp] , MatKingFlag ) ~= 0) then

                     king = KING_POS(board,opp);
                     king_file = SQUARE_FILE(king);

                     delta = math.abs(rook_file-king_file); -- file distance

                     if (delta <= 1) then
                        op[1+me] = op[1+me] + RookSemiKingFileOpening;
                        if (delta == 0) then
                          op[1+me] = op[1+me] + RookKingFileOpening - RookSemiKingFileOpening;
                        end
                     end
                  end
               end
            end

            -- 7th rank

            if (PAWN_RANK(from,me) == Rank7) then
                  -- if opponent pawn on 7th rank...
               if ( bit.band( pawn_info.flags[1+opp], BackRankFlag ) ~= 0 or
                     PAWN_RANK(KING_POS(board,opp),me) == Rank8) then
                  op[1+me] = op[1+me] + Rook7thOpening;
                  eg[1+me] = eg[1+me] + Rook7thEndgame;
               end
            end

         end

         if(ptype == Queen64) then

            -- mobility

            mob = -QueenUnit;

            mob = mob + add_line( board, me, from, -17 );
            mob = mob + add_line( board, me, from, -16 );
            mob = mob + add_line( board, me, from, -15 );
            mob = mob + add_line( board, me, from, -1 );
            mob = mob + add_line( board, me, from, 1 );
            mob = mob + add_line( board, me, from, 15 );
            mob = mob + add_line( board, me, from, 16 );
            mob = mob + add_line( board, me, from, 17 );


            op[1+me] = op[1+me] + (mob * QueenMobOpening);
            eg[1+me] = eg[1+me] + (mob * QueenMobEndgame);

            -- 7th rank

            if (PAWN_RANK(from,me) == Rank7) then
                  -- if opponent pawn on 7th rank...
               if ( bit.band( pawn_info.flags[1+opp], BackRankFlag ) ~= 0 or
                     PAWN_RANK(KING_POS(board,opp),me) == Rank8) then
                  op[1+me] = op[1+me] + Queen7thOpening;
                  eg[1+me] = eg[1+me] + Queen7thEndgame;
               end
            end

         end

        ptr = ptr + 1;
      end
   end

   -- update

   opening.v = opening.v + ((op[1+White] - op[1+Black]) * PieceActivityWeight) / 256;
   endgame.v = endgame.v + ((eg[1+White] - eg[1+Black]) * PieceActivityWeight) / 256;
end

-- eval_king()

function eval_king( board, mat_info, opening, endgame)  -- int

   local colour = 0;   -- int
   local op = { 0, 0 }; -- int[ColourNb]
   local eg = { 0, 0 }; -- int[ColourNb]
   local me = 0;       -- int
   local opp = 0;      -- int
   local from = 0;     -- int

   local penalty_1 = 0;   -- int
   local penalty_2 = 0;   -- int

   local tmp = 0;       -- int
   local penalty = 0;   -- int

   local king = 0;       -- int
   local ptr = 0;        -- int
   local piece = 0;      -- int
   local attack_tot = 0; -- int
   local piece_nb = 0;   -- int

   --ASSERT(100, board.sp~=nil);
   --ASSERT(101, mat_info.lock~=nil);
   --ASSERT(102, opening.v~=nil);
   --ASSERT(103, endgame.v~=nil);

   -- king attacks

   if (UseKingAttack) then

      for colour = 0, 1, 1 do

         if ( bit.band( mat_info.cflags[1+colour], MatKingFlag ) ~= 0) then

            me = colour;
            opp = COLOUR_OPP(me);

            king = KING_POS(board,me);

            -- piece attacks

            attack_tot = 0;
            piece_nb = 0;

            ptr = 1;        -- HACK: no king
            while(true) do
               from=board.piece[1+opp][1+ptr];
               if(from==SquareNone) then
                 break;
               end

               piece = board.square[1+from];

               if (piece_attack_king(board,piece,from,king)) then
                  piece_nb = piece_nb + 1;
                  attack_tot = attack_tot + KingAttackUnit[1+piece];
               end
               ptr = ptr + 1;
            end

            -- scoring

            --ASSERT(104, piece_nb>=0 and piece_nb<16);
            op[1+colour] = op[1+colour] - (attack_tot * KingAttackOpening * KingAttackWeight[1+piece_nb]) / 256;
         end
      end
   end

   -- white pawn shelter

   if (UseShelter  and  bit.band( mat_info.cflags[1+White], MatKingFlag ) ~= 0) then

      me = White;

      -- king

      penalty_1 = shelter_square(board,KING_POS(board,me),me);

      -- castling

      penalty_2 = penalty_1;

      if ( bit.band( board.flags, FlagsWhiteKingCastle ) ~= 0) then
         tmp = shelter_square(board,G1,me);
         if (tmp < penalty_2) then
           penalty_2 = tmp;
         end
      end

      if ( bit.band( board.flags, FlagsWhiteQueenCastle ) ~= 0) then
         tmp = shelter_square(board,B1,me);
         if (tmp < penalty_2) then
           penalty_2 = tmp;
         end
      end

      --ASSERT(105, penalty_2>=0 and penalty_2<=penalty_1);

      -- penalty

      penalty = (penalty_1 + penalty_2) / 2;
      --ASSERT(106, penalty>=0);

      op[1+me] = op[1+me] - (penalty * ShelterOpening) / 256;
   end

   -- black pawn shelter

   if (UseShelter  and  bit.band( mat_info.cflags[1+Black], MatKingFlag ) ~= 0) then

      me = Black;

      -- king

      penalty_1 = shelter_square(board,KING_POS(board,me),me);

      -- castling

      penalty_2 = penalty_1;

      if ( bit.band( board.flags, FlagsBlackKingCastle ) ~= 0) then
         tmp = shelter_square(board,G8,me);
         if (tmp < penalty_2) then
           penalty_2 = tmp;
         end
      end

      if ( bit.band( board.flags, FlagsBlackQueenCastle ) ~= 0) then
         tmp = shelter_square(board,B8,me);
         if (tmp < penalty_2) then
           penalty_2 = tmp;
         end
      end

      --ASSERT(107, penalty_2>=0 and penalty_2<=penalty_1);

      -- penalty

      penalty = (penalty_1 + penalty_2) / 2;
      --ASSERT(108, penalty>=0);

      op[1+me] = op[1+me] - (penalty * ShelterOpening) / 256;
   end

   -- update

   opening.v = opening.v + ((op[1+White] - op[1+Black]) * KingSafetyWeight) / 256;
   endgame.v = endgame.v + ((eg[1+White] - eg[1+Black]) * KingSafetyWeight) / 256;
end

-- eval_passer()

function eval_passer( board, pawn_info, opening, endgame )  -- int


   local colour = 0;   -- int
   local op = { 0, 0 }; -- int[ColourNb]
   local eg = { 0, 0 }; -- int[ColourNb]
   local att = 0;      -- int
   local def = 0;      -- int
   local bits = 0;     -- int
   local file = 0;     -- int
   local rank = 0;     -- int
   local sq = 0;       -- int
   local min = 0;      -- int
   local max = 0;      -- int
   local delta = 0     -- int

   --ASSERT(109, board.sp~=nil);
   --ASSERT(110, pawn_info.lock~=nil);
   --ASSERT(111, opening~=nil);
   --ASSERT(112, endgame~=nil);


   -- passed pawns

   for colour = 0, 1, 1 do

      att = colour;
      def = COLOUR_OPP(att);
      bits = pawn_info.passed_bits[1+att];
      while(true) do
         if(bits == 0) then
           break;
         end

         file = BitFirst[1+bits];
         --ASSERT(113, file>=FileA and file<=FileH);

         rank = BitLast[1+board.pawn_file[1+att][1+file] ];
         --ASSERT(114, rank>=Rank2 and rank<=Rank7);

         sq = SQUARE_MAKE(file,rank);
         if (COLOUR_IS_BLACK(att)) then
           sq = SQUARE_RANK_MIRROR(sq);
         end

         --ASSERT(115, PIECE_IS_PAWN(board.square[1+sq]));
         --ASSERT(116, COLOUR_IS(board.square[1+sq],att));

         -- opening scoring

         op[1+att] = op[1+att] + quad(PassedOpeningMin,PassedOpeningMax,rank);

         -- endgame scoring init

         min = PassedEndgameMin;
         max = PassedEndgameMax;

         delta = max - min;
         --ASSERT(117, delta>0);

         -- "dangerous" bonus

           -- defender has no piece
         if (board.piece_size[1+def] <= 1
           and  (unstoppable_passer(board,sq,att)  or  king_passer(board,sq,att))) then
            delta = delta + UnstoppablePasser;
         else
           if (free_passer(board,sq,att)) then
            delta = delta + FreePasser;
           end
         end

         -- king-distance bonus

         delta = delta - (pawn_att_dist(sq,KING_POS(board,att),att) * AttackerDistance);
         delta = delta + (pawn_def_dist(sq,KING_POS(board,def),att) * DefenderDistance);

         -- endgame scoring

         eg[1+att] = eg[1+att] + min;
         if (delta > 0) then
           eg[1+att] = eg[1+att] + quad(0,delta,rank);
         end

         bits = bit.band(bits, bits-1);
      end
   end

   -- update

   opening.v = opening.v + ((op[1+White] - op[1+Black]) * PassedPawnWeight) / 256;
   endgame.v = endgame.v + ((eg[1+White] - eg[1+Black]) * PassedPawnWeight) / 256;
end

-- eval_pattern()

function eval_pattern( board, opening, endgame )  -- int

   --ASSERT(118, board.sp~=nil);
   --ASSERT(119, opening.v~=nil);
   --ASSERT(120, endgame.v~=nil);

   -- trapped bishop (7th rank)

   if ((board.square[1+A7] == WB  and  board.square[1+B6] == BP)
     or  (board.square[1+B8] == WB  and  board.square[1+C7] == BP)) then
      opening.v = opening.v - TrappedBishop;
      endgame.v = endgame.v - TrappedBishop;
   end

   if ((board.square[1+H7] == WB  and  board.square[1+G6] == BP)
     or  (board.square[1+G8] == WB  and  board.square[1+F7] == BP)) then
      opening.v = opening.v - TrappedBishop;
      endgame.v = endgame.v - TrappedBishop;
   end

   if ((board.square[1+A2] == BB  and  board.square[1+B3] == WP)
     or  (board.square[1+B1] == BB  and  board.square[1+C2] == WP)) then
      opening.v = opening.v + TrappedBishop;
      endgame.v = endgame.v + TrappedBishop;
   end

   if ((board.square[1+H2] == BB  and  board.square[1+G3] == WP)
     or  (board.square[1+G1] == BB  and  board.square[1+F2] == WP)) then
      opening.v = opening.v + TrappedBishop;
      endgame.v = endgame.v + TrappedBishop;
   end

   -- trapped bishop (6th rank)

   if (board.square[1+A6] == WB  and  board.square[1+B5] == BP) then
      opening.v = opening.v - (TrappedBishop / 2);
      endgame.v = endgame.v - (TrappedBishop / 2);
   end

   if (board.square[1+H6] == WB  and  board.square[1+G5] == BP) then
      opening.v = opening.v - (TrappedBishop / 2);
      endgame.v = endgame.v - (TrappedBishop / 2);
   end

   if (board.square[1+A3] == BB  and  board.square[1+B4] == WP) then
      opening.v = opening.v + (TrappedBishop / 2);
      endgame.v = endgame.v + (TrappedBishop / 2);
   end

   if (board.square[1+H3] == BB  and  board.square[1+G4] == WP) then
      opening.v = opening.v + (TrappedBishop / 2);
      endgame.v = endgame.v + (TrappedBishop / 2);
   end

   -- blocked bishop

   if (board.square[1+D2] == WP  and  board.square[1+D3] ~= Empty  and  board.square[1+C1] == WB) then
      opening.v = opening.v - BlockedBishop;
   end

   if (board.square[1+E2] == WP  and  board.square[1+E3] ~= Empty  and  board.square[1+F1] == WB) then
      opening.v = opening.v - BlockedBishop;
   end

   if (board.square[1+D7] == BP  and  board.square[1+D6] ~= Empty  and  board.square[1+C8] == BB) then
      opening.v = opening.v + BlockedBishop;
   end

   if (board.square[1+E7] == BP  and  board.square[1+E6] ~= Empty  and  board.square[1+F8] == BB) then
      opening.v = opening.v + BlockedBishop;
   end

   -- blocked rook

   if ((board.square[1+C1] == WK  or  board.square[1+B1] == WK)
     and  (board.square[1+A1] == WR  or  board.square[1+A2] == WR  or  board.square[1+B1] == WR)) then
      opening.v = opening.v - BlockedRook;
   end

   if ((board.square[1+F1] == WK  or  board.square[1+G1] == WK)
     and  (board.square[1+H1] == WR  or  board.square[1+H2] == WR  or  board.square[1+G1] == WR)) then
      opening.v = opening.v - BlockedRook;
   end

   if ((board.square[1+C8] == BK  or  board.square[1+B8] == BK)
     and  (board.square[1+A8] == BR  or  board.square[1+A7] == BR  or  board.square[1+B8] == BR)) then
      opening.v = opening.v + BlockedRook;
   end

   if ((board.square[1+F8] == BK  or  board.square[1+G8] == BK)
     and  (board.square[1+H8] == BR  or  board.square[1+H7] == BR  or  board.square[1+G8] == BR)) then
      opening.v = opening.v + BlockedRook;
   end
end

-- unstoppable_passer()

function unstoppable_passer( board, pawn, colour )  -- bool

   local me = 0;     -- int
   local opp = 0;    -- int
   local file = 0;   -- int
   local rank = 0;   -- int
   local king = 0;   -- int
   local prom = 0;   -- int
   local ptr = 0;    -- int
   local sq = 0;     -- int
   local dist = 0;   -- int

   --ASSERT(121, board.sp~=nil);
   --ASSERT(122, SQUARE_IS_OK(pawn));
   --ASSERT(123, COLOUR_IS_OK(colour));

   me = colour;
   opp = COLOUR_OPP(me);

   file = SQUARE_FILE(pawn);
   rank = PAWN_RANK(pawn,me);

   king = KING_POS(board,opp);

   -- clear promotion path?


   ptr = 0;
   while(true) do
      sq=board.piece[1+me][1+ptr];
      if(sq==SquareNone) then
        break;
      end

      if (SQUARE_FILE(sq) == file  and  PAWN_RANK(sq,me) > rank) then
         return false; -- "friendly" blocker
      end
      ptr = ptr + 1;
   end


   -- init

   if (rank == Rank2) then
      pawn = pawn + PawnMoveInc[1+me];
      rank = rank + 1;
      --ASSERT(124, rank==PAWN_RANK(pawn,me));
   end

   --ASSERT(125, rank>=Rank3 and rank<=Rank7);

   prom = PAWN_PROMOTE(pawn,me);

   dist = DISTANCE(pawn,prom);
   --ASSERT(126, dist==Rank8-rank);
   if (board.turn == opp) then
     dist = dist + 1;
   end

   if (DISTANCE(king,prom) > dist) then
     return true; -- not in the square
   end

   return false;
end

-- king_passer()

function king_passer( board, pawn, colour )  -- bool

   local me = 0;     -- int
   local king = 0;   -- int
   local file = 0;   -- int
   local prom = 0;   -- int

   --ASSERT(127, board.sp~=nil);
   --ASSERT(128, SQUARE_IS_OK(pawn));
   --ASSERT(129, COLOUR_IS_OK(colour));

   me = colour;

   king = KING_POS(board,me);
   file = SQUARE_FILE(pawn);
   prom = PAWN_PROMOTE(pawn,me);

   if (DISTANCE(king,prom) <= 1
     and  DISTANCE(king,pawn) <= 1
     and  (SQUARE_FILE(king) ~= file
      or  (file ~= FileA  and  file ~= FileH))) then
      return true;
   end

   return false;
end

-- free_passer()

function free_passer( board, pawn, colour )  -- bool

   local me = 0;    -- int
   local opp = 0;   -- int
   local inc = 0;   -- int
   local sq = 0;    -- int
   local move = 0;  -- int

   --ASSERT(130, board.sp~=nil);
   --ASSERT(131, SQUARE_IS_OK(pawn));
   --ASSERT(132, COLOUR_IS_OK(colour));

   me = colour;
   opp = COLOUR_OPP(me);

   inc = PawnMoveInc[1+me];
   sq = pawn + inc;
   --ASSERT(133, SQUARE_IS_OK(sq));

   if (board.square[1+sq] ~= Empty) then
     return false;
   end

   move = MOVE_MAKE(pawn,sq);
   if (see_move(move,board) < 0) then
     return false;
   end

   return true;
end

-- pawn_att_dist()

function pawn_att_dist( pawn, king, colour )  -- int

   local me = 0;      -- int
   local inc = 0;     -- int
   local target = 0;  -- int

   --ASSERT(134, SQUARE_IS_OK(pawn));
   --ASSERT(135, SQUARE_IS_OK(king));
   --ASSERT(136, COLOUR_IS_OK(colour));

   me = colour;
   inc = PawnMoveInc[1+me];

   target = pawn + inc;

   return DISTANCE(king,target);
end

-- pawn_def_dist()

function pawn_def_dist( pawn, king, colour )  -- int

   local me = 0;      -- int
   local inc = 0;     -- int
   local target = 0;  -- int

   --ASSERT(137, SQUARE_IS_OK(pawn));
   --ASSERT(138, SQUARE_IS_OK(king));
   --ASSERT(139, COLOUR_IS_OK(colour));

   me = colour;
   inc = PawnMoveInc[1+me];

   target = pawn + inc;

   return DISTANCE(king,target);
end

-- draw_init_list()

function draw_init_list( list, board, pawn_colour )  -- int

   local pos = 0;   -- int
   local att = 0;   -- int
   local def = 0;   -- int
   local ptr = 0;   -- int
   local sq = 0;    -- int
   local pawn = 0;  -- int
   local i = 0;     -- int

   --ASSERT(141, board.sp~=nil);
   --ASSERT(142, COLOUR_IS_OK(pawn_colour));

   -- init

   pos = 0;

   att = pawn_colour;
   def = COLOUR_OPP(att);

   --ASSERT(143, board.pawn_size[1+att]==1);
   --ASSERT(144, board.pawn_size[1+def]==0);

   -- att

   ptr = 0;
   while(true) do
      sq=board.piece[1+att][1+ptr];
      if(sq==SquareNone) then
        break;
      end
      list[1+pos] = sq;
      pos = pos + 1;
      ptr = ptr + 1;
   end

   ptr = 0;
   while(true) do
      sq=board.pawn[1+att][1+ptr];
      if(sq==SquareNone) then
        break;
      end
      list[1+pos] = sq;
      pos = pos + 1;
      ptr = ptr + 1;
   end

   -- def

   ptr = 0;
   while(true) do
      sq=board.piece[1+def][1+ptr];
      if(sq==SquareNone) then
        break;
      end
      list[1+pos] = sq;
      pos = pos + 1;
      ptr = ptr + 1;
   end

   ptr = 0;
   while(true) do
      sq=board.pawn[1+def][1+ptr];
      if(sq==SquareNone) then
        break;
      end
      list[1+pos] = sq;
      pos = pos + 1;
      ptr = ptr + 1;
   end


   -- end marker

   --ASSERT(145, pos==board.piece_nb);

   list[1+pos] = SquareNone;

   -- file flip?

   pawn = board.pawn[1+att][1+0];

   if (SQUARE_FILE(pawn) >= FileE) then
      for i = 0, pos-1, 1 do
         list[1+i] = SQUARE_FILE_MIRROR(list[1+i]);
      end
   end

   -- rank flip?

   if (COLOUR_IS_BLACK(pawn_colour)) then
      for i = 0, pos-1, 1 do
         list[1+i] = SQUARE_RANK_MIRROR(list[1+i]);
      end
   end
end

-- draw_kpkq()

function draw_kpkq( list, turn )  -- bool

   local wk = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local bq = 0;       -- int
   local prom = 0;     -- int
   local dist = 0;     -- int
   local wp_file = 0;  -- int
   local wp_rank = 0;  -- int
   local ifelse = false;

   --ASSERT(146, list[1+0]~=nil);
   --ASSERT(147, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(148, SQUARE_IS_OK(wk));

   wp = list[1+1];
   --ASSERT(149, SQUARE_IS_OK(wp));
   --ASSERT(150, SQUARE_FILE(wp)<=FileD);

   bk =  list[1+2];
   --ASSERT(151, SQUARE_IS_OK(bk));

   bq =  list[1+3];
   --ASSERT(152, SQUARE_IS_OK(bq));

   --ASSERT(153, list[1+4]==SquareNone);

   -- test

   if (wp == A7) then

      prom = A8;
      dist = 4;

      if (wk == B7  or  wk == B8) then  -- best case
         if (COLOUR_IS_WHITE(turn)) then
           dist = dist - 1;
         end
      else
       if (wk == A8  or ((wk == C7  or  wk == C8)  and  bq ~= A8)) then    -- white loses a tempo
         if (COLOUR_IS_BLACK(turn)  and  SQUARE_FILE(bq) ~= FileB) then
           return false;
         end
       else
         return false;
       end
      end

      --ASSERT(154, bq~=prom);
      if (DISTANCE(bk,prom) > dist) then
        return true;
      end
   else
    if (wp == C7) then

      prom = C8;
      dist = 4;

      ifelse = true;
      if (ifelse and wk == C8) then     -- dist = 0

         dist = dist + 1; -- self-blocking penalty
         if (COLOUR_IS_WHITE(turn)) then
           dist = dist - 1; -- right-to-move bonus
         end

         ifelse = false;
      end
      if (ifelse and (wk == B7  or  wk == B8)) then -- dist = 1, right side

         dist = dist - 1; -- right-side bonus
         if (DELTA_INC_LINE(wp-bq) == wk-wp) then
           dist = dist + 1; -- pinned-pawn penalty
         end
         if (COLOUR_IS_WHITE(turn)) then
           dist = dist - 1; -- right-to-move bonus
         end

         ifelse = false;
      end

      if (ifelse and (wk == D7  or  wk == D8)) then -- dist = 1, wrong side

         if (DELTA_INC_LINE(wp-bq) == wk-wp) then
           dist = dist + 1; -- pinned-pawn penalty
         end
         if (COLOUR_IS_WHITE(turn)) then
           dist = dist - 1; -- right-to-move bonus
         end

         ifelse = false;
      end

      if (ifelse and ((wk == A7  or  wk == A8)  and  bq ~= C8)) then  -- dist = 2, right side

         if (COLOUR_IS_BLACK(turn)  and  SQUARE_FILE(bq) ~= FileB) then
           return false;
         end

         dist = dist - 1; -- right-side bonus

         ifelse = false;
      end

      if (ifelse and ((wk == E7  or  wk == E8)  and  bq ~= C8)) then -- dist = 2, wrong side

         if (COLOUR_IS_BLACK(turn)  and  SQUARE_FILE(bq) ~= FileD) then
           return false;
         end

         ifelse = false;
      end
      if (ifelse) then
         return false;
      end

      --ASSERT(155, bq~=prom);
      if (DISTANCE(bk,prom) > dist) then
         return true;
      end
   end
  end

   return false;
end

-- draw_kpkr()

function draw_kpkr( list, turn )  -- bool

   local wk = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local br = 0;       -- int
   local inc = 0;      -- int
   local prom = 0;     -- int
   local dist = 0;     -- int
   local wk_file = 0;  -- int
   local wk_rank = 0;  -- int
   local wp_file = 0;  -- int
   local wp_rank = 0;  -- int
   local br_file = 0;  -- int
   local br_rank = 0;  -- int


   --ASSERT(156, list[1+0]~=nil);
   --ASSERT(157, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(158, SQUARE_IS_OK(wk));

   wp = list[1+1];
   --ASSERT(159, SQUARE_IS_OK(wp));
   --ASSERT(160, SQUARE_FILE(wp)<=FileD);

   bk = list[1+2];
   --ASSERT(161, SQUARE_IS_OK(bk));

   br = list[1+3];
   --ASSERT(162, SQUARE_IS_OK(br));

   --ASSERT(163, list[1+4]==SquareNone);

   -- init

   wk_file = SQUARE_FILE(wk);
   wk_rank = SQUARE_RANK(wk);

   wp_file = SQUARE_FILE(wp);
   wp_rank = SQUARE_RANK(wp);

   br_file = SQUARE_FILE(br);
   br_rank = SQUARE_RANK(br);

   inc = PawnMoveInc[1+White];
   prom = PAWN_PROMOTE(wp,White);

   -- conditions

   if (DISTANCE(wk,wp) == 1) then

      --ASSERT(164, math.abs(wk_file-wp_file)<=1);
      --ASSERT(165, math.abs(wk_rank-wp_rank)<=1);

      -- no-op

   else
    if (DISTANCE(wk,wp) == 2  and  math.abs(wk_rank-wp_rank) <= 1) then

      --ASSERT(166, math.abs(wk_file-wp_file)==2);
      --ASSERT(167, math.abs(wk_rank-wp_rank)<=1);

      if (COLOUR_IS_BLACK(turn)  and  br_file ~= (wk_file + wp_file) / 2) then
        return false;
      end
    else
      return false;
    end
   end

   -- white features

   dist = DISTANCE(wk,prom) + DISTANCE(wp,prom);
   if (wk == prom) then
     dist = dist + 1;
   end

   if (wk == wp+inc) then  -- king on pawn's "front square"
      if (wp_file == FileA) then
        return false;
      end
      dist = dist + 1; -- self-blocking penalty
   end

   -- black features

   if (br_file ~= wp_file  and  br_rank ~= Rank8) then
      dist = dist - 1; -- misplaced-rook bonus
   end

   -- test

   if (COLOUR_IS_WHITE(turn)) then
      dist = dist - 1; -- right-to-move bonus
   end

   if (DISTANCE(bk,prom) > dist) then
      return true;
   end

   return false;
end

-- draw_kpkb()

function draw_kpkb( list, turn )  -- bool

   local wk = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local bb = 0;       -- int
   local inc = 0;      -- int
   local en2 = 0;      -- int
   local to = 0;       -- int
   local delta = 0;    -- int
   local inc_2 = 0;    -- int
   local sq = 0;       -- int


   --ASSERT(168, list[1+0]~=nil);
   --ASSERT(169, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(170, SQUARE_IS_OK(wk));

   wp = list[1+1];
   --ASSERT(171, SQUARE_IS_OK(wp));
   --ASSERT(172, SQUARE_FILE(wp)<=FileD);

   bk = list[1+2];
   --ASSERT(173, SQUARE_IS_OK(bk));

   bb = list[1+3];
   --ASSERT(174, SQUARE_IS_OK(bb));

   --ASSERT(175, list[1+4]==SquareNone);

   -- blocked pawn?

   inc = PawnMoveInc[1+White];
   en2 = PAWN_PROMOTE(wp,White) + inc;

   to = wp+inc;
   while(to ~= en2) do

      --ASSERT(176, SQUARE_IS_OK(to));

      if (to == bb) then
        return true; -- direct blockade
      end

      delta = to - bb;
      --ASSERT(177, delta_is_ok(delta));

      if (PSEUDO_ATTACK(BB,delta)) then

         inc_2 = DELTA_INC_ALL(delta);
         --ASSERT(178, inc_2~=IncNone);

         sq = bb;
         while(true) do

            sq = sq + inc_2;
            --ASSERT(179, SQUARE_IS_OK(sq));
            --ASSERT(180, sq~=wk);
            --ASSERT(181, sq~=wp);
            --ASSERT(182, sq~=bb);
            if (sq == to) then
              return true; -- indirect blockade
            end
            if(sq == bk) then
              break;
            end

         end
      end
     to = to + inc;
   end

   return false;
end

-- draw_kpkn()

function draw_kpkn( list, turn )  -- bool

   local wk = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local bn = 0;       -- int
   local inc = 0;      -- int
   local en2 = 0;      -- int
   local file = 0;     -- int
   local sq = 0;       -- int


   --ASSERT(183, list[1+0]~=nil);
   --ASSERT(184, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(185, SQUARE_IS_OK(wk));

   wp = list[1+1];
   --ASSERT(186, SQUARE_IS_OK(wp));
   --ASSERT(187, SQUARE_FILE(wp)<=FileD);

   bk = list[1+2];
   --ASSERT(188, SQUARE_IS_OK(bk));

   bn = list[1+3];
   --ASSERT(189, SQUARE_IS_OK(bn));

   --ASSERT(190, list[1+4]==SquareNone);

   -- blocked pawn?

   inc = PawnMoveInc[1+White];
   en2 = PAWN_PROMOTE(wp,White) + inc;

   file = SQUARE_FILE(wp);
   if (file == FileA  or  file == FileH) then
     en2 = en2 - inc;
   end

   sq = wp+inc;
   while(sq ~= en2) do

      --ASSERT(191, SQUARE_IS_OK(sq));

      if (sq == bn  or  PSEUDO_ATTACK(BN,sq-bn)) then
        return true; -- blockade
      end

      sq = sq + inc;
   end

   return false;
end

-- draw_knpk()

function draw_knpk( list, turn )  -- bool

   local wk = 0;       -- int
   local wn = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int


   --ASSERT(192, list[1+0]~=nil);
   --ASSERT(193, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(194, SQUARE_IS_OK(wk));

   wn = list[1+1];
   --ASSERT(195, SQUARE_IS_OK(wn));

   wp = list[1+2];
   --ASSERT(196, SQUARE_IS_OK(wp));
   --ASSERT(197, SQUARE_FILE(wp)<=FileD);

   bk = list[1+3];
   --ASSERT(198, SQUARE_IS_OK(bk));

   --ASSERT(199, list[1+4]==SquareNone);

   -- test

   if (wp == A7  and  DISTANCE(bk,A8) <= 1) then
     return true;
   end

   return false;
end

-- draw_krpkr()

function draw_krpkr( list, turn )  -- bool

   local wk = 0;       -- int
   local wr = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local br = 0;       -- int

   local wp_file = 0;  -- int
   local wp_rank = 0;  -- int
   local bk_file = 0;  -- int
   local bk_rank = 0;  -- int
   local br_file = 0;  -- int
   local br_rank = 0;  -- int

   local prom = 0;     -- int

   --ASSERT(200, list[1+0]~=nil);
   --ASSERT(201, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(202, SQUARE_IS_OK(wk));

   wr = list[1+1];
   --ASSERT(203, SQUARE_IS_OK(wr));

   wp = list[1+2];
   --ASSERT(204, SQUARE_IS_OK(wp));
   --ASSERT(205, SQUARE_FILE(wp)<=FileD);

   bk = list[1+3];
   --ASSERT(206, SQUARE_IS_OK(bk));

   br = list[1+4];
   --ASSERT(207, SQUARE_IS_OK(br));

   --ASSERT(208, list[1+5]==SquareNone);

   -- test

   wp_file = SQUARE_FILE(wp);
   wp_rank = SQUARE_RANK(wp);

   bk_file = SQUARE_FILE(bk);
   bk_rank = SQUARE_RANK(bk);

   br_file = SQUARE_FILE(br);
   br_rank = SQUARE_RANK(br);

   prom = PAWN_PROMOTE(wp,White);

   if (bk == prom) then

      -- TODO: rook near Rank1 if wp_rank == Rank6?

      if (br_file > wp_file) then
        return true;
      end

   else
    if (bk_file == wp_file  and  bk_rank > wp_rank) then

      return true;

    else
     if (wr == prom  and  wp_rank == Rank7  and  (bk == G7  or  bk == H7)  and  br_file == wp_file) then

      if (br_rank <= Rank3) then
         if (DISTANCE(wk,wp) > 1) then
           return true;
         end
      else -- br_rank >= Rank4
         if (DISTANCE(wk,wp) > 2) then
           return true;
         end
      end
     end
    end
   end

   return false;
end

-- draw_kbpkb()

function draw_kbpkb( list, turn )  -- bool

   local wk = 0;       -- int
   local wb = 0;       -- int
   local wp = 0;       -- int
   local bk = 0;       -- int
   local bb = 0;       -- int

   local inc = 0;      -- int
   local en2 = 0;      -- int
   local to = 0;       -- int
   local delta = 0;    -- int
   local inc_2 = 0;    -- int
   local sq = 0;       -- int


   --ASSERT(209, list[1+0]~=nil);
   --ASSERT(210, COLOUR_IS_OK(turn));

   -- load

   wk = list[1+0];
   --ASSERT(211, SQUARE_IS_OK(wk));

   wb = list[1+1];
   --ASSERT(212, SQUARE_IS_OK(wb));

   wp = list[1+2];
   --ASSERT(213, SQUARE_IS_OK(wp));
   --ASSERT(214, SQUARE_FILE(wp)<=FileD);

   bk = list[1+3];
   --ASSERT(215, SQUARE_IS_OK(bk));

   bb = list[1+4];
   --ASSERT(216, SQUARE_IS_OK(bb));

   --ASSERT(217, list[1+5]==SquareNone);

   -- opposit colour?

   if (SQUARE_COLOUR(wb) == SQUARE_COLOUR(bb)) then
     return false; -- TODO
   end

   -- blocked pawn?

   inc = PawnMoveInc[1+White];
   en2 = PAWN_PROMOTE(wp,White) + inc;

   to = wp+inc;
   while( to ~= en2 ) do

      --ASSERT(218, SQUARE_IS_OK(to));

      if (to == bb) then
        return true; -- direct blockade
      end

      delta = to - bb;
      --ASSERT(219, delta_is_ok(delta));

      if (PSEUDO_ATTACK(BB,delta)) then

         inc_2 = DELTA_INC_ALL(delta);
         --ASSERT(220, inc_2~=IncNone);

         sq = bb;
         while(true) do
            sq = sq + inc_2;
            --ASSERT(221, SQUARE_IS_OK(sq));
            --ASSERT(222, sq~=wk);
            --ASSERT(223, sq~=wb);
            --ASSERT(224, sq~=wp);
            --ASSERT(225, sq~=bb);
            if (sq == to) then
              return true; -- indirect blockade
            end
            if (sq == bk) then
              break;
            end
         end
      end
      to = to + inc;
   end

   return false;
end

-- shelter_square()

function shelter_square( board, square, colour )  -- int

   local penalty = 0;   -- int
   local file = 0;      -- int
   local rank = 0;      -- int

   --ASSERT(226, board.sp~=nil);
   --ASSERT(227, SQUARE_IS_OK(square));
   --ASSERT(228, COLOUR_IS_OK(colour));

   penalty = 0;

   file = SQUARE_FILE(square);
   rank = PAWN_RANK(square,colour);

   penalty = penalty + ( shelter_file(board,file,rank,colour) * 2 );
   if (file ~= FileA) then
     penalty = penalty + shelter_file(board,file-1,rank,colour);
   end
   if (file ~= FileH) then
     penalty = penalty + shelter_file(board,file+1,rank,colour);
   end

   if (penalty == 0) then
     penalty = 11; -- weak back rank
   end

   if (UseStorm) then
      penalty = penalty + storm_file(board,file,colour);
      if (file ~= FileA) then
        penalty = penalty + storm_file(board,file-1,colour);
      end
      if (file ~= FileH) then
        penalty = penalty + storm_file(board,file+1,colour);
      end
   end

   return penalty;
end

-- shelter_file()

function shelter_file( board, file, rank, colour )  -- int

   local dist = 0;      -- int
   local penalty = 0;   -- int

   --ASSERT(229, board.sp~=nil);
   --ASSERT(230, file>=FileA and file<=FileH);
   --ASSERT(231, rank>=Rank1 and rank<=Rank8);
   --ASSERT(232, COLOUR_IS_OK(colour));

   dist = BitFirst[1+ bit.band( board.pawn_file[1+colour][1+file], BitGE[1+rank]) ];
   --ASSERT(233, dist>=Rank2 and dist<=Rank8);

   dist = Rank8 - dist;
   --ASSERT(234, dist>=0 and dist<=6);

   penalty = 36 - (dist * dist);
   --ASSERT(235, penalty>=0 and penalty<=36);

   return penalty;
end

-- storm_file()

function storm_file( board, file, colour )  -- int

   local dist = 0;      -- int
   local penalty = 0;   -- int

   --ASSERT(236, board.sp~=nil);
   --ASSERT(237, file>=FileA and file<=FileH);
   --ASSERT(238, COLOUR_IS_OK(colour));

   dist = BitLast[1+board.pawn_file[1+COLOUR_OPP(colour)][1+file] ];
   --ASSERT(239, dist>=Rank1 and dist<=Rank7);

   penalty = 0;

   if(dist == Rank4) then
      penalty = StormOpening * 1;
   else
    if(dist == Rank5) then
      penalty = StormOpening * 3;
    else
     if(dist == Rank6) then
      penalty = StormOpening * 6;
     end
    end
   end

   return penalty;
end

-- bishop_can_attack()

function bishop_can_attack( board, to, colour )  -- bool

   local ptr = 0;    -- int
   local from = 0;   -- int
   local piece = 0;  -- int

   --ASSERT(240, board.sp~=nil);
   --ASSERT(241, SQUARE_IS_OK(to));
   --ASSERT(242, COLOUR_IS_OK(colour));

   ptr = 1;                -- HACK: no king
   while(true) do
      from = board.piece[1+colour][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      if (PIECE_IS_BISHOP(piece)  and  SQUARE_COLOUR(from) == SQUARE_COLOUR(to)) then
         return true;
      end
      ptr = ptr + 1;
   end

   return false;
end

-- end of eval.cpp



-- fen.cpp

-- functions

function if_fen_err( logic, fenstr, pos )
 if(logic) then
  my_fatal("board_from_fen(): bad FEN " .. fenstr .. " at pos=" .. string.format("%d",pos) .. " \n");
 end
end

-- board_from_fen()

function board_from_fen( board, fenstr ) -- void

   local pos = 0;   -- int
   local file = 0;  -- int
   local rank = 0;  -- int
   local sq = 0;    -- int
   local c = " ";   -- char
   local nb = "";   -- string
   local i = 0;     -- int
   local len = 0;   -- int
   local piece = 0; -- int
   local pawn = 0;  -- int
   local fen = {};  -- char[]
   local gotoupdate = false;

   --ASSERT(243, board.sp~=nil);
   --ASSERT(244, fen~=nil);

   board_clear(board);

   for i = 0, string.len( fenstr ), 1 do
     fen[1+i] = string.sub( fenstr, 1+i, 1+i );
   end

   pos = 0;
   c = fen[1+pos];

   -- piece placement

   for rank = Rank8, Rank1, -1 do

      file = FileA;
      while ( file <= FileH ) do

         if (c >= "1"  and  c <= "8") then            -- empty square(s)

            len = (string.byte(c,1) - string.byte("0",1));

            for i = 0, len-1, 1 do
               if_fen_err( file > FileH, fenstr, pos );

               board.square[1+SQUARE_MAKE(file,rank)] = Empty;
               file = file + 1;
            end

         else    -- piece

            piece = piece_from_char(c);
            if_fen_err( piece == PieceNone256, fenstr, pos );

            board.square[1+SQUARE_MAKE(file,rank)] = piece;
            file = file + 1;
         end

         pos = pos + 1;
         c = fen[1+pos];
      end

      if (rank > Rank1) then
         if_fen_err( c ~= "/", fenstr, pos );
         pos = pos + 1;
         c = fen[1+pos];

      end
   end

   -- active colour

   if_fen_err( c ~= " ", fenstr, pos );

   pos = pos + 1;
   c = fen[1+pos];

   if(c=="w") then
      board.turn = White;
   else
    if(c=="b") then
      board.turn = Black;
    else
      if_fen_err( true, fenstr, pos );
    end
   end

   pos = pos + 1;
   c = fen[1+pos];

   -- castling

   if_fen_err( c ~= " ", fenstr, pos );

   pos = pos + 1;
   c = fen[1+pos];

   board.flags = FlagsNone;

   if (c == "-") then    -- no castling rights

      pos = pos + 1;
      c = fen[1+pos];

   else


      if (c == "K") then
         if (board.square[1+E1] == WK  and  board.square[1+H1] == WR) then
            board.flags = bit.bor( board.flags, FlagsWhiteKingCastle );
         end
         pos = pos + 1;
         c = fen[1+pos];
      end

      if (c == "Q") then
         if (board.square[1+E1] == WK  and  board.square[1+A1] == WR) then
           board.flags = bit.bor( board.flags, FlagsWhiteQueenCastle );
         end
         pos = pos + 1;
         c = fen[1+pos];
      end

      if (c == "k") then
         if (board.square[1+E8] == BK  and  board.square[1+H8] == BR) then
           board.flags = bit.bor( board.flags, FlagsBlackKingCastle );
         end
         pos = pos + 1;
         c = fen[1+pos];
      end

      if (c == "q") then
         if (board.square[1+E8] == BK  and  board.square[1+A8] == BR) then
           board.flags = bit.bor( board.flags, FlagsBlackQueenCastle );
         end
         pos = pos + 1;
         c = fen[1+pos];
      end
   end

   -- en-passant

   if_fen_err( c ~= " ", fenstr, pos );

   pos = pos + 1;
   c = fen[1+pos];

   if (c == "-") then   -- no en-passant

      sq = SquareNone;
      pos = pos + 1;
      c = fen[1+pos];

   else

      if_fen_err( c < "a"  or  c > "h", fenstr, pos );
      file = file_from_char(c);
      pos = pos + 1;
      c = fen[1+pos];

      if_fen_err( c ~= iif(COLOUR_IS_WHITE(board.turn) , "6" , "3"), fenstr, pos );

      rank = rank_from_char(c);
      pos = pos + 1;
      c = fen[1+pos];

      sq = SQUARE_MAKE(file,rank);
      pawn = SQUARE_EP_DUAL(sq);

      if (board.square[1+sq] ~= Empty
        or  board.square[1+pawn] ~= PawnMake[1+COLOUR_OPP(board.turn)]
        or  (board.square[1+pawn-1] ~= PawnMake[1+board.turn]
         and  board.square[1+pawn+1] ~= PawnMake[1+board.turn])) then
         sq = SquareNone;
      end
   end

   board.ep_square = sq;

   -- halfmove clock

   board.ply_nb = 0;
   board.movenumb = 0;

   if (c ~= " ") then
      if (not Strict) then
        gotoupdate = true;
      else
        if_fen_err( true, fenstr, pos );
      end
   end

   if( not gotoupdate ) then
     pos = pos + 1;
     c = fen[1+pos];

     if (c<"0" or c>"9") then
        if (not Strict) then
          gotoupdate = true;
        else
          if_fen_err( true, fenstr, pos );
        end
     end
   end

   if( not gotoupdate ) then
      nb = str_after_ok( string.sub( fenstr, 1+pos ), " ");  -- ignore halfmove clock
      board.ply_nb = tonumber( nb );
      board.movenumb = board.ply_nb;  -- just save it
   end

   -- board update

   -- update:
   board_init_list(board);
end

-- board_to_fen()

function board_to_fen( board, strfen )  -- bool

   local file = 0;   -- int
   local rank = 0;   -- int
   local sq = 0;     -- int
   local piece = 0;  -- int
   local c = " ";    -- string
   local len = 0;    -- int
   local fen = "";   -- string
   local str1 = string_t()

   --ASSERT(245, board.sp~=nil);

   -- piece placement

   for rank = Rank8, Rank1, -1 do

      file = FileA;
      while( file <= FileH ) do

         sq = SQUARE_MAKE(file,rank);
         piece = board.square[1+sq];
         --ASSERT(248, piece==Empty or piece_is_ok(piece));

         if (piece == Empty) then

            len = 0;
            while( file <= FileH  and  board.square[1+SQUARE_MAKE(file,rank)] == Empty ) do

               file = file + 1;
               len = len + 1;
            end

            --ASSERT(249, len>=1 and len<=8);
            c = string.format( "%c", string.byte("0",1) + len );

         else

            c = piece_to_char(piece);
            file = file + 1;
         end

         fen = fen .. c;

      end

      if( rank ~= Rank1 ) then
        fen = fen .. "/";
      end
   end

   -- active colour

   fen = fen .. " " .. iif(COLOUR_IS_WHITE(board.turn) , "w", "b" ) .. " ";

   -- castling

   if (board.flags == FlagsNone) then
      fen = fen .. "-";
   else
      if ( bit.band( board.flags, FlagsWhiteKingCastle) ~= 0) then
        fen = fen .. "K";
      end
      if ( bit.band( board.flags, FlagsWhiteQueenCastle) ~= 0) then
        fen = fen .. "Q";
      end
      if ( bit.band( board.flags, FlagsBlackKingCastle) ~= 0) then
        fen = fen .. "k";
      end
      if ( bit.band( board.flags, FlagsBlackQueenCastle) ~= 0) then
        fen = fen .. "q";
      end
   end

   fen = fen .. " ";

   -- en-passant

   if (board.ep_square == SquareNone) then
      fen = fen .. "-";
   else
      square_to_string(board.ep_square, str1 );
      fen = fen .. str1.v;
   end

   fen = fen .. " ";

   -- ignoring halfmove clock

   fen = fen .. "0 " .. string.format("%d",board.movenumb );

   strfen.v = fen;

   return true;
end

-- to see on screen

function printboard() -- void

   local file = 0;   -- int
   local rank = 0;   -- int
   local sq = 0;     -- int
   local piece = 0;  -- int
   local str1 = string_t();
   local s = "";     --  string
   local board = SearchInput.board;

   -- piece placement

   for rank = Rank8, Rank1, -1 do

      file = FileA;
      while( file <= FileH ) do

         sq = SQUARE_MAKE(file,rank);
         piece = board.square[1+sq];
         --ASSERT(248, piece==Empty or piece_is_ok(piece));

         if(piece == Empty) then
           s = s .. ".";
         else
           s = s .. piece_to_char(piece);
         end
		 s = s .. " ";

         file = file + 1;
      end

      s = s .. "\n";
   end

   board_to_fen( board, str1 );

   s = s .. str1.v .. "\n";

   print(s);

end

-- end of fen.cpp


-- hash.cpp

-- 64-bit functions for 32-bit reality, we accept collisions for slower interpreter


-- functions

-- hash_init()

function hash_init()

   local i = 0;   -- int

   for i = 0, 15, 1 do
     Castle64[1+i] = hash_castle_key(i);
   end
end

-- hash_key()

function hash_key( board )    -- uint64
   local key = 0     -- uint64;
   local colour = 0; -- int
   local ptr = 0;    -- int
   local sq = 0;     -- int
   local piece = 0;  -- int

   --ASSERT(250, board.sp~=nil);

   -- init

   key = 0;

   -- pieces

   for colour = 0, 1, 1 do

      ptr = 0;
      while(true) do
         sq=board.piece[1+colour][1+ptr];
         if(sq== SquareNone) then
           break;
         end

         piece = board.square[1+sq];
         key = bit.bxor( key, hash_piece_key(piece,sq) );

         ptr = ptr + 1;
      end


      ptr = 0;
      while(true) do
         sq=board.pawn[1+colour][1+ptr];
         if(sq== SquareNone) then
           break;
         end

         piece = board.square[1+sq];
         key = bit.bxor( key, hash_piece_key(piece,sq) );

         ptr = ptr + 1;
      end

   end

   -- castle flags

   key = bit.bxor( key, hash_castle_key(board.flags) );

   -- en-passant square

   sq = board.ep_square;
   if (sq ~= SquareNone) then
      key = bit.bxor( key, hash_ep_key(sq) );
   end

   -- turn

   key = bit.bxor( key, hash_turn_key(board.turn) );

   return key;
end

-- hash_pawn_key()

function hash_pawn_key( board ) -- uint64

   local key = 0     -- uint64;
   local colour = 0; -- int
   local ptr = 0;    -- int
   local sq = 0;     -- int
   local piece = 0;  -- int

   --ASSERT(251, board.sp~=nil);

   -- init

   key = 0;

   -- pawns

   for colour = 0, 1, 1 do

      ptr = 0;
      while(true) do
         sq=board.pawn[1+colour][1+ptr];
         if(sq== SquareNone) then
           break;
         end

         piece = board.square[1+sq];
         key = bit.bxor( key, hash_piece_key(piece,sq) );

         ptr = ptr + 1;
      end

   end

   return key;
end

-- hash_material_key()

function hash_material_key( board ) -- uint64

   local key = 0     -- uint64;
   local piece = 0;  -- int
   local count = 0;  -- int

   --ASSERT(252, board.sp~=nil);

   -- init

   key = 0;

   -- counters

   for piece_12 = 0, 11, 1 do
      count = board.number[1+piece_12];
      key = bit.bxor( key, hash_counter_key(piece_12,count) );
   end

   return key;

end

-- hash_piece_key()

function hash_piece_key( piece, square )  -- uint64

   --ASSERT(253, piece_is_ok(piece));
   --ASSERT(254, SQUARE_IS_OK(square));

   return Random64[1+RandomPiece+bit.bxor(PieceTo12[1+piece],1)*64 + SquareTo64[1+square] ];
             -- HACK: xor 1 for PolyGlot book (not lua)
end

-- hash_castle_key()

function hash_castle_key( flags )  -- uint64

   local key = 0     -- uint64;
   local i = 0;      -- int

   --ASSERT(255, bit.band(flags,bnotF)==0);

   key = 0;

   for i = 0, 3, 1 do
      if ( bit.band( flags, bit.lshift(1,i) ) ~= 0) then
        key = bit.bxor( key, Random64[1+RandomCastle+i] );
      end
   end

   return key;
end

-- hash_ep_key()

function hash_ep_key( square )  -- uint64

   --ASSERT(256, SQUARE_IS_OK(square));

   return Random64[1+RandomEnPassant+SQUARE_FILE(square)-FileA ];
end

-- hash_turn_key()

function hash_turn_key( colour )  -- uint64

   --ASSERT(257, COLOUR_IS_OK(colour));

   return iif(COLOUR_IS_WHITE(colour) , Random64[1+RandomTurn] , 0 );
end

-- hash_counter_key()

function hash_counter_key( piece_12, count )  -- uint64

   local key = 0     -- uint64;
   local i = 0;      -- int
   local index = 0;  -- int

   --ASSERT(258, piece_12>=0 and piece_12<12);
   --ASSERT(259, count>=0 and count<=10);

   -- init

   key = 0;

   -- counter

   index = piece_12 * 16;
   for i = 0, count-1, 1 do
     key = bit.bxor( key, Random64[1+index+i] );
   end

   return key;

end

-- end of hash.cpp





-- list.cpp

-- functions

-- list_is_ok()

function list_is_ok( list )  -- bool

   if (list.size == nil) then
     return false;
   end

   if (list.size < 0  or  list.size >= ListSize) then
     return false;
   end

   return true;
end

-- list_remove()

function list_remove( list, pos )  -- int

   local i = 0;   -- int

   --ASSERT(260, list_is_ok(list));
   --ASSERT(261, pos>=0 and pos<list.size);

   for i = pos, list.size-2, 1 do
      list.move[1+i] = list.move[1+i+1];
      list.value[1+i] = list.value[1+i+1];
   end

   list.size = list.size - 1;
end

-- list_copy()

function list_copy( dst, src )  -- void

   local i = 0;   -- int

   --ASSERT(262, dst.size~=nil);
   --ASSERT(263, list_is_ok(src));

   dst.size = src.size;

   for i = 0, src.size-1, 1 do
      dst.move[1+i] = src.move[1+i];
      dst.value[1+i] = src.value[1+i];
   end
end

-- list_sort()

function list_sort( list )  -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local j = 0;      -- int
   local move = 0;   -- int
   local value = 0;  -- int

   --ASSERT(264, list_is_ok(list));

   -- init

   size = list.size;
   list.value[1+size] = -32768; -- HACK: sentinel

   -- insert sort (stable)

   for i = size-2, 0, -1 do

      move = list.move[1+i];
      value = list.value[1+i];

      j = i;
      while( value < list.value[1+j+1] ) do
         list.move[1+j] = list.move[1+j+1];
         list.value[1+j] = list.value[1+j+1];
         j = j + 1;
      end

      --ASSERT(265, j<size);

      list.move[1+j] = move;
      list.value[1+j] = value;
   end

   -- debug

   if (iDbg01) then
      for i = 0, size-2, 1 do
         --ASSERT(266, list.value[1+i]>=list.value[1+i+1]);
      end
   end
end

-- list_contain()

function list_contain( list, move )  -- bool

   local i = 0;   -- int

   --ASSERT(267, list_is_ok(list));
   --ASSERT(268, move_is_ok(move));

   for i = 0, list.size-1, 1 do
      if (list.move[1+i] == move) then
        return true;
      end
   end

   return false;
end

-- list_note()

function list_note( list )  -- void

   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(269, list_is_ok(list));

   for i = 0, list.size-1, 1 do
      move = list.move[1+i];
      --ASSERT(270, move_is_ok(move));
      list.value[1+i] = -move_order(move);
   end
end

-- list_filter()

function list_filter( list, board, keep )  -- bool

   local pos = 0;   -- int
   local i = 0;     -- int
   local move = 0;  -- int
   local value = 0; -- int

   --ASSERT(271, list.size~=nil);
   --ASSERT(272, board.sp~=nil);
   ----ASSERT(273, test~=nil);
   --ASSERT(274, keep==true or keep==false);

   pos = 0;

   for i = 0, list.size-1, 1 do

      --ASSERT(275, pos>=0 and pos<=i);

      move = list.move[1+i];
      value = list.value[1+i];

      if (pseudo_is_legal(move,board) == keep) then
         list.move[1+pos] = move;
         list.value[1+pos] = value;
         pos = pos + 1;
      end
   end

   --ASSERT(276, pos>=0 and pos<=list.size);
   list.size = pos;

   -- debug

   --ASSERT(277, list_is_ok(list));
end

-- end of list.cpp




-- material.cpp

-- functions

-- material_init()

function material_init()

   -- UCI options

   MaterialWeight = (option_get_int("Material") * 256 + 50) / 100;

   -- material table

   Material.size = 0;
   Material.mask = 0;
end

-- material_alloc()

function material_alloc()

   --ASSERT(278, true);   -- sizeof(entry_t)==16

   if (UseTable) then

      Material.size = MaterialTableSize;
      Material.mask = Material.size - 1;   -- 2^x -1
      -- Material.table = (entry_t *) my_malloc(Material.size*sizeof(entry_t));

      material_clear();
   end

end

-- material_clear()

function material_clear()

   local i = 0;

   Material.table = {};
   Material.used = 0;
   Material.read_nb = 0;
   Material.read_hit = 0;
   Material.write_nb = 0;
   Material.write_collision = 0;

end

-- material_get_info()

function material_get_info( info, board )  -- void

   local key = 0;             -- uint64
   local entry = nil;         -- entry_t *
   local index = 0;

   --ASSERT(279, info.lock~=nil);
   --ASSERT(280, board.sp~=nil);

   -- probe

   if (UseTable) then

      Material.read_nb = Material.read_nb + 1;

      key = board.material_key;
      index = bit.band( KEY_INDEX(key), Material.mask );

      entry = Material.table[1+index];

      if(entry == nil or entry.lock == nil) then
        Material.table[1+index] = material_info_t();
        entry = Material.table[1+index];
      end

      if (entry.lock == KEY_LOCK(key)) then

         -- found

         Material.read_hit = Material.read_hit + 1;

         material_info_copy( info, entry );

         return;
      end
   end

   -- calculation

   material_comp_info(info,board);

   -- store

   if (UseTable) then

      Material.write_nb = Material.write_nb + 1;

      if (entry.lock == 0) then     -- HACK: assume free entry
         Material.used = Material.used + 1;
      else
         Material.write_collision = Material.write_collision + 1;
      end

      material_info_copy( entry, info );

      entry.lock = KEY_LOCK(key);
   end

end

-- material_comp_info()

function material_comp_info( info,  board)  -- void

   local wp = 0;   -- int
   local wn = 0;   -- int
   local wb = 0;   -- int
   local wr = 0;   -- int
   local wq = 0;   -- int
   local bp = 0;   -- int
   local bn = 0;   -- int
   local bb = 0;   -- int
   local br = 0;   -- int
   local bq = 0;   -- int

   local wt = 0;   -- int
   local bt = 0;   -- int
   local wm = 0;   -- int
   local bm = 0;   -- int

   local colour = 0;  -- int
   local recog = 0;   -- int
   local flags = 0;   -- int
   local cflags = { 0, 0 }; -- int[ColourNb]
   local mul = { 16, 16 };    -- int[ColourNb]
   local phase = 0;   -- int
   local opening = 0; -- int
   local endgame = 0; -- int
   local ifelse = false;

   --ASSERT(281, info.lock~=nil);
   --ASSERT(282, board.sp~=nil);

   -- init

   wp = board.number[1+WhitePawn12];
   wn = board.number[1+WhiteKnight12];
   wb = board.number[1+WhiteBishop12];
   wr = board.number[1+WhiteRook12];
   wq = board.number[1+WhiteQueen12];

   bp = board.number[1+BlackPawn12];
   bn = board.number[1+BlackKnight12];
   bb = board.number[1+BlackBishop12];
   br = board.number[1+BlackRook12];
   bq = board.number[1+BlackQueen12];

   wt = wq + wr + wb + wn + wp; -- no king
   bt = bq + br + bb + bn + bp; -- no king

   wm = wb + wn;
   bm = bb + bn;

   local w_maj = wq * 2 + wr;         -- int
   local w_min = wb + wn;             -- int
   local w_tot = w_maj * 2 + w_min;   -- int

   local b_maj = bq * 2 + br;         -- int
   local b_min = bb + bn;             -- int
   local b_tot = b_maj * 2 + b_min;   -- int

   -- recogniser

   recog = MAT_NONE;

   ifelse = true;

   if (ifelse and (wt == 0  and  bt == 0)) then

      recog = MAT_KK;

      ifelse = false;
   end

   if (ifelse and (wt == 1  and  bt == 0)) then

      if (wb == 1) then
        recog = MAT_KBK;
      end
      if (wn == 1) then
        recog = MAT_KNK;
      end
      if (wp == 1) then
        recog = MAT_KPK;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 0  and  bt == 1)) then

      if (bb == 1) then
        recog = MAT_KKB;
      end
      if (bn == 1) then
        recog = MAT_KKN;
      end
      if (bp == 1) then
        recog = MAT_KKP;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 1  and  bt == 1)) then

      if (wq == 1  and  bq == 1) then
        recog = MAT_KQKQ;
      end
      if (wq == 1  and  bp == 1) then
        recog = MAT_KQKP;
      end
      if (wp == 1  and  bq == 1) then
        recog = MAT_KPKQ;
      end
      if (wr == 1  and  br == 1) then
        recog = MAT_KRKR;
      end
      if (wr == 1  and  bp == 1) then
        recog = MAT_KRKP;
      end
      if (wp == 1  and  br == 1) then
        recog = MAT_KPKR;
      end
      if (wb == 1  and  bb == 1) then
        recog = MAT_KBKB;
      end
      if (wb == 1  and  bp == 1) then
        recog = MAT_KBKP;
      end
      if (wp == 1  and  bb == 1) then
        recog = MAT_KPKB;
      end
      if (wn == 1  and  bn == 1) then
        recog = MAT_KNKN;
      end
      if (wn == 1  and  bp == 1) then
        recog = MAT_KNKP;
      end
      if (wp == 1  and  bn == 1) then
        recog = MAT_KPKN;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 2  and  bt == 0)) then

      if (wb == 1  and  wp == 1) then
        recog = MAT_KBPK;
      end
      if (wn == 1  and  wp == 1) then
        recog = MAT_KNPK;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 0  and  bt == 2)) then

      if (bb == 1  and  bp == 1) then
        recog = MAT_KKBP;
      end
      if (bn == 1  and  bp == 1) then
        recog = MAT_KKNP;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 2  and  bt == 1)) then

      if (wr == 1  and  wp == 1  and  br == 1) then
        recog = MAT_KRPKR;
      end
      if (wb == 1  and  wp == 1  and  bb == 1) then
        recog = MAT_KBPKB;
      end

      ifelse = false;
   end

   if (ifelse and (wt == 1  and  bt == 2)) then

      if (wr == 1  and  br == 1  and  bp == 1) then
        recog = MAT_KRKRP;
      end
      if (wb == 1  and  bb == 1  and  bp == 1) then
        recog = MAT_KBKBP;
      end

      ifelse = false;
   end

   -- draw node (exact-draw recogniser)

   flags = 0; -- TODO: MOVE ME

            -- if no major piece or pawn
   if (wq+wr+wp == 0  and  bq+br+bp == 0) then
         -- at most one minor => KK, KBK or KNK
      if (wm + bm <= 1 or  recog == MAT_KBKB) then
         flags = bit.bor( flags, DrawNodeFlag );
      end

   else
     if (recog == MAT_KPK   or  recog == MAT_KKP or  recog == MAT_KBPK  or  recog == MAT_KKBP) then
       flags = bit.bor( flags, DrawNodeFlag );
     end
   end

   -- bishop endgame
            -- if only bishops
   if (wq+wr+wn == 0  and  bq+br+bn == 0) then
      if (wb == 1  and  bb == 1) then
         if (wp-bp >= -2  and  wp-bp <= 2) then    -- pawn diff <= 2
            flags = bit.bor( flags, DrawBishopFlag );
         end
      end
   end

   -- white multiplier

   if (wp == 0) then  -- white has no pawns

      ifelse = true;
      if (ifelse and (w_tot == 1)) then

         --ASSERT(283, w_maj==0);
         --ASSERT(284, w_min==1);

         -- KBK* or KNK*, always insufficient

         mul[1+White] = 0;


         ifelse = false;
      end

      if (ifelse and (w_tot == 2  and  wn == 2)) then

         --ASSERT(285, w_maj==0);
         --ASSERT(286, w_min==2);

         -- KNNK*, usually insufficient

         if (b_tot ~= 0  or  bp == 0) then
            mul[1+White] = 0;
         else    -- KNNKP+, might not be draw
            mul[1+White] = 1; -- 1/16
         end

         ifelse = false;
      end

      if (ifelse and (w_tot == 2  and  wb == 2  and  b_tot == 1  and  bn == 1)) then

         --ASSERT(287, w_maj==0);
         --ASSERT(288, w_min==2);
         --ASSERT(289, b_maj==0);
         --ASSERT(290, b_min==1);

         -- KBBKN*, barely drawish (not at all?)

         mul[1+White] = 8; -- 1/2

         ifelse = false;
      end

      if (ifelse and (w_tot-b_tot <= 1  and  w_maj <= 2)) then

         -- no more than 1 minor up, drawish

         mul[1+White] = 2; -- 1/8
         ifelse = false;
      end

   else

    if (wp == 1) then -- white has one pawn

      if (b_min ~= 0) then

         -- assume black sacrifices a minor against the lone pawn

         b_min = b_min - 1;
         b_tot = b_tot + 1;

         ifelse = true;
         if (ifelse and (w_tot == 1)) then

            --ASSERT(291, w_maj==0);
            --ASSERT(292, w_min==1);

            -- KBK* or KNK*, always insufficient

            mul[1+White] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (w_tot == 2  and  wn == 2)) then

            --ASSERT(293, w_maj==0);
            --ASSERT(294, w_min==2);

            -- KNNK*, usually insufficient

            mul[1+White] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (w_tot-b_tot <= 1  and  w_maj <= 2)) then

            -- no more than 1 minor up, drawish

            mul[1+White] = 8; -- 1/2

            ifelse = false;
         end

      else
       if (br ~= 0) then

         -- assume black sacrifices a rook against the lone pawn

         b_maj = b_maj - 1;
         b_tot = b_tot - 2;

         ifelse = true;
         if (ifelse and (w_tot == 1)) then

            --ASSERT(295, w_maj==0);
            --ASSERT(296, w_min==1);

            -- KBK* or KNK*, always insufficient

            mul[1+White] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (w_tot == 2  and  wn == 2)) then

            --ASSERT(297, w_maj==0);
            --ASSERT(298, w_min==2);

            -- KNNK*, usually insufficient

            mul[1+White] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (w_tot-b_tot <= 1  and  w_maj <= 2)) then

            -- no more than 1 minor up, drawish

            mul[1+White] = 8; -- 1/2

            ifelse = false;
         end

       end
      end

    end
   end

   -- black multiplier

   if (bp == 0) then    -- black has no pawns


      ifelse = true;
      if (ifelse and (b_tot == 1)) then

         --ASSERT(299, b_maj==0);
         --ASSERT(300, b_min==1);

         -- KBK* or KNK*, always insufficient

         mul[1+Black] = 0;

         ifelse = false;
      end

      if (ifelse and (b_tot == 2  and  bn == 2)) then

         --ASSERT(301, b_maj==0);
         --ASSERT(302, b_min==2);

         -- KNNK*, usually insufficient

         if (w_tot ~= 0  or  wp == 0) then
            mul[1+Black] = 0;
         else   -- KNNKP+, might not be draw
            mul[1+Black] = 1; -- 1/16
         end

         ifelse = false;
      end

      if (ifelse and (b_tot == 2  and  bb == 2  and  w_tot == 1  and  wn == 1)) then

         --ASSERT(303, b_maj==0);
         --ASSERT(304, b_min==2);
         --ASSERT(305, w_maj==0);
         --ASSERT(306, w_min==1);

         -- KBBKN*, barely drawish (not at all?)

         mul[1+Black] = 8; -- 1/2

         ifelse = false;
      end

      if (ifelse and (b_tot-w_tot <= 1  and  b_maj <= 2)) then

         -- no more than 1 minor up, drawish

         mul[1+Black] = 2; -- 1/8

         ifelse = false;
      end

   else
    if (bp == 1) then  -- black has one pawn

      if (w_min ~= 0) then

         -- assume white sacrifices a minor against the lone pawn

         w_min = w_min - 1;
         w_tot = w_tot - 1;

         ifelse = true;
         if (ifelse and (b_tot == 1)) then

            --ASSERT(307, b_maj==0);
            --ASSERT(308, b_min==1);

            -- KBK* or KNK*, always insufficient

            mul[1+Black] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (b_tot == 2  and  bn == 2)) then

            --ASSERT(309, b_maj==0);
            --ASSERT(310, b_min==2);

            -- KNNK*, usually insufficient

            mul[1+Black] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (b_tot-w_tot <= 1  and  b_maj <= 2)) then

            -- no more than 1 minor up, drawish

            mul[1+Black] = 8; -- 1/2

            ifelse = false;
         end

      else
       if (wr ~= 0) then

         -- assume white sacrifices a rook against the lone pawn

         w_maj = w_maj - 1;
         w_tot = w_tot - 2;

         ifelse = true;
         if (ifelse and (b_tot == 1)) then

            --ASSERT(311, b_maj==0);
            --ASSERT(312, b_min==1);

            -- KBK* or KNK*, always insufficient

            mul[1+Black] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (b_tot == 2  and  bn == 2)) then

            --ASSERT(313, b_maj==0);
            --ASSERT(314, b_min==2);

            -- KNNK*, usually insufficient

            mul[1+Black] = 4; -- 1/4

            ifelse = false;
         end

         if (ifelse and (b_tot-w_tot <= 1  and  b_maj <= 2)) then

            -- no more than 1 minor up, drawish

            mul[1+Black] = 8; -- 1/2

            ifelse = false;
         end

       end
      end
    end
   end

   -- potential draw for white

   if (wt == wb+wp  and  wp >= 1) then
     cflags[1+White] = bit.bor( cflags[1+White], MatRookPawnFlag );
   end
   if (wt == wb+wp  and  wb <= 1  and  wp >= 1  and  bt > bp) then
     cflags[1+White] = bit.bor( cflags[1+White], MatBishopFlag );
   end

   if (wt == 2  and  wn == 1  and  wp == 1  and  bt > bp) then
     cflags[1+White] = bit.bor( cflags[1+White], MatKnightFlag );
   end

   -- potential draw for black

   if (bt == bb+bp  and  bp >= 1) then
     cflags[1+Black] = bit.bor( cflags[1+Black], MatRookPawnFlag );
   end
   if (bt == bb+bp  and  bb <= 1  and  bp >= 1  and  wt > wp) then
     cflags[1+Black] = bit.bor( cflags[1+Black], MatBishopFlag );
   end

   if (bt == 2  and  bn == 1  and  bp == 1  and  wt > wp) then
     cflags[1+Black] = bit.bor( cflags[1+Black], MatKnightFlag );
   end

   -- draw leaf (likely draw)

   if (recog == MAT_KQKQ  or  recog == MAT_KRKR) then
      mul[1+White] = 0;
      mul[1+Black] = 0;
   end

   -- king safety

   if (bq >= 1  and  bq+br+bb+bn >= 2) then
     cflags[1+White] = bit.bor( cflags[1+White], MatKingFlag );
   end
   if (wq >= 1  and  wq+wr+wb+wn >= 2) then
     cflags[1+Black] = bit.bor( cflags[1+Black], MatKingFlag );
   end

   -- phase (0: opening . 256: endgame)

   phase = TotalPhase;

   phase = phase - (wp * PawnPhase);
   phase = phase - (wn * KnightPhase);
   phase = phase - (wb * BishopPhase);
   phase = phase - (wr * RookPhase);
   phase = phase - (wq * QueenPhase);

   phase = phase - (bp * PawnPhase);
   phase = phase - (bn * KnightPhase);
   phase = phase - (bb * BishopPhase);
   phase = phase - (br * RookPhase);
   phase = phase - (bq * QueenPhase);

   if (phase < 0) then
     phase = 0;
   end

   --ASSERT(315, phase>=0 and phase<=TotalPhase);
   phase = math.min( ((phase * 256) + (TotalPhase / 2)) / TotalPhase, 256 );

   --ASSERT(316, phase>=0 and phase<=256);

   -- material

   opening = 0;
   endgame = 0;

   opening = opening + (wp * PawnOpening);
   opening = opening + (wn * KnightOpening);
   opening = opening + (wb * BishopOpening);
   opening = opening + (wr * RookOpening);
   opening = opening + (wq * QueenOpening);

   opening = opening - (bp * PawnOpening);
   opening = opening - (bn * KnightOpening);
   opening = opening - (bb * BishopOpening);
   opening = opening - (br * RookOpening);
   opening = opening - (bq * QueenOpening);

   endgame = endgame + (wp * PawnEndgame);
   endgame = endgame + (wn * KnightEndgame);
   endgame = endgame + (wb * BishopEndgame);
   endgame = endgame + (wr * RookEndgame);
   endgame = endgame + (wq * QueenEndgame);

   endgame = endgame - (bp * PawnEndgame);
   endgame = endgame - (bn * KnightEndgame);
   endgame = endgame - (bb * BishopEndgame);
   endgame = endgame - (br * RookEndgame);
   endgame = endgame - (bq * QueenEndgame);

   -- bishop pair

   if (wb >= 2) then     -- HACK: assumes different colours
      opening = opening + BishopPairOpening;
      endgame = endgame + BishopPairEndgame;
   end

   if (bb >= 2) then     -- HACK: assumes different colours
      opening = opening - BishopPairOpening;
      endgame = endgame - BishopPairEndgame;
   end

   -- store info

   info.recog = recog;
   info.flags = flags;

   for colour = 0, 1, 1 do
     info.cflags[1+colour] = cflags[1+colour];
     info.mul[1+colour] = mul[1+colour];
   end

   info.phase = phase;
   info.opening = (opening * MaterialWeight) / 256;
   info.endgame = (endgame * MaterialWeight) / 256;
end

-- end of material.cpp



-- move.cpp

-- functions

-- move_is_ok()

function move_is_ok( move )  -- bool

   if (move < 0  or  move >= 65536 or move == MoveNone or move == Movenil) then
     return false;
   end
   return true;
end

-- move_promote()

function move_promote( move )  -- int

   local code = 0;   -- int
   local piece = 0;  -- int

   --ASSERT(317, move_is_ok(move));

   --ASSERT(318, MOVE_IS_PROMOTE(move));

   code = bit.band( bit.rshift(move,12), 3 );
   piece = PromotePiece[1+code];

   if (SQUARE_RANK(MOVE_TO(move)) == Rank8) then
      piece = bit.bor( piece, WhiteFlag );
   else
      --ASSERT(319, SQUARE_RANK(MOVE_TO(move))==Rank1);
      piece = bit.bor( piece, BlackFlag );
   end

   --ASSERT(320, piece_is_ok(piece));

   return piece;
end

-- move_order()

function move_order( move )  -- int

   --ASSERT(321, move_is_ok(move));

   return bit.bor( bit.lshift( bit.band(move,V07777),2 ), bit.band( bit.rshift(move,12),3 ) );
end

-- move_is_capture()

function move_is_capture( move, board )  -- bool

   --ASSERT(322, move_is_ok(move));
   --ASSERT(323, board.sp~=nil);

   return MOVE_IS_EN_PASSANT(move) or (board.square[1+MOVE_TO(move)] ~= Empty);
end

-- move_is_under_promote()

function move_is_under_promote( move )  -- bool

   --ASSERT(324, move_is_ok(move));

   return MOVE_IS_PROMOTE(move) and ( bit.band( move, MoveAllFlags ) ~= MovePromoteQueen );
end

-- move_is_tactical()

function move_is_tactical( move, board )  -- bool

   --ASSERT(325, move_is_ok(move));
   --ASSERT(326, board.sp~=nil);

   return ( bit.band(move,bit.lshift(1,15))~= 0 )  or  (board.square[1+MOVE_TO(move)] ~= Empty); -- HACK
end

-- move_capture()


function move_capture( move, board )  -- int

   --ASSERT(327, move_is_ok(move));
   --ASSERT(328, board.sp~=nil);

   if (MOVE_IS_EN_PASSANT(move)) then
      return PAWN_OPP(board.square[1+MOVE_FROM(move)]);
   end

   return board.square[1+MOVE_TO(move)];
end

-- move_to_string()

function move_to_string( move, str1 )  -- bool

   local str2 = string_t();

   --ASSERT(329, move==Movenil or move_is_ok(move));
   --ASSERT(330, str1.v~=nil);

   -- nil move

   if (move == Movenil) then
      return true;
   end

   -- normal moves

   str1.v = "";
   square_to_string( MOVE_FROM(move), str2 );
   str1.v = str1.v .. str2.v;
   square_to_string( MOVE_TO(move), str2 );
   str1.v = str1.v .. str2.v;
   --ASSERT(332, string.len(str1.v)==4);

   -- promotes

   if (MOVE_IS_PROMOTE(move)) then
      str1.v = str1.v .. string.lower( piece_to_char(move_promote(move)) );
   end

   return true;
end

-- move_from_string()

function move_from_string( str1, board )  -- int

   local str2 = string_t();
   local c = " ";         -- char;

   local from = 0;        -- int
   local to = 0;          -- int
   local move = 0;        -- int
   local piece = 0;       -- int
   local delta = 0;       -- int

   --ASSERT(333, str1.v~=nil);
   --ASSERT(334, board.sp~=nil);

   -- from

   str2.v = string.sub( str1.v, 1, 2 );

   from = square_from_string(str2);
   if (from == SquareNone) then
     return MoveNone;
   end

   -- to

   str2.v = string.sub( str1.v, 3, 4 );

   to = square_from_string(str2);
   if (to == SquareNone) then
     return MoveNone;
   end

   move = MOVE_MAKE(from,to);

   -- promote

   if( string.len( str1.v )>4 ) then
     c = string.sub( str1.v, 5, 5 );
     if(c=="n") then
       move = bit.bor( move, MovePromoteKnight );
     end
     if(c=="b") then
       move = bit.bor( move, MovePromoteBishop );
     end
     if(c=="r") then
       move = bit.bor( move, MovePromoteRook );
     end
     if(c=="q") then
       move = bit.bor( move, MovePromoteQueen );
     end
   end

   -- flags

   piece = board.square[1+from];

   if (PIECE_IS_PAWN(piece)) then
      if (to == board.ep_square) then
        move = bit.bor( move, MoveEnPassant );
      end
   else
    if (PIECE_IS_KING(piece)) then
      delta = to - from;
      if (delta == 2  or  delta == -2) then
        move = bit.bor( move, MoveCastle );
      end
    end
   end

   return move;
end

-- end of move.cpp




-- move_check.cpp

-- functions

-- gen_quiet_checks()

function gen_quiet_checks( list,  board ) -- void

   --ASSERT(335, list.size~=nil);
   --ASSERT(336, board.sp~=nil);

   --ASSERT(337, not board_is_check(board));

   list.size=0;

   add_quiet_checks(list,board);
   add_castle_checks(list,board);

   -- debug

   --ASSERT(338, list_is_ok(list));
end

-- add_quiet_checks()

function add_quiet_checks( list,  board ) -- void

   local me = 0;    -- int
   local opp = 0;   -- int
   local king = 0;  -- int

   local ptr = 0;   -- int
   local ptr_2 = 0; -- int

   local from = 0;  -- int
   local to = 0;    -- int
   local sq = 0;    -- int

   local piece = 0;    -- int
   local inc_ptr = 0;  -- int
   local inc = 0;      -- int
   local pawn = 0;   -- int
   local rank = 0;   -- int
   local pin = {};   -- int[8+1]
   local gotonextpiece = false;

   --ASSERT(339, list.size~=nil);
   --ASSERT(340, board.sp~=nil);

   -- init

   me = board.turn;
   opp = COLOUR_OPP(me);

   king = KING_POS(board,opp);

   find_pins(pin,board);

   -- indirect checks

   ptr = 0;
   while(true) do
      from = pin[1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      --ASSERT(341, is_pinned(board,from,opp));

      if (PIECE_IS_PAWN(piece)) then

         inc = PawnMoveInc[1+me];
         rank = PAWN_RANK(from,me);

         if (rank ~= Rank7) then    -- promotes are generated with captures
            to = from + inc;
            if (board.square[1+to] == Empty) then
               if (DELTA_INC_LINE(to-king) ~= DELTA_INC_LINE(from-king)) then
                  --ASSERT(342, not SquareIsPromote[1+to]);
                  LIST_ADD(list,MOVE_MAKE(from,to));
                  if (rank == Rank2) then
                     to = from + (2*inc);
                     if (board.square[1+to] == Empty) then
                        --ASSERT(343, DELTA_INC_LINE(to-king)~=DELTA_INC_LINE(from-king));
                        --ASSERT(344, not SquareIsPromote[1+to]);
                        LIST_ADD(list,MOVE_MAKE(from,to));
                     end
                  end
               end
            end
         end

      else
       if (PIECE_IS_SLIDER(piece)) then

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from+inc;
           while(true) do

               if( board.square[1+to] ~= Empty ) then
                 break;
               end

               --ASSERT(345, DELTA_INC_LINE(to-king)~=DELTA_INC_LINE(from-king));
               LIST_ADD(list,MOVE_MAKE(from,to));

               to = to + inc;
           end
           inc_ptr = inc_ptr + 1;
         end

       else

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from + inc;
           if (board.square[1+to] == Empty) then
               if (DELTA_INC_LINE(to-king) ~= DELTA_INC_LINE(from-king)) then
                  LIST_ADD(list,MOVE_MAKE(from,to));
               end
           end

           inc_ptr = inc_ptr + 1;
         end

       end
      end
      ptr = ptr + 1;
   end

   -- piece direct checks

   ptr = 1;       -- HACK: no king
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      ptr_2 = 0;
      while(true) do
        sq = pin[1+ptr_2];
        if( sq == SquareNone ) then
          break;
        end

        if (sq == from) then
          gotonextpiece = true;
          break;
        end

        ptr_2 = ptr_2 + 1;
      end

      if(gotonextpiece) then

        gotonextpiece = false;

      else

       --ASSERT(346, not is_pinned(board,from,opp));

       piece = board.square[1+from];

       if (PIECE_IS_SLIDER(piece)) then

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from+inc;
           while(true) do

               if( board.square[1+to] ~= Empty ) then
                 break;
               end

               if (PIECE_ATTACK(board,piece,to,king)) then
                  LIST_ADD(list,MOVE_MAKE(from,to));
               end

               to = to + inc;
           end
           inc_ptr = inc_ptr + 1;
         end


       else

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from + inc;
           if (board.square[1+to] == Empty) then
               if (PSEUDO_ATTACK(piece,king-to)) then
                  LIST_ADD(list,MOVE_MAKE(from,to));
               end
           end

           inc_ptr = inc_ptr + 1;
         end

       end

      end

-- next_piece:

      ptr = ptr + 1;
   end

   -- pawn direct checks

   inc = PawnMoveInc[1+me];
   pawn = PawnMake[1+me];

   to = king - (inc-1);
   --ASSERT(347, PSEUDO_ATTACK(pawn,king-to));

   from = to - inc;
   if (board.square[1+from] == pawn) then
      if (board.square[1+to] == Empty) then
         --ASSERT(348, not SquareIsPromote[1+to]);
         LIST_ADD(list,MOVE_MAKE(from,to));
      end
   else
      from = to - (2*inc);
      if (board.square[1+from] == pawn) then
         if (PAWN_RANK(from,me) == Rank2
           and  board.square[1+to] == Empty
           and  board.square[1+from+inc] == Empty) then
            --ASSERT(349, not SquareIsPromote[1+to]);
            LIST_ADD(list,MOVE_MAKE(from,to));
         end
      end
   end

   to = king - (inc+1);
   --ASSERT(350, PSEUDO_ATTACK(pawn,king-to));

   from = to - inc;
   if (board.square[1+from] == pawn) then
      if (board.square[1+to] == Empty) then
         --ASSERT(351, not SquareIsPromote[1+to]);
         LIST_ADD(list,MOVE_MAKE(from,to));
      end
   else
      from = to - (2*inc);
      if (board.square[1+from] == pawn) then
         if (PAWN_RANK(from,me) == Rank2
           and  board.square[1+to] == Empty
           and  board.square[1+from+inc] == Empty) then
            --ASSERT(352, not SquareIsPromote[1+to]);
            LIST_ADD(list,MOVE_MAKE(from,to));
         end
      end
   end

end

-- add_castle_checks()

function add_castle_checks( list, board ) -- void

   --ASSERT(353, list.size~=nil);
   --ASSERT(354, board.sp~=nil);

   --ASSERT(355, not board_is_check(board));

   if (COLOUR_IS_WHITE(board.turn)) then

      if ( bit.band( board.flags, FlagsWhiteKingCastle) ~= 0
        and  board.square[1+F1] == Empty
        and  board.square[1+G1] == Empty
        and  (not is_attacked(board,F1,Black))) then
         add_check(list,MOVE_MAKE_FLAGS(E1,G1,MoveCastle),board);
      end

      if ( bit.band( board.flags, FlagsWhiteQueenCastle) ~= 0
        and  board.square[1+D1] == Empty
        and  board.square[1+C1] == Empty
        and  board.square[1+B1] == Empty
        and  (not is_attacked(board,D1,Black))) then
         add_check(list,MOVE_MAKE_FLAGS(E1,C1,MoveCastle),board);
      end

   else  -- black

      if ( bit.band( board.flags, FlagsBlackKingCastle) ~= 0
        and  board.square[1+F8] == Empty
        and  board.square[1+G8] == Empty
        and  (not is_attacked(board,F8,White))) then
         add_check(list,MOVE_MAKE_FLAGS(E8,G8,MoveCastle),board);
      end

      if ( bit.band( board.flags, FlagsBlackQueenCastle) ~= 0
        and  board.square[1+D8] == Empty
        and  board.square[1+C8] == Empty
        and  board.square[1+B8] == Empty
        and  (not is_attacked(board,D8,White))) then
         add_check(list,MOVE_MAKE_FLAGS(E8,C8,MoveCastle),board);
      end
   end
end

-- add_check()

function add_check( list, move, board )  -- int

   local undo = undo_t();    -- undo_t[1];

   --ASSERT(356, list.size~=nil);
   --ASSERT(357, move_is_ok(move));
   --ASSERT(358, board.sp~=nil);

   move_do(board,move,undo);
   if (IS_IN_CHECK(board,board.turn)) then
     LIST_ADD(list,move);
   end
   move_undo(board,move,undo);
end

-- move_is_check()

function move_is_check( move, board )  -- bool

   local undo = undo_t();    -- undo_t[1];

   local check = false;   -- bool
   local me = 0;          -- int
   local opp = 0;         -- int
   local king = 0;        -- int
   local from = 0;        -- int
   local to = 0;          -- int
   local piece = 0;       -- int

   --ASSERT(359, move_is_ok(move));
   --ASSERT(360, board.sp~=nil);

   -- slow test for complex moves

   if (MOVE_IS_SPECIAL(move)) then

      move_do(board,move,undo);
      check = IS_IN_CHECK(board,board.turn);
      move_undo(board,move,undo);

      return check;
   end

   -- init

   me = board.turn;
   opp = COLOUR_OPP(me);
   king = KING_POS(board,opp);

   from = MOVE_FROM(move);
   to = MOVE_TO(move);
   piece = board.square[1+from];
   --ASSERT(361, COLOUR_IS(piece,me));

   -- direct check

   if (PIECE_ATTACK(board,piece,to,king)) then
     return true;
   end

   -- indirect check

   if (is_pinned(board,from,opp)
     and  DELTA_INC_LINE(king-to) ~= DELTA_INC_LINE(king-from)) then
      return true;
   end

   return false;
end

-- find_pins()

function find_pins( list, board )  -- int

   local me = 0;    -- int
   local opp = 0;   -- int
   local king = 0;  -- int
   local ptr = 0;   -- int
   local from = 0;  -- int
   local piece = 0; -- int
   local delta = 0; -- int
   local inc = 0;   -- int
   local sq = 0;    -- int
   local pin = 0;   -- int
   local capture = 0;   -- int
   local q = 0;         -- int

   --ASSERT(363, board.sp~=nil);

   -- init

   me = board.turn;
   opp = COLOUR_OPP(me);

   king = KING_POS(board,opp);

   ptr = 1;            -- HACK: no king
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      delta = king - from;
      --ASSERT(364, delta_is_ok(delta));

      if (PSEUDO_ATTACK(piece,delta)) then

         --ASSERT(365, PIECE_IS_SLIDER(piece));

         inc = DELTA_INC_LINE(delta);
         --ASSERT(366, inc~=IncNone);

         --ASSERT(367, SLIDER_ATTACK(piece,inc));

         sq = from;

         while(true) do
           sq = sq + inc;
           capture = board.square[1+sq];
           if( capture ~= Empty ) then
             break;
           end
         end

         --ASSERT(368, sq~=king);

         if (COLOUR_IS(capture,me)) then
            pin = sq;

            while(true) do
              sq = sq + inc;

              if( board.square[1+sq] ~= Empty ) then
                break;
              end
            end

            if (sq == king) then

              list[1+q] = pin;
              q = q + 1;

            end
         end
      end

      ptr = ptr + 1;
   end

   list[1+q] = SquareNone;
end

-- end of move_check.cpp



-- move_do.cpp

-- functions

function initCmsk( sq, flagMask )
  CastleMask[1+sq] = bit.band( CastleMask[1+sq], bit.bnot( flagMask ) );
end

-- move_do_init()

function move_do_init()

   local sq = 0;   -- int

   for sq = 0, SquareNb-1, 1 do
     CastleMask[1+sq] = 0xF;
   end

   initCmsk( E1, FlagsWhiteKingCastle );
   initCmsk( H1, FlagsWhiteKingCastle );

   initCmsk( E1, FlagsWhiteQueenCastle );
   initCmsk( A1, FlagsWhiteQueenCastle );

   initCmsk( E8, FlagsBlackKingCastle );
   initCmsk( H8, FlagsBlackKingCastle );

   initCmsk( E8, FlagsBlackQueenCastle );
   initCmsk( A8, FlagsBlackQueenCastle );

end

-- move_do()

function move_do( board, move, undo )  -- int

   local me = 0;        -- int
   local opp = 0;       -- int
   local from = 0;      -- int
   local to = 0;        -- int
   local piece = 0;     -- int
   local pos = 0;       -- int
   local capture = 0;   -- int
   local old_flags = 0; -- int
   local new_flags = 0; -- int

   local delta = 0;  -- int
   local sq = 0;     -- int
   local pawn = 0;   -- int
   local rook = 0;   -- int

   --ASSERT(369, board.sp~=nil);
   --ASSERT(370, move_is_ok(move));
   --ASSERT(371, undo.flags~=nil);

   --ASSERT(372, board_is_legal(board));

   -- initialise undo

   undo.capture = false;

   undo.turn = board.turn;
   undo.flags = board.flags;
   undo.ep_square = board.ep_square;
   undo.ply_nb = board.ply_nb;

   undo.cap_sq = board.cap_sq;

   undo.opening = board.opening;
   undo.endgame = board.endgame;

   undo.key = board.key;
   undo.pawn_key = board.pawn_key;
   undo.material_key = board.material_key;

   -- init

   me = board.turn;
   opp = COLOUR_OPP(me);

   from = MOVE_FROM(move);
   to = MOVE_TO(move);

   piece = board.square[1+from];
   --ASSERT(373, COLOUR_IS(piece,me));

   -- update key stack

   --ASSERT(374, board.sp<StackSize);
   board.stack[1+board.sp] = board.key;
   board.sp = board.sp + 1;

   -- update turn

   board.turn = opp;


   -- update castling rights

   old_flags = board.flags;
   new_flags = bit.band( bit.band( old_flags, CastleMask[1+from] ) , CastleMask[1+to] );

   board.flags = new_flags;


   -- update en-passant square

   sq = board.ep_square;
   if (sq ~= SquareNone) then

      board.ep_square = SquareNone;
   end

   if (PIECE_IS_PAWN(piece)) then

      delta = to - from;

      if (delta == 32  or  delta == -32) then
         pawn = PawnMake[1+opp];
         if (board.square[1+to-1] == pawn  or  board.square[1+to+1] == pawn) then
            board.ep_square = (from + to) / 2;
        end
      end
   end

   -- update move number (captures are handled later)

   board.ply_nb = board.ply_nb + 1;
   if (PIECE_IS_PAWN(piece)) then
     board.ply_nb = 0; -- conversion
   end

   -- update last square

   board.cap_sq = SquareNone;

   -- remove the captured piece

   sq = to;
   if (MOVE_IS_EN_PASSANT(move)) then
     sq = SQUARE_EP_DUAL(sq);
   end

   capture=board.square[1+sq];
   if (capture~= Empty) then

      --ASSERT(375, COLOUR_IS(capture,opp));
      --ASSERT(376, not PIECE_IS_KING(capture));

      undo.capture = true;
      undo.capture_square = sq;
      undo.capture_piece = capture;
      undo.capture_pos = board.pos[1+sq];

      square_clear(board,sq,capture,true);

      board.ply_nb = 0; -- conversion
      board.cap_sq = to;
   end

   -- move the piece

   if (MOVE_IS_PROMOTE(move)) then

      -- promote

      undo.pawn_pos = board.pos[1+from];

      square_clear(board,from,piece,true);

      piece = move_promote(move);

      -- insert the promote piece in MV order

      pos = board.piece_size[1+me];
      while( pos > 0  and  piece > board.square[1+board.piece[1+me][1+pos-1]] ) do
        pos = pos - 1;   -- HACK
      end

      square_set(board,to,piece,pos,true);

      board.cap_sq = to;

   else

      -- normal move

      square_move(board,from,to,piece,true);
   end

   -- move the rook in case of castling

   if (MOVE_IS_CASTLE(move)) then

      rook =  bit.bor( Rook64, COLOUR_FLAG(me) ); -- HACK

      if (to == G1) then
         square_move(board,H1,F1,rook,true);
      else
       if (to == C1) then
         square_move(board,A1,D1,rook,true);
       else
        if (to == G8) then
          square_move(board,H8,F8,rook,true);
        else
          if (to == C8) then
            square_move(board,A8,D8,rook,true);
          else
            --ASSERT(377, false);
          end
        end
       end
      end
   end

   -- debug

   --ASSERT(378, board_is_ok(board));

end

-- move_undo()

function move_undo( board, move, undo )  -- int

   local me = 0;    -- int
   local from = 0;  -- int
   local to = 0;    -- int
   local piece = 0; -- int
   local pos = 0;   -- int
   local rook = 0;  -- int

   --ASSERT(379, board.sp~=nil);
   --ASSERT(380, move_is_ok(move));
   --ASSERT(381, undo.flags~=nil);

   -- init

   me = undo.turn;

   from = MOVE_FROM(move);
   to = MOVE_TO(move);

   piece = board.square[1+to];
   --ASSERT(382, COLOUR_IS(piece,me));

   -- castle

   if (MOVE_IS_CASTLE(move)) then

      rook =  bit.bor( Rook64, COLOUR_FLAG(me) ); -- HACK

      if (to == G1) then
         square_move(board,F1,H1,rook,false);
      else
       if (to == C1) then
         square_move(board,D1,A1,rook,false);
       else
        if (to == G8) then
          square_move(board,F8,H8,rook,false);
        else
          if (to == C8) then
            square_move(board,D8,A8,rook,false);
          else
            --ASSERT(383, false);
          end
        end
       end
      end
   end



   -- move the piece backward

   if (MOVE_IS_PROMOTE(move)) then

      -- promote

      --ASSERT(384, piece==move_promote(move));
      square_clear(board,to,piece,false);

      piece = PawnMake[1+me];
      pos = undo.pawn_pos;

      square_set(board,from,piece,pos,false);

   else

      -- normal move

      square_move(board,to,from,piece,false);
   end

   -- put the captured piece back

   if (undo.capture) then
      square_set(board,undo.capture_square,undo.capture_piece,undo.capture_pos,false);
   end

   -- update board info

   board.turn = undo.turn;
   board.flags = undo.flags;
   board.ep_square = undo.ep_square;
   board.ply_nb = undo.ply_nb;

   board.cap_sq = undo.cap_sq;

   board.opening = undo.opening;
   board.endgame = undo.endgame;

   board.key = undo.key;
   board.pawn_key = undo.pawn_key;
   board.material_key = undo.material_key;

   -- update key stack

   --ASSERT(385, board.sp>0);
   board.sp = board.sp - 1;

   -- debug

   --ASSERT(386, board_is_ok(board));
   --ASSERT(387, board_is_legal(board));
end

-- move_do_nil()

function move_do_nil( board, undo )  -- void

   local sq = 0;   -- int

   --ASSERT(388, board.sp~=nil);
   --ASSERT(389, undo.flags~=nil);

   --ASSERT(390, board_is_legal(board));
   --ASSERT(391, not board_is_check(board));

   -- initialise undo

   undo.turn = board.turn;
   undo.ep_square = board.ep_square;
   undo.ply_nb = board.ply_nb;
   undo.cap_sq = board.cap_sq;
   undo.key = board.key;

   -- update key stack

   --ASSERT(392, board.sp<StackSize);
   board.stack[1+board.sp] = board.key;
   board.sp = board.sp + 1;

   -- update turn

   board.turn = COLOUR_OPP(board.turn);

   -- update en-passant square

   sq = board.ep_square;
   if (sq ~= SquareNone) then

      board.ep_square = SquareNone;
   end

   -- update move number

   board.ply_nb = 0; -- HACK: nil move is considered as a conversion

   -- update last square

   board.cap_sq = SquareNone;

   -- debug

   --ASSERT(393, board_is_ok(board));
end

-- move_undo_nil()

function move_undo_nil( board, undo )  -- void

   --ASSERT(394, board.sp~=nil);
   --ASSERT(395, undo.flags~=nil);

   --ASSERT(396, board_is_legal(board));
   --ASSERT(397, not board_is_check(board));

   -- update board info

   board.turn = undo.turn;
   board.ep_square = undo.ep_square;
   board.ply_nb = undo.ply_nb;
   board.cap_sq = undo.cap_sq;
   board.key = undo.key;

   -- update key stack

   --ASSERT(398, board.sp>0);
   board.sp = board.sp - 1;

   -- debug

   --ASSERT(399, board_is_ok(board));
end

-- square_clear()

function square_clear( board, square, piece, update )  -- bool

   local pos = 0;       -- int
   local piece_12 = 0;  -- int
   local colour = 0;    -- int
   local sq = 0;        -- int
   local i = 0;         -- int
   local size = 0;      -- int
   local sq_64 = 0;     -- int
   local t = 0;         -- int
   local hash_xor = 0;  -- uint64

   --ASSERT(400, board.sp~=nil);
   --ASSERT(401, SQUARE_IS_OK(square));
   --ASSERT(402, piece_is_ok(piece));
   --ASSERT(403, update==true or update==false);

   -- init

   pos = board.pos[1+square];
   --ASSERT(404, pos>=0);

   piece_12 = PieceTo12[1+piece];
   colour = PIECE_COLOUR(piece);

   -- square

   --ASSERT(405, board.square[1+square]==piece);
   board.square[1+square] = Empty;

   -- piece list

   if (not PIECE_IS_PAWN(piece)) then

      -- init

      size = board.piece_size[1+colour];
      --ASSERT(406, size>=1);

      -- stable swap

      --ASSERT(407, pos>=0 and pos<size);

      --ASSERT(408, board.pos[1+square]==pos);
      board.pos[1+square] = -1;

      for i = pos, size-2, 1 do

         sq = board.piece[1+colour][1+i+1];

         board.piece[1+colour][1+i] = sq;

         --ASSERT(409, board.pos[1+sq]==i+1);
         board.pos[1+sq] = i;
      end

      -- size

      size = size - 1;

      board.piece[1+colour][1+size] = SquareNone;
      board.piece_size[1+colour] = size;

   else

      -- init

      size = board.pawn_size[1+colour];
      --ASSERT(410, size>=1);

      -- stable swap

      --ASSERT(411, pos>=0 and pos<size);

      --ASSERT(412, board.pos[1+square]==pos);
      board.pos[1+square] = -1;

      for i = pos, size-2, 1 do

         sq = board.pawn[1+colour][1+i+1];

         board.pawn[1+colour][1+i] = sq;

         --ASSERT(413, board.pos[1+sq]==i+1);
         board.pos[1+sq] = i;
      end

      -- size

      size = size - 1;

      board.pawn[1+colour][1+size] = SquareNone;
      board.pawn_size[1+colour] = size;

      -- pawn "bitboard"

      t = SQUARE_FILE(square);
      board.pawn_file[1+colour][1+t] = bit.bxor( board.pawn_file[1+colour][1+t] ,
            BitEQ[1+PAWN_RANK(square,colour)] );
   end

   -- material

   --ASSERT(414, board.piece_nb>0);
   board.piece_nb = board.piece_nb - 1;

   --ASSERT(415, board.number[1+piece_12]>0);
   board.number[1+piece_12] = board.number[1+piece_12] - 1;

   -- update

   if (update) then

      -- init

      sq_64 = SquareTo64[1+square];

      -- PST

      board.opening = board.opening - Pget( piece_12, sq_64, Opening );
      board.endgame = board.endgame - Pget( piece_12, sq_64, Endgame );

      -- hash key

      hash_xor = Random64[1+RandomPiece+(bit.bxor(piece_12,1)*64)+sq_64];
         -- HACK: xor 1 for PolyGlot book (not lua)

      board.key = bit.bxor( board.key, hash_xor);
      if (PIECE_IS_PAWN(piece)) then
        board.pawn_key = bit.bxor( board.pawn_key, hash_xor);
      end

      -- material key

      board.material_key = bit.bxor( board.material_key, Random64[1+(piece_12*16)+board.number[1+piece_12]] );


   end
end

-- square_set()

function square_set( board, square, piece, pos, update )  -- bool

   local piece_12 = 0;  -- int
   local colour = 0;    -- int
   local sq = 0;        -- int
   local i = 0;         -- int
   local size = 0;      -- int
   local sq_64 = 0;     -- int
   local t = 0;         -- int
   local hash_xor = 0;  -- uint64


   --ASSERT(416, board.sp~=nil);
   --ASSERT(417, SQUARE_IS_OK(square));
   --ASSERT(418, piece_is_ok(piece));
   --ASSERT(419, pos>=0);
   --ASSERT(420, update==true or update==false);

   -- init

   piece_12 = PieceTo12[1+piece];
   colour = PIECE_COLOUR(piece);

   -- square

   --ASSERT(421, board.square[1+square]==Empty);
   board.square[1+square] = piece;

   -- piece list

   if (not PIECE_IS_PAWN(piece)) then

      -- init

      size = board.piece_size[1+colour];
      --ASSERT(422, size>=0);

      -- size

      size = size + 1;

      board.piece[1+colour][1+size] = SquareNone;
      board.piece_size[1+colour] = size;

      -- stable swap

      --ASSERT(423, pos>=0 and pos<size);

      for i = size-1, pos+1, -1 do

         sq = board.piece[1+colour][1+i-1];

         board.piece[1+colour][1+i] = sq;

         --ASSERT(424, board.pos[1+sq]==i-1);
         board.pos[1+sq] = i;
      end

      board.piece[1+colour][1+pos] = square;

      --ASSERT(425, board.pos[1+square]==-1);
      board.pos[1+square] = pos;

   else

      -- init

      size = board.pawn_size[1+colour];
      --ASSERT(426, size>=0);

      -- size

      size = size + 1;

      board.pawn[1+colour][1+size] = SquareNone;
      board.pawn_size[1+colour] = size;

      -- stable swap

      --ASSERT(427, pos>=0 and pos<size);

      for i = size-1, pos+1, -1 do

         sq = board.pawn[1+colour][1+i-1];

         board.pawn[1+colour][1+i] = sq;

         --ASSERT(428, board.pos[1+sq]==i-1);
         board.pos[1+sq] = i;
      end

      board.pawn[1+colour][1+pos] = square;

      --ASSERT(429, board.pos[1+square]==-1);
      board.pos[1+square] = pos;

      -- pawn "bitboard"

      t = SQUARE_FILE(square);
      board.pawn_file[1+colour][1+t] = bit.bxor( board.pawn_file[1+colour][1+t] ,
            BitEQ[1+PAWN_RANK(square,colour)] );


   end

   -- material

   --ASSERT(430, board.piece_nb<32);
   board.piece_nb = board.piece_nb + 1;

   --ASSERT(431, board.number[1+piece_12]<9);
   board.number[1+piece_12] = board.number[1+piece_12] + 1;

   -- update

   if (update) then

      -- init

      sq_64 = SquareTo64[1+square];

      -- PST

      board.opening = board.opening + Pget( piece_12, sq_64, Opening );
      board.endgame = board.endgame +  Pget( piece_12, sq_64, Endgame );
      -- hash key

      hash_xor = Random64[1+RandomPiece+(bit.bxor(piece_12,1)*64)+sq_64];
         -- HACK: xor 1 for PolyGlot book (not lua)

      board.key = bit.bxor( board.key, hash_xor);
      if (PIECE_IS_PAWN(piece)) then
        board.pawn_key = bit.bxor( board.pawn_key, hash_xor);
      end

      -- material key

      board.material_key = bit.bxor( board.material_key, Random64[1+(piece_12*16)+board.number[1+piece_12]] );

   end
end

-- square_move()

function square_move( board, from, to, piece, update )  -- bool

   local piece_12 = 0;    -- int
   local colour = 0;      -- int
   local pos = 0;         -- int
   local from_64 = 0;     -- int
   local to_64 = 0;       -- int
   local piece_index = 0; -- int
   local t = 0;           -- int
   local hash_xor = 0;    -- uint64


   --ASSERT(432, board.sp~=nil);
   --ASSERT(433, SQUARE_IS_OK(from));
   --ASSERT(434, SQUARE_IS_OK(to));
   --ASSERT(435, piece_is_ok(piece));
   --ASSERT(436, update==true or update==false);

   -- init

   colour = PIECE_COLOUR(piece);

   pos = board.pos[1+from];
   --ASSERT(437, pos>=0);

   -- from

   --ASSERT(438, board.square[1+from]==piece);
   board.square[1+from] = Empty;

   --ASSERT(439, board.pos[1+from]==pos);
   board.pos[1+from] = -1; -- not needed

   -- to

   --ASSERT(440, board.square[1+to]==Empty);
   board.square[1+to] = piece;

   --ASSERT(441, board.pos[1+to]==-1);
   board.pos[1+to] = pos;

   -- piece list

   if (not PIECE_IS_PAWN(piece)) then

      --ASSERT(442, board.piece[1+colour][1+pos]==from);
      board.piece[1+colour][1+pos] = to;

   else

      --ASSERT(443, board.pawn[1+colour][1+pos]==from);
      board.pawn[1+colour][1+pos] = to;

      -- pawn "bitboard"

      t = SQUARE_FILE(from);
      board.pawn_file[1+colour][1+t] = bit.bxor( board.pawn_file[1+colour][1+t] ,
            BitEQ[1+PAWN_RANK(from,colour)] );
      t = SQUARE_FILE(to);
      board.pawn_file[1+colour][1+t] = bit.bxor( board.pawn_file[1+colour][1+t] ,
            BitEQ[1+PAWN_RANK(to,colour)] );

   end

   -- update

   if (update) then

      -- init

      from_64 = SquareTo64[1+from];
      to_64 = SquareTo64[1+to];
      piece_12 = PieceTo12[1+piece];

      -- PST

 	  board.opening = board.opening + Pget(piece_12,to_64,Opening) - Pget(piece_12,from_64,Opening);
      board.endgame = board.endgame + Pget(piece_12,to_64,Endgame) - Pget(piece_12,from_64,Endgame);

      -- hash key

      piece_index = RandomPiece + (bit.bxor(piece_12,1) * 64);
          -- HACK: xor 1 for PolyGlot book (not lua)

      hash_xor =  bit.bxor( Random64[1+piece_index+to_64], Random64[1+piece_index+from_64] );

      board.key = bit.bxor( board.key, hash_xor );
      if (PIECE_IS_PAWN(piece)) then
        board.pawn_key = bit.bxor( board.pawn_key, hash_xor);
      end

   end

end

-- end of move_do.cpp



-- move_evasion.cpp

-- functions

-- gen_legal_evasions()

function gen_legal_evasions( list, board, attack ) -- void

   --ASSERT(444, list.size~=nil);
   --ASSERT(445, board.sp~=nil);
   --ASSERT(446, attack.dn~=nil);

   gen_evasions(list,board,attack,true,false);

   -- debug

   --ASSERT(447, list_is_ok(list));
end

-- gen_pseudo_evasions()

function gen_pseudo_evasions( list, board, attack ) -- void

   --ASSERT(448, list.size~=nil);
   --ASSERT(449, board.sp~=nil);
   --ASSERT(450, attack.dn~=nil);

   gen_evasions(list,board,attack,false,false);

   -- debug

   --ASSERT(451, list_is_ok(list));
end

-- legal_evasion_exist()

function legal_evasion_exist( board, attack )  -- bool

   local list = list_t();  -- list[1] dummy

   --ASSERT(452, board.sp~=nil);
   --ASSERT(453, attack.dn~=nil);

   return gen_evasions(list,board,attack,true,true);
end

-- gen_evasions()

function gen_evasions( list, board, attack, legal, stop )  -- bool
   local me = 0;         -- int
   local opp = 0;        -- int
   local opp_flag = 0;   -- int
   local king = 0;       -- int
   local inc_ptr = 0;    -- int
   local inc = 0;        -- int
   local to = 0;         -- int
   local piece = 0;      -- int

   --ASSERT(454, list.size~=nil);
   --ASSERT(455, board.sp~=nil);
   --ASSERT(456, attack.dn~=nil);
   --ASSERT(457, legal==true or legal==false);
   --ASSERT(458, stop==true or stop==false);

   --ASSERT(459, board_is_check(board));
   --ASSERT(460, ATTACK_IN_CHECK(attack));

   -- init

   list.size=0;

   me = board.turn;
   opp = COLOUR_OPP(me);

   opp_flag = COLOUR_FLAG(opp);

   king = KING_POS(board,me);

   inc_ptr = 0;
   while(true) do
      inc = KingInc[1+inc_ptr];
      if( inc == IncNone ) then
        break;
      end
        -- avoid escaping along a check line
      if (inc ~= -attack.di[1+0]  and  inc ~= -attack.di[1+1]) then
         to = king + inc;
         piece = board.square[1+to];
         if (piece == Empty  or  FLAG_IS(piece,opp_flag)) then
            if (not legal  or  not is_attacked(board,to,opp)) then
               if (stop) then
                 return true;
               end
               LIST_ADD(list,MOVE_MAKE(king,to));
            end
         end
      end

      inc_ptr = inc_ptr + 1;
   end


   if (attack.dn >= 2) then
     return false; -- double check, we are done
   end

   -- single check

   --ASSERT(461, attack.dn==1);

   -- capture the checking piece

   if (add_pawn_captures(list,board,attack.ds[1+0],legal,stop)  and  stop) then
     return true;
   end
   if (add_piece_moves(list,board,attack.ds[1+0],legal,stop)  and  stop) then
     return true;
   end

   -- interpose a piece

   inc = attack.di[1+0];

   if (inc ~= IncNone) then -- line
      to = king+inc;
      while( to ~= attack.ds[1+0] ) do

        --ASSERT(462, SQUARE_IS_OK(to));
        --ASSERT(463, board.square[1+to]==Empty);
        if (add_pawn_moves(list,board,to,legal,stop)  and  stop) then
          return true;
        end
        if (add_piece_moves(list,board,to,legal,stop)  and  stop) then
          return true;
        end
        to = to + inc;
      end
   end

   return false;

end

-- add_pawn_moves()

function add_pawn_moves( list, board, to, legal, stop )  -- bool
   local me = 0;      -- int
   local inc = 0;     -- int
   local pawn = 0;    -- int
   local from = 0;    -- int
   local piece = 0;   -- int

   --ASSERT(464, list.size~=nil);
   --ASSERT(465, board.sp~=nil);
   --ASSERT(466, SQUARE_IS_OK(to));
   --ASSERT(467, legal==true or legal==false);
   --ASSERT(468, stop==true or stop==false);

   --ASSERT(469, board.square[1+to]==Empty);

   me = board.turn;

   inc = PawnMoveInc[1+me];
   pawn = PawnMake[1+me];

   from = to - inc;
   piece = board.square[1+from];

   if (piece == pawn) then  -- single push

      if ((not legal)  or  (not is_pinned(board,from,me))) then
         if (stop) then
           return true;
         end
         add_pawn_move(list,from,to);
      end

   else
    if (piece == Empty  and  PAWN_RANK(to,me) == Rank4)  then   -- double push

      from = to - (2*inc);
      if (board.square[1+from] == pawn) then
         if ((not legal)  or  (not is_pinned(board,from,me))) then
            if (stop) then
              return true;
            end
            --ASSERT(470, not SquareIsPromote[1+to]);
            LIST_ADD(list,MOVE_MAKE(from,to));
         end
      end
    end
   end

   return false;
end

-- add_pawn_captures()

function add_pawn_captures( list, board, to, legal, stop ) -- bool
   local me = 0;     -- int
   local inc = 0;    -- int
   local pawn = 0;   -- int
   local from = 0;   -- int

   --ASSERT(471, list.size~=nil);
   --ASSERT(472, board.sp~=nil);
   --ASSERT(473, SQUARE_IS_OK(to));
   --ASSERT(474, legal==true or legal==false);
   --ASSERT(475, stop==true or stop==false);

   --ASSERT(476, COLOUR_IS(board.square[1+to],COLOUR_OPP(board.turn)));

   me = board.turn;

   inc = PawnMoveInc[1+me];
   pawn = PawnMake[1+me];

   from = to - (inc-1);
   if (board.square[1+from] == pawn) then
      if ((not legal)  or  (not is_pinned(board,from,me))) then
         if (stop) then
           return true;
         end
         add_pawn_move(list,from,to);
      end
   end

   from = to - (inc+1);
   if (board.square[1+from] == pawn) then
      if ((not legal)  or  (not is_pinned(board,from,me))) then
         if (stop) then
           return true;
         end
         add_pawn_move(list,from,to);
      end
   end

   if (board.ep_square ~= SquareNone and  to == SQUARE_EP_DUAL(board.ep_square)) then

      --ASSERT(477, PAWN_RANK(to,me)==Rank5);
      --ASSERT(478, PIECE_IS_PAWN(board.square[1+to]));

      to = board.ep_square;
      --ASSERT(479, PAWN_RANK(to,me)==Rank6);
      --ASSERT(480, board.square[1+to]==Empty);

      from = to - (inc-1);
      if (board.square[1+from] == pawn) then
         if ((not legal)  or  (not is_pinned(board,from,me))) then
            if (stop) then
              return true;
            end
            --ASSERT(481, not SquareIsPromote[1+to]);
            LIST_ADD(list,MOVE_MAKE_FLAGS(from,to,MoveEnPassant));
         end
      end

      from = to - (inc+1);
      if (board.square[1+from] == pawn) then
         if ((not legal)  or  (not is_pinned(board,from,me))) then
            if (stop) then
              return true;
            end
            --ASSERT(482, not SquareIsPromote[1+to]);
            LIST_ADD(list,MOVE_MAKE_FLAGS(from,to,MoveEnPassant));
         end
      end
   end

   return false;
end

-- add_piece_moves()

function add_piece_moves( list, board, to, legal, stop)  -- bool
   local me = 0;      -- int
   local ptr = 0;     -- int
   local from = 0;    -- int
   local piece = 0;   -- int

   --ASSERT(483, list.size~=nil);
   --ASSERT(484, board.sp~=nil);
   --ASSERT(485, SQUARE_IS_OK(to));
   --ASSERT(486, legal==true or legal==false);
   --ASSERT(487, stop==true or stop==false);

   me = board.turn;

   ptr = 1;            -- HACK: no king
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      if (PIECE_ATTACK(board,piece,from,to)) then
         if ((not legal)  or  (not is_pinned(board,from,me))) then
            if (stop) then
              return true;
            end
            LIST_ADD(list,MOVE_MAKE(from,to));
         end
      end

      ptr = ptr + 1;
   end

   return false;

end

-- end of move_evasion.cpp



-- move_gen.cpp

-- functions

-- gen_legal_moves()

function gen_legal_moves( list, board )  -- void

   local attack = attack_t();  -- attack_t[1]

   --ASSERT(488, list.size~=nil);
   --ASSERT(489, board.sp~=nil);

   attack_set(attack,board);

   if (ATTACK_IN_CHECK(attack)) then
      gen_legal_evasions(list,board,attack);
   else
      gen_moves(list,board);
      list_filter(list,board, true);
   end

   -- debug

   --ASSERT(490, list_is_ok(list));
end

-- gen_moves()

function gen_moves( list, board ) -- void

   --ASSERT(491, list.size~=nil);
   --ASSERT(492, board.sp~=nil);

   --ASSERT(493, not board_is_check(board));

   list.size=0;

   add_moves(list,board);

   add_en_passant_captures(list,board);
   add_castle_moves(list,board);

   -- debug

   --ASSERT(494, list_is_ok(list));
end

-- gen_captures()

function gen_captures( list, board ) -- void

   --ASSERT(495, list.size~=nil);
   --ASSERT(496, board.sp~=nil);

   list.size=0;

   add_captures(list,board);
   add_en_passant_captures(list,board);

   -- debug

   --ASSERT(497, list_is_ok(list));
end

-- gen_quiet_moves()

function gen_quiet_moves( list, board ) -- void

   --ASSERT(498, list.size~=nil);
   --ASSERT(499, board.sp~=nil);

   --ASSERT(500, not board_is_check(board));

   list.size=0;

   add_quiet_moves(list,board);
   add_castle_moves(list,board);

   -- debug

   --ASSERT(501, list_is_ok(list));
end

-- add_moves()

function add_moves( list, board ) -- void

   local me = 0;         -- int
   local opp = 0;        -- int
   local opp_flag = 0;   -- int
   local ptr = 0;        -- int
   local from = 0;       -- int
   local to = 0;         -- int
   local piece = 0;      -- int
   local capture = 0;    -- int
   local inc_ptr = 0;    -- int
   local inc = 0;        -- int

   --ASSERT(502, list.size~=nil);
   --ASSERT(503, board.sp~=nil);

   me = board.turn;
   opp = COLOUR_OPP(me);

   opp_flag = COLOUR_FLAG(opp);

   -- piece moves

   ptr = 0;
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      if (PIECE_IS_SLIDER(piece)) then

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from+inc;
           while(true) do
               capture=board.square[1+to];
               if( capture ~= Empty ) then
                 break;
               end

               LIST_ADD(list,MOVE_MAKE(from,to));

               to = to + inc;
           end

           if (FLAG_IS(capture,opp_flag)) then
              LIST_ADD(list,MOVE_MAKE(from,to));
           end

           inc_ptr = inc_ptr + 1;
         end

      else

         inc_ptr = 0;
         while(true) do
           inc = PieceInc[1+piece][1+inc_ptr];
           if( inc == IncNone ) then
             break;
           end

           to = from + inc;
           capture = board.square[1+to];
           if (capture == Empty  or  FLAG_IS(capture,opp_flag)) then
              LIST_ADD(list,MOVE_MAKE(from,to));
           end

           inc_ptr = inc_ptr + 1;
         end

      end

      ptr = ptr + 1;
   end


   -- pawn moves

   inc = PawnMoveInc[1+me];

   ptr = 0;
   while(true) do
      from = board.pawn[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      to = from + (inc-1);
      if (FLAG_IS(board.square[1+to],opp_flag)) then
         add_pawn_move(list,from,to);
      end

      to = from + (inc+1);
      if (FLAG_IS(board.square[1+to],opp_flag)) then
         add_pawn_move(list,from,to);
      end

      to = from + inc;
      if (board.square[1+to] == Empty) then
         add_pawn_move(list,from,to);
         if (PAWN_RANK(from,me) == Rank2) then
            to = from + (2*inc);
            if (board.square[1+to] == Empty) then
               --ASSERT(504, not SquareIsPromote[1+to]);
               LIST_ADD(list,MOVE_MAKE(from,to));
            end
         end
      end

      ptr = ptr + 1;
   end

end

--
function add_capt1 ( from, dt, list, board, opp_flag )
  local to = from + dt;
  if (FLAG_IS(board.square[1+to],opp_flag)) then
    LIST_ADD(list,MOVE_MAKE(from,to));
  end
end


--
function add_capt2( from, dt, list, board, opp_flag )
 local to = from + dt;
 local capture = 0;
 while(true) do
   capture=board.square[1+to];
   if(capture~=Empty) then
     break;
   end
   to = to + dt;
 end
 if (FLAG_IS(capture,opp_flag)) then
   LIST_ADD(list,MOVE_MAKE(from,to));
 end
end

--
function add_capt3( from, dt, list, board, opp_flag )
 local to = from + dt;
 if (FLAG_IS(board.square[1+to],opp_flag)) then
   add_pawn_move(list,from,to);
 end
end

--
function add_capt4( from, dt, list, board )
 local to = from + dt;
 if (board.square[1+to] == Empty) then
   add_promote(list,MOVE_MAKE(from,to));
 end
end

-- add_captures()

function add_captures( list, board ) -- void

   local me = 0;         -- int
   local opp = 0;        -- int
   local opp_flag = 0;   -- int
   local ptr = 0;        -- int
   local from = 0;       -- int
   local piece = 0;      -- int
   local p = 0;

   --ASSERT(505, list.size~=nil);
   --ASSERT(506, board.sp~=nil);

   me = board.turn;
   opp = COLOUR_OPP(me);

   opp_flag = COLOUR_FLAG(opp);

   -- piece captures

   ptr = 0;
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      p = PIECE_TYPE(piece);

      if(p == Knight64) then

         add_capt1 ( from, -33, list, board, opp_flag );
         add_capt1 ( from, -31, list, board, opp_flag );
         add_capt1 ( from, -18, list, board, opp_flag );
         add_capt1 ( from, -14, list, board, opp_flag );
         add_capt1 ( from, 14, list, board, opp_flag );
         add_capt1 ( from, 18, list, board, opp_flag );
         add_capt1 ( from, 31, list, board, opp_flag );
         add_capt1 ( from, 33, list, board, opp_flag );
      else

       if(p == Bishop64) then

         add_capt2 ( from, -17, list, board, opp_flag );
         add_capt2 ( from, -15, list, board, opp_flag );
         add_capt2 ( from, 15, list, board, opp_flag );
         add_capt2 ( from, 17, list, board, opp_flag );

       else

        if(p == Rook64) then

          add_capt2 ( from, -16, list, board, opp_flag );
          add_capt2 ( from, -1, list, board, opp_flag );
          add_capt2 ( from, 1, list, board, opp_flag );
          add_capt2 ( from, 16, list, board, opp_flag );

        else

         if(p == Queen64) then

            add_capt2 ( from, -17, list, board, opp_flag );
            add_capt2 ( from, -16, list, board, opp_flag );
            add_capt2 ( from, -15, list, board, opp_flag );
            add_capt2 ( from, -1, list, board, opp_flag );
            add_capt2 ( from, 1, list, board, opp_flag );
            add_capt2 ( from, 15, list, board, opp_flag );
            add_capt2 ( from, 16, list, board, opp_flag );
            add_capt2 ( from, 17, list, board, opp_flag );

         else

           if(p == King64) then

              add_capt1 ( from, -17, list, board, opp_flag );
              add_capt1 ( from, -16, list, board, opp_flag );
              add_capt1 ( from, -15, list, board, opp_flag );
              add_capt1 ( from, -1, list, board, opp_flag );
              add_capt1 ( from, 1, list, board, opp_flag );
              add_capt1 ( from, 15, list, board, opp_flag );
              add_capt1 ( from, 16, list, board, opp_flag );
              add_capt1 ( from, 17, list, board, opp_flag );

           else

              --ASSERT(507, false);

           end
         end
        end
       end
      end

      ptr = ptr + 1;
   end

   -- pawn captures

   if (COLOUR_IS_WHITE(me)) then

      ptr = 0;
      while(true) do
         from = board.pawn[1+me][1+ptr];
         if( from == SquareNone ) then
           break;
         end

         add_capt3 ( from, 15, list, board, opp_flag );
         add_capt3 ( from, 17, list, board, opp_flag );

         -- promote

         if (SQUARE_RANK(from) == Rank7) then
            add_capt4 ( from, 16, list, board );
         end

         ptr = ptr + 1;
      end

   else  -- black

      ptr = 0;
      while(true) do
         from = board.pawn[1+me][1+ptr];
         if( from == SquareNone ) then
           break;
         end

         add_capt3 ( from, -17, list, board, opp_flag );
         add_capt3 ( from, -15, list, board, opp_flag );

         -- promote

         if (SQUARE_RANK(from) == Rank2) then
            add_capt4 ( from, -16, list, board );
         end

         ptr = ptr + 1;
      end

   end

end


--
function add_quietm1( from, dt, list, board )
 local to = from + dt;
 if (board.square[1+to] == Empty) then
   LIST_ADD(list,MOVE_MAKE(from,to));
 end
end

--
function add_quietm2( from, dt, list, board )
 local to = from + dt;
 while(true) do
   if(board.square[1+to]~=Empty) then
     break;
   end
   LIST_ADD(list,MOVE_MAKE(from,to));
   to = to + dt;
 end
end

-- add_quiet_moves()

function add_quiet_moves( list, board ) -- void

   local me = 0;         -- int
   local ptr = 0;        -- int
   local from = 0;       -- int
   local to = 0;         -- int
   local piece = 0;      -- int
   local p = 0;


   --ASSERT(508, list.size~=nil);
   --ASSERT(509, board.sp~=nil);

   me = board.turn;

   -- piece moves

   ptr = 0;
   while(true) do
      from = board.piece[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      piece = board.square[1+from];

      p = PIECE_TYPE(piece);

      if(p == Knight64) then

         add_quietm1 ( from, -33, list, board );
         add_quietm1 ( from, -31, list, board );
         add_quietm1 ( from, -18, list, board );
         add_quietm1 ( from, -14, list, board );
         add_quietm1 ( from, 14, list, board );
         add_quietm1 ( from, 18, list, board );
         add_quietm1 ( from, 31, list, board );
         add_quietm1 ( from, 33, list, board );
      else

       if(p == Bishop64) then

         add_quietm2 ( from, -17, list, board );
         add_quietm2 ( from, -15, list, board );
         add_quietm2 ( from, 15, list, board );
         add_quietm2 ( from, 17, list, board );

       else

        if(p == Rook64) then

          add_quietm2 ( from, -16, list, board );
          add_quietm2 ( from, -1, list, board );
          add_quietm2 ( from, 1, list, board );
          add_quietm2 ( from, 16, list, board );

        else

         if(p == Queen64) then

            add_quietm2 ( from, -17, list, board );
            add_quietm2 ( from, -16, list, board );
            add_quietm2 ( from, -15, list, board );
            add_quietm2 ( from, -1, list, board );
            add_quietm2 ( from, 1, list, board );
            add_quietm2 ( from, 15, list, board );
            add_quietm2 ( from, 16, list, board );
            add_quietm2 ( from, 17, list, board );

         else

           if(p == King64) then

              add_quietm1 ( from, -17, list, board );
              add_quietm1 ( from, -16, list, board );
              add_quietm1 ( from, -15, list, board );
              add_quietm1 ( from, -1, list, board );
              add_quietm1 ( from, 1, list, board );
              add_quietm1 ( from, 15, list, board );
              add_quietm1 ( from, 16, list, board );
              add_quietm1 ( from, 17, list, board );

           else

              --ASSERT(510, false);

           end
         end
        end
       end
      end

      ptr = ptr + 1;
   end

   -- pawn moves

   if (COLOUR_IS_WHITE(me)) then

      ptr = 0;
      while(true) do
         from = board.pawn[1+me][1+ptr];
         if( from == SquareNone ) then
           break;
         end

         -- non promotes

         if (SQUARE_RANK(from) ~= Rank7) then
            to = from + 16;
            if (board.square[1+to] == Empty) then
               --ASSERT(511, not SquareIsPromote[1+to]);
               LIST_ADD(list,MOVE_MAKE(from,to));
               if (SQUARE_RANK(from) == Rank2) then
                  to = from + 32;
                  if (board.square[1+to] == Empty) then
                     --ASSERT(512, not SquareIsPromote[1+to]);
                     LIST_ADD(list,MOVE_MAKE(from,to));
                  end
               end
            end
         end

         ptr = ptr + 1;
      end

   else  -- black

      ptr = 0;
      while(true) do
         from = board.pawn[1+me][1+ptr];
         if( from == SquareNone ) then
           break;
         end

         -- non promotes

         if (SQUARE_RANK(from) ~= Rank2) then
            to = from - 16;
            if (board.square[1+to] == Empty) then
               --ASSERT(513, not SquareIsPromote[1+to]);
               LIST_ADD(list,MOVE_MAKE(from,to));
               if (SQUARE_RANK(from) == Rank7) then
                  to = from - 32;
                  if (board.square[1+to] == Empty) then
                     --ASSERT(514, not SquareIsPromote[1+to]);
                     LIST_ADD(list,MOVE_MAKE(from,to));
                  end
               end
            end
         end

         ptr = ptr + 1;
      end

   end

end

-- add_promotes()

function add_promotes( list, board ) -- void

   local me = 0;    -- int
   local inc = 0;   -- int
   local ptr = 0;   -- int
   local from = 0;  -- int
   local to = 0;    -- int

   --ASSERT(515, list.size~=nil);
   --ASSERT(516, board.sp~=nil);

   me = board.turn;

   inc = PawnMoveInc[1+me];

   ptr = 0;
   while(true) do
      from = board.pawn[1+me][1+ptr];
      if( from == SquareNone ) then
        break;
      end

      if (PAWN_RANK(from,me) == Rank7) then
         add_capt4 ( from, inc, list, board );
         to = from + inc;
      end

      ptr = ptr + 1;
   end
end

-- add_en_passant_captures()

function add_en_passant_captures( list, board ) -- void

   local from = 0;  -- int
   local to = 0;    -- int
   local me = 0;    -- int
   local inc = 0;   -- int
   local pawn = 0;  -- int

   --ASSERT(517, list.size~=nil);
   --ASSERT(518, board.sp~=nil);

   to = board.ep_square;

   if (to ~= SquareNone) then

      me = board.turn;

      inc = PawnMoveInc[1+me];
      pawn = PawnMake[1+me];

      from = to - (inc-1);
      if (board.square[1+from] == pawn) then
         --ASSERT(519, not SquareIsPromote[1+to]);
         LIST_ADD(list,MOVE_MAKE_FLAGS(from,to,MoveEnPassant));
      end

      from = to - (inc+1);
      if (board.square[1+from] == pawn) then
         --ASSERT(520, not SquareIsPromote[1+to]);
         LIST_ADD(list,MOVE_MAKE_FLAGS(from,to,MoveEnPassant));
      end

   end

end

-- add_castle_moves()

function add_castle_moves( list, board ) -- void

   --ASSERT(521, list.size~=nil);
   --ASSERT(522, board.sp~=nil);

   --ASSERT(523, not board_is_check(board));

   if (COLOUR_IS_WHITE(board.turn)) then

      if ( bit.band( board.flags, FlagsWhiteKingCastle ) ~= 0
        and  board.square[1+F1] == Empty
        and  board.square[1+G1] == Empty
        and  (not is_attacked(board,F1,Black))) then
         LIST_ADD(list,MOVE_MAKE_FLAGS(E1,G1,MoveCastle));
      end

      if ( bit.band( board.flags, FlagsWhiteQueenCastle ) ~= 0
        and  board.square[1+D1] == Empty
        and  board.square[1+C1] == Empty
        and  board.square[1+B1] == Empty
        and  (not is_attacked(board,D1,Black))) then
         LIST_ADD(list,MOVE_MAKE_FLAGS(E1,C1,MoveCastle));
      end

   else  -- black

      if ( bit.band( board.flags, FlagsBlackKingCastle ) ~= 0
        and  board.square[1+F8] == Empty
        and  board.square[1+G8] == Empty
        and  (not is_attacked(board,F8,White))) then
         LIST_ADD(list,MOVE_MAKE_FLAGS(E8,G8,MoveCastle));
      end

      if ( bit.band( board.flags, FlagsBlackQueenCastle ) ~= 0
        and  board.square[1+D8] == Empty
        and  board.square[1+C8] == Empty
        and  board.square[1+B8] == Empty
        and  (not is_attacked(board,D8,White))) then
         LIST_ADD(list,MOVE_MAKE_FLAGS(E8,C8,MoveCastle));
      end
   end
end

-- add_pawn_move()

function add_pawn_move( list, from, to )  -- void

   local move = 0;   -- int

   --ASSERT(524, list.size~=nil);
   --ASSERT(525, SQUARE_IS_OK(from));
   --ASSERT(526, SQUARE_IS_OK(to));

   move = MOVE_MAKE(from,to);

   if (SquareIsPromote[1+to]) then
      LIST_ADD(list,bit.bor(move,MovePromoteQueen));
      LIST_ADD(list,bit.bor(move,MovePromoteKnight));
      LIST_ADD(list,bit.bor(move,MovePromoteRook));
      LIST_ADD(list,bit.bor(move,MovePromoteBishop));
   else
      LIST_ADD(list,move);
   end
end

-- add_promote()

function add_promote( list, move )  -- void

   --ASSERT(527, list.size~=nil);
   --ASSERT(528, move_is_ok(move));

   --ASSERT(529, bit.band(move,bnotV07777)==0); -- HACK
   --ASSERT(530, SquareIsPromote[1+MOVE_TO(move)]);

   LIST_ADD(list,bit.bor(move,MovePromoteQueen));
   LIST_ADD(list,bit.bor(move,MovePromoteKnight));
   LIST_ADD(list,bit.bor(move,MovePromoteRook));
   LIST_ADD(list,bit.bor(move,MovePromoteBishop));
end

-- end of move_gen.cpp




-- move_legal.cpp

-- functions

-- move_is_pseudo()

function move_is_pseudo( move, board ) -- bool

   local me = 0;      -- int
   local opp = 0;     -- int
   local from = 0;    -- int
   local to = 0;      -- int
   local piece = 0;   -- int
   local capture = 0; -- int
   local inc = 0;     -- int
   local delta = 0;   -- int

   --ASSERT(531, move_is_ok(move));
   --ASSERT(532, board.sp~=nil);

   --ASSERT(533, not board_is_check(board));

   -- special cases

   if (MOVE_IS_SPECIAL(move)) then
      return move_is_pseudo_debug(move,board);
   end

   --ASSERT(534, bit.band(move,bnotV07777)==0);

   -- init

   me = board.turn;
   opp = COLOUR_OPP(board.turn);

   -- from

   from = MOVE_FROM(move);
   --ASSERT(535, SQUARE_IS_OK(from));

   piece = board.square[1+from];
   if (not COLOUR_IS(piece,me)) then
     return false;
   end

   --ASSERT(536, piece_is_ok(piece));

   -- to

   to = MOVE_TO(move);
   --ASSERT(537, SQUARE_IS_OK(to));

   capture = board.square[1+to];
   if (COLOUR_IS(capture,me)) then
     return false;
   end

   -- move

   if (PIECE_IS_PAWN(piece)) then

      if (SquareIsPromote[1+to]) then
        return false;
      end

      inc = PawnMoveInc[1+me];
      delta = to - from;
      --ASSERT(538, delta_is_ok(delta));

      if (capture == Empty) then

         -- pawn push

         if (delta == inc) then
           return true;
         end

         if (delta == (2*inc)
           and  PAWN_RANK(from,me) == Rank2
           and  board.square[1+from+inc] == Empty) then
            return true;
         end

      else

         -- pawn capture

         if (delta == (inc-1)  or  delta == (inc+1)) then
           return true;
         end
      end

   else

      if (PIECE_ATTACK(board,piece,from,to)) then
        return true;
      end
   end

   return false;
end

-- quiet_is_pseudo()

function quiet_is_pseudo( move, board )  -- bool

   local me = 0;      -- int
   local opp = 0;     -- int
   local from = 0;    -- int
   local to = 0;      -- int
   local piece = 0;   -- int
   local inc = 0;     -- int
   local delta = 0;   -- int

   --ASSERT(539, move_is_ok(move));
   --ASSERT(540, board.sp~=nil);

   --ASSERT(541, not board_is_check(board));

   -- special cases

   if (MOVE_IS_CASTLE(move)) then
      return move_is_pseudo_debug(move,board);
   else
    if (MOVE_IS_SPECIAL(move)) then
      return false;
    end
   end

   --ASSERT(542, bit.band(move,bnotV07777)==0);

   -- init

   me = board.turn;
   opp = COLOUR_OPP(board.turn);

   -- from

   from = MOVE_FROM(move);
   --ASSERT(543, SQUARE_IS_OK(from));

   piece = board.square[1+from];
   if (not COLOUR_IS(piece,me)) then
     return false;
   end

   --ASSERT(544, piece_is_ok(piece));

   -- to

   to = MOVE_TO(move);
   --ASSERT(545, SQUARE_IS_OK(to));

   if (board.square[1+to] ~= Empty) then
     return false; -- capture
   end

   -- move

   if (PIECE_IS_PAWN(piece)) then

      if (SquareIsPromote[1+to]) then
        return false;
      end

      inc = PawnMoveInc[1+me];
      delta = to - from;
      --ASSERT(546, delta_is_ok(delta));

      -- pawn push

      if (delta == inc) then
        return true;
      end

      if (delta == (2*inc)
        and  PAWN_RANK(from,me) == Rank2
        and  board.square[1+from+inc] == Empty) then
         return true;
      end

   else

      if (PIECE_ATTACK(board,piece,from,to)) then
        return true;
      end
   end

   return false;
end

-- pseudo_is_legal()

function pseudo_is_legal( move, board ) -- bool

   local opp = 0;        -- int
   local me = 0;         -- int
   local from = 0;       -- int
   local to = 0;         -- int
   local piece = 0;      -- int
   local legal = false;  -- bool
   local king = 0;       -- int
   local undo = undo_t();  --undo_t[1]

   --ASSERT(547, move_is_ok(move));
   --ASSERT(548, board.sp~=nil);

   -- init

   me = board.turn;
   opp = COLOUR_OPP(me);

   from = MOVE_FROM(move);
   to = MOVE_TO(move);

   piece = board.square[1+from];
   --ASSERT(549, COLOUR_IS(piece,me));

   -- slow test for en-passant captures

   if (MOVE_IS_EN_PASSANT(move)) then

      move_do(board,move,undo);
      legal = not IS_IN_CHECK(board,me);
      move_undo(board,move,undo);

      return legal;
   end

   -- king moves (including castle)

   if (PIECE_IS_KING(piece)) then

      legal = not is_attacked(board,to,opp);

      if (iDbg01) then
         --ASSERT(550, board.square[1+from]==piece);
         board.square[1+from] = Empty;
         --ASSERT(551, legal==not is_attacked(board,to,opp));
         board.square[1+from] = piece;
      end

      return legal;
   end

   -- pins

   if (is_pinned(board,from,me)) then
      king = KING_POS(board,me);
      return (DELTA_INC_LINE(king-to) == DELTA_INC_LINE(king-from)); -- does not discover the line
   end

   return true;
end

-- move_is_pseudo_debug()

function move_is_pseudo_debug ( move, board) -- bool

   local list = list_t();  --list_t[1]

   --ASSERT(552, move_is_ok(move));
   --ASSERT(553, board.sp~=nil);

   --ASSERT(554, not board_is_check(board));

   gen_moves(list,board);

   return list_contain(list,move);
end

-- end of move_legal.cpp



-- option.cpp

-- functions

-- option_init()

function option_init() -- void

   local opt = nil;
   local i = 0;

   -- options are as they are for the execuatable version
   Option[1] = opt_t_def( "Hash",  false, "16", "spin", "min 4 max 1024", nil );
   Option[2] = opt_t_def( "Ponder",  false, "false", "check", "", nil );
   Option[3] = opt_t_def( "OwnBook",  false, "false", "check", "", nil );
   Option[4] = opt_t_def( "BookFile",   false, "book_small.bin", "string", "", nil );
   Option[5] = opt_t_def( "nilMove Pruning",  true, "Fail High", "combo", "var Always var Fail High var Never", nil );
   Option[6] = opt_t_def( "nilMove Reduction",  true, "3", "spin", "min 1 max 3", nil );
   Option[7] = opt_t_def( "Verification Search",  true, "Endgame", "combo", "var Always var Endgame var Never", nil );
   Option[8] = opt_t_def( "Verification Reduction",  true, "5", "spin", "min 1 max 6", nil );
   Option[9] = opt_t_def( "History Pruning", true, "true", "check", "", nil );
   Option[10] = opt_t_def( "History Threshold",  true, "60", "spin", "min 0 max 100", nil );
   Option[11] = opt_t_def( "Futility Pruning",  true, "false", "check", "", nil );
   Option[12] = opt_t_def( "Futility Margin",  true, "100", "spin",  "min 0 max 500", nil );
   Option[13] = opt_t_def( "Delta Pruning",  true, "false", "check", "", nil );
   Option[14] = opt_t_def( "Delta Margin",  true, "50", "spin",  "min 0 max 500", nil );
   Option[15] = opt_t_def( "Quiescence Check Plies", true, "1", "spin", "min 0 max 2", nil );
   Option[16] = opt_t_def( "Material",  true, "100", "spin", "min 0 max 400", nil );
   Option[17] = opt_t_def( "Piece Activity",  true, "100", "spin", "min 0 max 400", nil );
   Option[18] = opt_t_def( "King Safety",  true, "100", "spin", "min 0 max 400", nil );
   Option[19] = opt_t_def( "Pawn Structure",  true, "100", "spin", "min 0 max 400", nil );
   Option[20] = opt_t_def( "Passed Pawns",  true, "100", "spin", "min 0 max 400", nil );
   Option[21] = opt_t_def( nil, false, nil, nil, nil, nil );


   while(true) do
     opt = Option[1+i];
     if( opt.var == nil ) then
       break;
     end
     option_set( opt.var, opt.init );
     i = i + 1;
   end
end

-- option_list()

function option_list() -- void

   local opt = nil;
   local i = 0;

   while(true) do
     opt = Option[1+i];
     if( opt.var == nil ) then
       break;
     end

     if (opt.declare) then
         send("option name ".. opt.var .." type ".. opt.type .." default ".. opt.val .. opt.extra);
     end

     i = i + 1;
   end
end

-- option_set()

function option_set( var, val )  -- bool

   local i = 0;

   --ASSERT(555, var~=nil);
   --ASSERT(556, val~=nil);

   i = option_find(var);
   if (i == nil) then return
     false;
   end

   Option[1+i].val = val;

   return true;
end

-- option_get()

function option_get( var ) -- string

   local i = 0;

   --ASSERT(557, var~=nil);

   i = option_find(var);
   if (i == nil) then return
     my_fatal("option_get(): unknown option : ".. var .. "\n");
   end

   return Option[1+i].val;
end

-- option_get_bool()

function option_get_bool( var ) -- const bool

   local val = option_get(var);   -- string

   if (string_equal(val,"true")  or  string_equal(val,"yes")  or  string_equal(val,"1")) then
      return true;
   else
    if (string_equal(val,"false")  or  string_equal(val,"no")  or  string_equal(val,"0")) then
      return false;
    end
   end

   --ASSERT(558, false);

   return false;
end

-- option_get_int()

function option_get_int( var )  -- int
   return tonumber( option_get(var) );
end

-- option_get_string()

function option_get_string( var ) -- string
   return option_get(var);
end

-- option_find()

function option_find( var ) -- int

   local opt = nil;
   local i = 0;

   --ASSERT(559, var~=nil);

   while(true) do
     opt = Option[1+i];
     if( opt.var == nil ) then
       break;
     end

     if (string_equal(opt.var,var)) then
       return i;
     end


     i = i + 1;
   end

   return nil;
end

-- end of option.cpp



-- pawn.cpp

-- functions

-- pawn_init_bit()

function pawn_init_bit()  -- void

   local rank = 0;   -- int
   local first = 0;  -- int
   local last = 0;   -- int
   local count = 0;  -- int
   local b = 0;      -- int
   local rev = 0;    -- int


   -- rank-indexed Bit*[]

   for rank = 0, RankNb-1, 1 do

      BitEQ[1+rank] = 0;
      BitLT[1+rank] = 0;
      BitLE[1+rank] = 0;
      BitGT[1+rank] = 0;
      BitGE[1+rank] = 0;

      BitRank1[1+rank] = 0;
      BitRank2[1+rank] = 0;
      BitRank3[1+rank] = 0;
   end

   for rank = Rank1, Rank8, 1 do
      BitEQ[1+rank] = bit.lshift( 1, rank - Rank1);
      BitLT[1+rank] = BitEQ[1+rank] - 1;
      BitLE[1+rank] = bit.bor( BitLT[1+rank], BitEQ[1+rank] );
      BitGT[1+rank] = bit.bxor( BitLE[1+rank], 0xFF );
      BitGE[1+rank] = bit.bor( BitGT[1+rank], BitEQ[1+rank]);
   end

   for rank = Rank1, Rank8, 1 do
      BitRank1[1+rank] = BitEQ[1+rank+1];
      BitRank2[1+rank] = bit.bor( BitEQ[1+rank+1], BitEQ[1+rank+2]) ;
      BitRank3[1+rank] = bit.bor( bit.bor( BitEQ[1+rank+1], BitEQ[1+rank+2] ) , BitEQ[1+rank+3] );
   end

   -- bit-indexed Bit*[1+]

   for b = 0, 0x100-1, 1 do

      first = Rank8;  -- HACK for pawn shelter
      last = Rank1;   -- HACK
      count = 0;
      rev = 0;

      for rank = Rank1, Rank8, 1 do
         if ( bit.band( b, BitEQ[1+rank] ) ~= 0) then
            if (rank < first) then
              first = rank;
            end
            if (rank > last) then
              last = rank;
            end
            count = count + 1;
            rev = bit.bor( rev, BitEQ[1+RANK_OPP(rank)] );
         end
      end

      BitFirst[1+b] = first;
      BitLast[1+b] = last;
      BitCount[1+b] = count;
      BitRev[1+b] = rev;
   end

end

-- pawn_init()

function pawn_init() -- void

   local rank = 0;   -- int

   -- UCI options

   PawnStructureWeight = (option_get_int("Pawn Structure") * 256 + 50) / 100;

   -- bonus

   for rank = 0, RankNb-1, 1 do

     Bonus[1+rank] = 0;
   end

   Bonus[1+Rank4] = 26;
   Bonus[1+Rank5] = 77;
   Bonus[1+Rank6] = 154;
   Bonus[1+Rank7] = 256;

   -- pawn hash-table

   Pawn.size = 0;
   Pawn.mask = 0;

end

-- pawn_alloc()

function pawn_alloc()  -- void

   --ASSERT(560, true );   -- sizeof(entry_t)==16

   if (UseTable) then

      Pawn.size = PawnTableSize;
      Pawn.mask = Pawn.size - 1;     -- 2^x -1
      -- Pawn.table = (entry_t *) my_malloc(Pawn.size*sizeof(entry_t));
      pawn_clear();
   end

end

-- pawn_clear()

function pawn_clear()  -- void

   local i = 0;

   Pawn.table = {};
   Pawn.used = 0;
   Pawn.read_nb = 0;
   Pawn.read_hit = 0;
   Pawn.write_nb = 0;
   Pawn.write_collision = 0;

end

-- pawn_get_info()

function pawn_get_info( info, board ) -- const

   local key = 0;           -- uint64
   local entry = nil        -- entry_t *;
   local index = 0;

   --ASSERT(561, info.lock~=nil);
   --ASSERT(562, board.sp~=nil);

   -- probe

  if (UseTable) then

      Pawn.read_nb = Pawn.read_nb + 1;

      key = board.pawn_key;
      index = bit.band( KEY_INDEX(key), Pawn.mask );

      entry = Pawn.table[1+index];
      if(entry == nil or entry.lock == nil) then
        Pawn.table[1+index] = pawn_info_t();
        entry = Pawn.table[1+index];
      end

      if (entry.lock == KEY_LOCK(key)) then

         -- found

         Pawn.read_hit = Pawn.read_hit + 1;

         pawn_info_copy( info, entry );

         return;
      end
   end

   -- calculation

   pawn_comp_info(info,board);

   -- store

   if (UseTable) then

      Pawn.write_nb = Pawn.write_nb + 1;

      if (entry.lock == 0) then    -- HACK: assume free entry
         Pawn.used = Pawn.used + 1;
      else
         Pawn.write_collision = Pawn.write_collision + 1;
      end

      pawn_info_copy( entry, info );

      entry.lock = KEY_LOCK(key);
   end

end

-- pawn_comp_info()

function pawn_comp_info( info, board ) -- void

   local colour = 0;   -- int
   local file = 0;     -- int
   local rank = 0;     -- int
   local me = 0;       -- int
   local opp = 0;      -- int
   local ptr = 0;      -- int
   local sq = 0;       -- int
   local backward = false;    -- bool
   local candidate = false;   -- bool
   local doubled = false;     -- bool
   local isolated = false;    -- bool
   local open = false;        -- bool
   local passed = false;      -- bool
   local t1 = 0;        -- int
   local t2 = 0;        -- int
   local n = 0;         -- int
   local bits = 0;      -- int
   local opening = { 0, 0 };  -- int[ColourNb]
   local endgame = { 0, 0 };  -- int[ColourNb]
   local flags = { 0, 0 };    -- int[ColourNb]
   local file_bits = { 0, 0 };   -- int[ColourNb]
   local passed_bits = { 0, 0 }; -- int[ColourNb]
   local single_file = { 0, 0 }; -- int[ColourNb]
   local q = 0;
   local om = 0;
   local em = 0;

   --ASSERT(563, info.lock~=nil);
   --ASSERT(564, board.sp~=nil);

   -- pawn_file[]

-- #if DEBUG
   for colour = 0, 1, 1 do

      local pawn_file = {};   -- int[FileNb]

      me = colour;

      for file = 0, FileNb-1, 1 do
         pawn_file[1+file] = 0;
      end

      ptr = 0;
      while(true) do
         sq=board.pawn[1+me][1+ptr];
         if(sq==SquareNone) then
           break;
         end

         file = SQUARE_FILE(sq);
         rank = PAWN_RANK(sq,me);

         --ASSERT(565, file>=FileA and file<=FileH);
         --ASSERT(566, rank>=Rank2 and rank<=Rank7);

         pawn_file[1+file] =  bit.bor( pawn_file[1+file] , BitEQ[1+rank] );

         ptr = ptr + 1;
      end

      for file = 0, FileNb-1, 1 do
         if (board.pawn_file[1+colour][1+file] ~= pawn_file[1+file]) then
           my_fatal("board.pawn_file[][]\n");
         end
      end
   end
-- #endif


   -- features and scoring

   for colour = 0, 1, 1 do

      me = colour;
      opp = COLOUR_OPP(me);

      ptr = 0;
      while(true) do
         sq=board.pawn[1+me][1+ptr];
         if(sq==SquareNone) then
           break;
         end


         -- init

         file = SQUARE_FILE(sq);
         rank = PAWN_RANK(sq,me);

         --ASSERT(567, file>=FileA and file<=FileH);
         --ASSERT(568, rank>=Rank2 and rank<=Rank7);

         -- flags

         file_bits[1+me] = bit.bor( file_bits[1+me], BitEQ[1+file] );
         if (rank == Rank2) then
            flags[1+me] = bit.bor( flags[1+me], BackRankFlag );
         end

         -- features

         backward = false;
         candidate = false;
         doubled = false;
         isolated = false;
         open = false;
         passed = false;

         t1 = bit.bor( board.pawn_file[1+me][1+file-1], board.pawn_file[1+me][1+file+1] );
         t2 = bit.bor( board.pawn_file[1+me][1+file], BitRev[1+board.pawn_file[1+opp][1+file]] );

         -- doubled

         if ( bit.band( board.pawn_file[1+me][1+file] , BitLT[1+rank] ) ~= 0) then
            doubled = true;
         end

         -- isolated and backward

         if (t1 == 0) then

            isolated = true;

         else
          if ( bit.band( t1, BitLE[1+rank] ) == 0) then

            backward = true;

            -- really backward?

            if ( bit.band( t1, BitRank1[1+rank] ) ~= 0) then

               --ASSERT(569, rank+2<=Rank8);
               q = bit.band(t2,BitRank1[1+rank]);
               q = bit.bor(q,BitRev[1+board.pawn_file[1+opp][1+file-1]]);
               q = bit.bor(q,BitRev[1+board.pawn_file[1+opp][1+file+1]]);

               if ( bit.band( q, BitRank2[1+rank] ) == 0) then

                  backward = false;
               end

            else
             if (rank == Rank2  and  ( bit.band( t1 , BitEQ[1+rank+2] ) ~= 0)) then

               --ASSERT(570, rank+3<=Rank8);
               q = bit.band(t2,BitRank2[1+rank]);
               q = bit.bor(q,BitRev[1+board.pawn_file[1+opp][1+file-1]]);
               q = bit.bor(q,BitRev[1+board.pawn_file[1+opp][1+file+1]]);

               if ( bit.band( q, BitRank3[1+rank] ) == 0) then

                  backward = false;
               end
             end
            end
          end
         end

         -- open, candidate and passed

         if ( bit.band( t2, BitGT[1+rank] ) == 0) then

            open = true;

            q = bit.bor( BitRev[1+board.pawn_file[1+opp][1+file-1]] ,
                     BitRev[1+board.pawn_file[1+opp][1+file+1]]);

            if ( bit.band( q, BitGT[1+rank] ) == 0) then

               passed = true;
               passed_bits[1+me] = bit.bor( passed_bits[1+me], BitEQ[1+file] );

            else

               -- candidate?

               n = 0;

               n = n + BitCount[1+bit.band( board.pawn_file[1+me][1+file-1], BitLE[1+rank] ) ];
               n = n + BitCount[1+bit.band( board.pawn_file[1+me][1+file+1], BitLE[1+rank] ) ];

               n = n - BitCount[1+bit.band( BitRev[1+board.pawn_file[1+opp][1+file-1]], BitGT[1+rank] ) ];
               n = n - BitCount[1+bit.band( BitRev[1+board.pawn_file[1+opp][1+file+1]], BitGT[1+rank] ) ];

               if (n >= 0) then

                  -- safe?

                  n = 0;

                  n = n + BitCount[1+bit.band( board.pawn_file[1+me][1+file-1], BitEQ[1+rank-1] ) ];
                  n = n + BitCount[1+bit.band( board.pawn_file[1+me][1+file+1], BitEQ[1+rank-1] ) ];

                  n = n - BitCount[1+bit.band( BitRev[1+board.pawn_file[1+opp][1+file-1]], BitEQ[1+rank+1] ) ];
                  n = n - BitCount[1+bit.band( BitRev[1+board.pawn_file[1+opp][1+file+1]], BitEQ[1+rank+1] ) ];

                  if (n >= 0) then
                    candidate = true;
                  end
               end
            end
         end

         -- score

         om = opening[1+me];
         em = endgame[1+me];

         if (doubled) then
            om = om - DoubledOpening;
            em = em - DoubledEndgame;
         end

         if (isolated) then
            if (open) then
               om = om - IsolatedOpeningOpen;
               em = em - IsolatedEndgame;
            else
               om = om - IsolatedOpening;
               em = em - IsolatedEndgame;
            end
         end

         if (backward) then
            if (open) then
               om = om - BackwardOpeningOpen;
               em = em - BackwardEndgame;
            else
               om = om - BackwardOpening;
               em = em - BackwardEndgame;
            end
         end

         if (candidate) then
            om = om + quad(CandidateOpeningMin,CandidateOpeningMax,rank);
            em = em + quad(CandidateEndgameMin,CandidateEndgameMax,rank);
         end


         opening[1+me] = om;
         endgame[1+me] = em;

         ptr = ptr + 1;

      end
   end

   -- store info

   info.opening = ((opening[1+White] - opening[1+Black]) * PawnStructureWeight) / 256;
   info.endgame = ((endgame[1+White] - endgame[1+Black]) * PawnStructureWeight) / 256;

   for colour = 0, 1, 1 do

      me = colour;
      opp = COLOUR_OPP(me);

      -- draw flags

      bits = file_bits[1+me];

      if (bits ~= 0  and  ( bit.band( bits, bits-1 ) == 0) ) then  -- one set bit

         file = BitFirst[1+bits];
         rank = BitFirst[1+board.pawn_file[1+me][1+file] ];
         --ASSERT(571, rank>=Rank2);

         q = bit.bor( BitRev[1+board.pawn_file[1+opp][1+file-1]],
                     BitRev[1+board.pawn_file[1+opp][1+file+1]] );

         if ( bit.band( q, BitGT[1+rank] ) == 0) then

            rank = BitLast[1+board.pawn_file[1+me][1+file] ];
            single_file[1+me] = SQUARE_MAKE(file,rank);
         end
      end

      info.flags[1+colour] = flags[1+colour];
      info.passed_bits[1+colour] = passed_bits[1+colour];
      info.single_file[1+colour] = single_file[1+colour];
   end

end

-- quad()

function quad( y_min, y_max, x )  -- int

   local y = 0;   -- int

   --ASSERT(572, y_min>=0 and y_min<=y_max and y_max<=32767);
   --ASSERT(573, x>=Rank2 and x<=Rank7);

   y =  math.floor( y_min + ((y_max - y_min) * Bonus[1+x] + 128) / 256 );

   --ASSERT(574, y>=y_min and y<=y_max);

   return y;
end

-- end of pawn.cpp



-- piece.cpp

-- functions

-- piece_init()

function piece_init() -- void

   local piece = 0;      -- int
   local piece_12 = 0;   -- int

   -- PieceTo12[], PieceOrder[], PieceInc[]

   for piece = 0, PieceNb-1, 1 do
     PieceTo12[1+piece] = -1;
     PieceOrder[1+piece] = -1;
     PieceInc[1+piece] = nil;
   end

   for piece_12 = 0, 11, 1 do
      PieceTo12[1+PieceFrom12[1+piece_12]] = piece_12;
      PieceOrder[1+PieceFrom12[1+piece_12]] = bit.rshift( piece_12, 1 );
   end

   PieceInc[1+WhiteKnight256] = KnightInc;
   PieceInc[1+WhiteBishop256] = BishopInc;
   PieceInc[1+WhiteRook256]   = RookInc;
   PieceInc[1+WhiteQueen256]  = QueenInc;
   PieceInc[1+WhiteKing256]   = KingInc;

   PieceInc[1+BlackKnight256] = KnightInc;
   PieceInc[1+BlackBishop256] = BishopInc;
   PieceInc[1+BlackRook256]   = RookInc;
   PieceInc[1+BlackQueen256]  = QueenInc;
   PieceInc[1+BlackKing256]   = KingInc;

end

-- piece_is_ok()

function piece_is_ok( piece )  -- bool

   if (piece < 0  or  piece >= PieceNb) then
     return false;
   end
   if (PieceTo12[1+piece] < 0) then
     return false;
   end
   return true;
end

-- piece_to_char()

function piece_to_char( piece )  -- int

   local i = PieceTo12[1+piece];

   --ASSERT(576, piece_is_ok(piece));

   return string.sub(PieceString, 1+i, 1+i );
end

-- piece_from_char()

function piece_from_char( c )  -- int

   local ptr = string.find(PieceString,c);   -- int

   if (ptr == nil) then
     return PieceNone256;
   end
   ptr = ptr - 1;

   --ASSERT(575, ptr>=0 and ptr<12);

   return PieceFrom12[1+ptr];
end

-- end of piece.cpp




-- protocol.cpp

-- functions

function setstartpos()

   -- init (to help debugging)

   Init = false;

   search_clear();

   board_from_fen(SearchInput.board,StartFen);

end

-- inits()

function inits()

   if (not Init) then

      -- late initialisation

      Init = true;

      if (option_get_bool("OwnBook")) then
        --   book_open(option_get_string("BookFile"));
        send("Sorry, no book.");
      end

      trans_alloc(Trans);

      pawn_init();
      pawn_alloc();

      material_init();
      material_alloc();

      pst_init();
      eval_init();
   end
end

-- loop_step()

function do_input( cmd )

   local ifelse = true;

   -- parse

   if (ifelse and string_start_with(cmd,"go")) then

      inits();
      parse_go( cmd );

      ifelse = false;
   end

   if (ifelse and string_equal(cmd,"isready")) then

      inits();
      send("readyok");

      ifelse = false;
   end


   if (ifelse and string_start_with(cmd,"position ")) then

      inits();
      parse_position(cmd);

      ifelse = false;
   end


   if (ifelse and string_start_with(cmd,"setoption ")) then

      parse_setoption( cmd );

      ifelse = false;
   end


   if (ifelse and string_equal(cmd,"help")) then


      send("supports commands: setposition fen, setposition moves, go depth, go movetime ");

      -- can manage also options, but for lua is better to use the default settings

      -- option_list();

      ifelse = false;
   end

end

-- parse_go()

function parse_go( cmd ) -- void

   local cmd1 = "";          -- string
   local cmd2 = "";          -- string
   local infinite = false;   -- bool
   local depth = -1;         -- int
   local movetime = -1.0;    -- int
   local ifelse = false;
   local save_board = string_t();

   -- parse

   cmd1 = str_after_ok(cmd," ");    -- skip "go"
   cmd2 = str_after_ok(cmd1," ");   -- value
   cmd1 = str_before_ok(cmd1.." "," ");

   ifelse = true;
   if (ifelse and string_equal(cmd1,"depth")) then

      depth = tonumber(cmd2);
      --ASSERT(590, depth>=0);

      ifelse = false;
   end

   if (ifelse and string_equal(cmd1,"infinite")) then

      infinite = true;

      ifelse = false;
   end

   if (ifelse and string_equal(cmd1,"movetime")) then

      movetime = tonumber(cmd2);
      --ASSERT(593, movetime>=0.0);

      ifelse = false;
   end

   if (ifelse) then

      movetime = 10;   -- Otherwise constantly 10 secs

      ifelse = false;
   end


   -- init

   ClearAll();

   -- depth limit

   if (depth >= 0) then
      SearchInput.depth_is_limited = true;
      SearchInput.depth_limit = depth;
   end

   -- time limit

   if (movetime >= 0.0) then

      -- fixed time

      SearchInput.time_is_limited = true;
      SearchInput.time_limit_1 = movetime;
      SearchInput.time_limit_2 = movetime;

   end

   if (infinite) then
      SearchInput.infinite = true;
   end

   -- search

   if( not ShowInfo) then
     send("Thinking (ShowInfo=false)...");
   end

   board_to_fen(SearchInput.board, save_board);   -- save board for sure

   search();
   search_update_current();

   board_from_fen(SearchInput.board, save_board.v); -- and restore after search

   send_best_move();

end

-- parse_position()

function parse_position( cmd ) -- void

   local cmd1 = "";          -- string
   local cmd2 = "";          -- string
   local mc = 0;
   local mnext = "";         -- string

   local move_string = string_t();   -- string

   local move = 0;          -- int
   local undo = undo_t();  -- undo_t[1]

   cmd1 = str_after_ok(cmd," ");    -- skip "position"
   cmd2 = str_after_ok(cmd1," ");   -- value

   -- start position

   if ( string_start_with(cmd1,"fen") ) then  -- "fen" present

      board_from_fen(SearchInput.board,cmd2);

   else

    if ( string_start_with(cmd1,"moves") ) then  -- "moves" present

      board_from_fen(SearchInput.board,StartFen);

      mc = 0;

      mnext = cmd2;
      while(true) do

         if( string.len(mnext)==0 ) then
           break;
         end

         move_string.v = iif( string.find( mnext," ")==nil, mnext, str_before_ok(mnext," ") );

         move = move_from_string(move_string,SearchInput.board);

         move_do(SearchInput.board,move,undo);

         mnext = str_after_ok(mnext," ");

         mc = mc + 1

      end

      SearchInput.board.movenumb = 1+math.floor(mc/2);

    else

      -- HACK: assumes startpos

      board_from_fen(SearchInput.board,StartFen);

    end
   end

end

-- parse_setoption()

function parse_setoption( cmd ) -- void

   local cmd1 = "";    -- string
   local cmd2 = "";    -- string

   local name = "";    -- string
   local value = "";   -- string

   cmd1 = str_after_ok(cmd," ");    -- skip "setoption"

   name = str_after_ok(cmd1,"name ");
   name = str_before_ok(name.." "," ");

   value = str_after_ok(cmd1,"value ");
   value  = str_before_ok(value.." "," ");


   if ( string.len(name)>0 and string.len(value)>0 )  then

     -- update

     option_set(name,value);
   end

   -- update transposition-table size if needed

   if (Init  and  string_equal(name,"Hash")) then  -- Init => already allocated

      if (option_get_int("Hash") >= 4) then
         trans_alloc(Trans);
      end
   end

end


-- send_best_move()

function send_ndtm( ch )

   local s = "info";
   local s2 = "";

   if(ch>5) then
     s = s .. " depth " .. string.format ("%d", SearchCurrent.depth );
     s = s .. " seldepth " .. string.format ("%d", SearchCurrent.max_depth ) .. " ";
   end

   if(ch>=20 and ch<=22) then
     s2 = s2 .. " score mate " .. string.format ("%d", SearchCurrent.mate ) .. " ";
   end
   if(ch==11 or ch==21) then
     s2 = s2 .. "lowerbound ";
   end
   if(ch==12 or ch==22) then
     s2 = s2 .. "upperbound ";
   end

   s = s .. " " .. s2 .. "time ".. string.format ("%.0f", SearchCurrent.time ) .. "s";
   s = s .. " nodes " .. string.format ("%d", SearchCurrent.node_nb );
   s = s .. " nps " ..   string.format ("%.0f", SearchCurrent.speed );

   send( s );

end

function send_best_move()

   local move_string = string_t();     -- string
   local ponder_string = string_t();   -- string

   local move = 0;      -- int
   local pv = nil;

   -- info

   send_ndtm(1);


   trans_stats(Trans);
   -- pawn_stats();
   -- material_stats();

   -- best move

   move = SearchBest.move;
   pv = SearchBest.pv;

   move_to_string(move,move_string);

   if ((false) and pv[1+0] == move  and  move_is_ok(pv[1+1])) then

        -- no pondering for lua, too slow

      move_to_string(pv[1+1],ponder_string);
      send("bestmove " .. move_string.v .. " ponder " .. ponder_string.v);
   else
      send("bestmove " .. move_string.v);
   end

   bestmv = move_string.v;

   format_best_mv2( move );

end

-- move for pgn

function format_best_mv2( move )

   local piece = 0;
   local piecech = "";
   local mvattr = "";
   local promos = "";
   local ckmt = "";
   local board = SearchInput.board;

   if( MOVE_IS_CASTLE(move) ) then
      bestmv2 = iif( string.sub(bestmv,3,3) == "g", "0-0","0-0-0" );
   else
      piece = board.square[1+MOVE_FROM(move)];
      if( not piece_is_ok( piece ) or piece == PieceNone64 ) then
        piece = board.square[1+MOVE_TO(move)];
      end

      piecech = string.upper( piece_to_char(piece) );
      if( piecech == "P") then
        piecech = "";
      end

      mvattr = iif( move_is_capture(move,board), "x", "-" );

      if( string.len(bestmv)>4 ) then
        promos = string.sub(bestmv,5,5);
      end

      if( move_is_check(move,board) ) then
        ckmt = "+";
      end

      bestmv2 = piecech .. string.sub(bestmv,1,2) .. mvattr .. string.sub(bestmv,3,4) .. promos .. ckmt;

   end
end


-- send()

function send( str1 ) -- void

   --ASSERT(605, str1~=nil);

   if( not ShowInfo and string_start_with(str1,"info ")) then
     return;
   end

   print( str1 );
end

-- string_equal()

function string_equal( s1, s2 ) -- bool

   --ASSERT(606, s1~=nil);
   --ASSERT(607, s2~=nil);

   return (s1==s2);
end

-- string_start_with()

function string_start_with( s1,  s2 ) -- bool

   local l1=string.len(s1);
   local l2=string.len(s2);

   --ASSERT(608, s1~=nil);
   --ASSERT(609, s2~=nil);

   return (l1>=l2) and (string.sub(s1,1,l2)==s2);
end


-- str_before_ok()

function str_before_ok( str1, c )
  local i = string.find( str1, c );
  if(i~=nil) then
    return string.sub( str1, 1, i-1 );
  end
  return "";
end

-- str_after_ok()

function str_after_ok( str1, c )
  local i = string.find( str1, c );
  if(i~=nil) then
    return string.sub( str1, i+ string.len(c) );
  end
  return "";
end

-- end of protocol.cpp



-- pst.cpp



-- macros

function Pget( piece_12,square_64,stage )
  return Pst[1+piece_12][1+square_64][1+stage];
end

function Pset( piece_12,square_64,stage, value )
  Pst[1+piece_12][1+square_64][1+stage] = value;
end

function Padd( piece_12,square_64,stage, value )
  Pst[1+piece_12][1+square_64][1+stage] = Pst[1+piece_12][1+square_64][1+stage] + value;
end

function Pmul( piece_12,square_64,stage, value )
  Pst[1+piece_12][1+square_64][1+stage] = Pst[1+piece_12][1+square_64][1+stage] * value;
end

-- functions

-- pst_init()

function pst_init()

   local i = 0;      -- int
   local piece = 0;  -- int
   local sq = 0;     -- int
   local stage = 0;  -- int

   -- UCI options

   PieceActivityWeight = (option_get_int("Piece Activity") * 256 + 50) / 100;
   KingSafetyWeight    = (option_get_int("King Safety")    * 256 + 50) / 100;
   PawnStructureWeight = (option_get_int("Pawn Structure") * 256 + 50) / 100;

   -- init

   for piece = 0, 11, 1 do
      Pst[1+piece] = {};
      for sq = 0, 63, 1 do
         Pst[1+piece][1+sq] = {};
         for stage = 0, StageNb-1, 1 do
            Pset(piece,sq,stage, 0);
         end
      end
   end

   -- pawns

   piece = WhitePawn12;

   -- file

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, PawnFile[1+square_file(sq)] * PawnFileOpening );
   end

   -- centre control

   Padd(piece,pD3,Opening, 10);
   Padd(piece,pE3,Opening, 10);

   Padd(piece,pD4,Opening, 20);
   Padd(piece,pE4,Opening, 20);

   Padd(piece,pD5,Opening, 10);
   Padd(piece,pE5,Opening, 10);

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening,  PawnStructureWeight / 256);
      Pmul(piece,sq,Endgame,  PawnStructureWeight / 256);
   end

   -- knights

   piece = WhiteKnight12;

   -- centre

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, KnightLine[1+square_file(sq)] * KnightCentreOpening);
      Padd(piece,sq,Opening, KnightLine[1+square_rank(sq)] * KnightCentreOpening);
      Padd(piece,sq,Endgame, KnightLine[1+square_file(sq)] * KnightCentreEndgame);
      Padd(piece,sq,Endgame, KnightLine[1+square_rank(sq)] * KnightCentreEndgame);
   end

   -- rank

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, KnightRank[1+square_rank(sq)] * KnightRankOpening);
   end

   -- back rank

   for sq = pA1, pH1, 1 do    -- HACK: only first rank
      Padd(piece,sq,Opening, -KnightBackRankOpening);
   end

   -- "trapped"

   Padd(piece,pA8,Opening, -KnightTrapped);
   Padd(piece,pH8,Opening, -KnightTrapped);

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening,  PieceActivityWeight / 256);
      Pmul(piece,sq,Endgame,  PieceActivityWeight / 256);
   end

   -- bishops

   piece = WhiteBishop12;

   -- centre

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening,  BishopLine[1+square_file(sq)] * BishopCentreOpening);
      Padd(piece,sq,Opening,  BishopLine[1+square_rank(sq)] * BishopCentreOpening);
      Padd(piece,sq,Endgame,  BishopLine[1+square_file(sq)] * BishopCentreEndgame);
      Padd(piece,sq,Endgame,  BishopLine[1+square_rank(sq)] * BishopCentreEndgame);
   end

   -- back rank

   for sq = pA1, pH1, 1 do    -- HACK: only first rank
      Padd(piece,sq,Opening, -BishopBackRankOpening);
   end

   -- main diagonals

   for i = 0, 7, 1 do
      sq = square_make(i,i);
      Padd(piece,sq,Opening, BishopDiagonalOpening);
      Padd(piece,square_opp(sq),Opening, BishopDiagonalOpening);
   end

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening,  PieceActivityWeight / 256);
      Pmul(piece,sq,Endgame,  PieceActivityWeight / 256);
   end

   -- rooks

   piece = WhiteRook12;

   -- file

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, RookFile[1+square_file(sq)] * RookFileOpening);
   end

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening,  PieceActivityWeight / 256);
      Pmul(piece,sq,Endgame,  PieceActivityWeight / 256);
   end

   -- queens

   piece = WhiteQueen12;

   -- centre

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, QueenLine[1+square_file(sq)] * QueenCentreOpening);
      Padd(piece,sq,Opening, QueenLine[1+square_rank(sq)] * QueenCentreOpening);
      Padd(piece,sq,Endgame, QueenLine[1+square_file(sq)] * QueenCentreEndgame);
      Padd(piece,sq,Endgame, QueenLine[1+square_rank(sq)] * QueenCentreEndgame);
   end

   -- back rank

   for sq = pA1, pH1, 1 do    -- HACK: only first rank
      Padd(piece,sq,Opening, -QueenBackRankOpening);
   end

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening, PieceActivityWeight / 256);
      Pmul(piece,sq,Endgame, PieceActivityWeight / 256);
   end

   -- kings

   piece = WhiteKing12;

   -- centre

   for sq = 0, 63, 1 do
      Padd(piece,sq,Endgame, KingLine[1+square_file(sq)] * KingCentreEndgame);
      Padd(piece,sq,Endgame, KingLine[1+square_rank(sq)] * KingCentreEndgame);
   end

   -- file

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, KingFile[1+square_file(sq)] * KingFileOpening);
   end

   -- rank

   for sq = 0, 63, 1 do
      Padd(piece,sq,Opening, KingRank[1+square_rank(sq)] * KingRankOpening);
   end

   -- weight

   for sq = 0, 63, 1 do
      Pmul(piece,sq,Opening, KingSafetyWeight / 256);
      Pmul(piece,sq,Endgame, PieceActivityWeight / 256);
   end

   -- symmetry copy for black

   for piece = 0, 11, 2 do -- HACK
      for sq = 0, 63, 1 do
         for stage = 0, StageNb-1, 1 do
            Pset(piece+1,sq,stage, -Pget(piece,square_opp(sq),stage) ); -- HACK
         end
      end
   end

end

-- square_make()

function square_make( file, rank )  -- int

   --ASSERT(610, file>=0 and file<8);
   --ASSERT(611, rank>=0 and rank<8);

   return bit.bor( bit.lshift(rank,3) , file);
end

-- square_file()

function square_file( square )  -- int

   --ASSERT(612, square>=0 and square<64);

   return bit.band( square, 7 );
end

-- square_rank()

function square_rank( square )  -- int

   --ASSERT(613, square>=0 and square<64);

   return bit.rshift(square,3);
end

-- square_opp()

function square_opp( square )  -- int

   --ASSERT(614, square>=0 and square<64);

   return bit.bxor(square,56);
end

-- end of pst.cpp




-- pv.cpp


-- functions

-- pv_is_ok()

function pv_is_ok( pv )  -- bool

   local pos = 0;    -- int
   local move = 0;   -- int

   if (pv[1+0] == nil) then
     return false;
   end

   while(true) do

      if (pos >= 256) then
        return false;
      end
      move = pv[1+pos];

      if (move == MoveNone) then
        return true;
      end
      if (not move_is_ok(move)) then
        return false;
      end

      pos = pos + 1;
   end

   return true;
end

-- pv_copy()

function pv_copy( dst, src ) -- void

   local i = 0;  -- int
   local m = 0;  -- int

   --ASSERT(615, pv_is_ok(src));

   while(true) do
      m = src[1+i];
      dst[1+i] = m;
      if( m == MoveNone) then
        break;
      end
      i = i + 1;
   end

end

-- pv_cat()

function pv_cat( dst, src, move )  -- int

   local i = 0;  -- int
   local m = 0;  -- int

   --ASSERT(617, pv_is_ok(src));

   dst[1+0] = move;

   while(true) do
      m = src[1+i];
      dst[1+i+1] = m;
      if( m == MoveNone) then
        break;
      end
      i = i + 1;
   end

end

-- pv_to_string()


function pv_to_string( pv, str1 )  -- bool

   local i = 0;              -- int
   local move = 0;           -- int
   local str2 = string_t();  -- string_t[1]

   --ASSERT(619, pv_is_ok(pv));
   --ASSERT(620, str1.v~=nil);

   -- init

   str1.v = "";

   -- loop

   while(true) do

      move = pv[1+i];
      if(move==MoveNone) then
        break;
      end

      if(i>0) then
        str1.v = str1.v .. " ";
      end

      move_to_string(move, str2);
      str1.v = str1.v .. str2.v;

      i = i + 1;
   end

   return true;

end

-- end of pv.cpp




-- random.cpp

-- we simply ignore 32bits of number
-- so, we can't read polyglot book
-- anyway, we can hash now

-- functions

function Rn64(s64b)
 Random64 [1+R64_i] = tonumber( string.sub( s64b, 1, 10 ) );
 R64_i = R64_i + 1;
end

-- random_init()

function random_init()

   Rn64("0x9D39247E33776D41"); Rn64("0x2AF7398005AAA5C7"); Rn64("0x44DB015024623547"); Rn64("0x9C15F73E62A76AE2");
   Rn64("0x75834465489C0C89"); Rn64("0x3290AC3A203001BF"); Rn64("0x0FBBAD1F61042279"); Rn64("0xE83A908FF2FB60CA");
   Rn64("0x0D7E765D58755C10"); Rn64("0x1A083822CEAFE02D"); Rn64("0x9605D5F0E25EC3B0"); Rn64("0xD021FF5CD13A2ED5");
   Rn64("0x40BDF15D4A672E32"); Rn64("0x011355146FD56395"); Rn64("0x5DB4832046F3D9E5"); Rn64("0x239F8B2D7FF719CC");
   Rn64("0x05D1A1AE85B49AA1"); Rn64("0x679F848F6E8FC971"); Rn64("0x7449BBFF801FED0B"); Rn64("0x7D11CDB1C3B7ADF0");
   Rn64("0x82C7709E781EB7CC"); Rn64("0xF3218F1C9510786C"); Rn64("0x331478F3AF51BBE6"); Rn64("0x4BB38DE5E7219443");
   Rn64("0xAA649C6EBCFD50FC"); Rn64("0x8DBD98A352AFD40B"); Rn64("0x87D2074B81D79217"); Rn64("0x19F3C751D3E92AE1");
   Rn64("0xB4AB30F062B19ABF"); Rn64("0x7B0500AC42047AC4"); Rn64("0xC9452CA81A09D85D"); Rn64("0x24AA6C514DA27500");
   Rn64("0x4C9F34427501B447"); Rn64("0x14A68FD73C910841"); Rn64("0xA71B9B83461CBD93"); Rn64("0x03488B95B0F1850F");
   Rn64("0x637B2B34FF93C040"); Rn64("0x09D1BC9A3DD90A94"); Rn64("0x3575668334A1DD3B"); Rn64("0x735E2B97A4C45A23");
   Rn64("0x18727070F1BD400B"); Rn64("0x1FCBACD259BF02E7"); Rn64("0xD310A7C2CE9B6555"); Rn64("0xBF983FE0FE5D8244");
   Rn64("0x9F74D14F7454A824"); Rn64("0x51EBDC4AB9BA3035"); Rn64("0x5C82C505DB9AB0FA"); Rn64("0xFCF7FE8A3430B241");
   Rn64("0x3253A729B9BA3DDE"); Rn64("0x8C74C368081B3075"); Rn64("0xB9BC6C87167C33E7"); Rn64("0x7EF48F2B83024E20");
   Rn64("0x11D505D4C351BD7F"); Rn64("0x6568FCA92C76A243"); Rn64("0x4DE0B0F40F32A7B8"); Rn64("0x96D693460CC37E5D");
   Rn64("0x42E240CB63689F2F"); Rn64("0x6D2BDCDAE2919661"); Rn64("0x42880B0236E4D951"); Rn64("0x5F0F4A5898171BB6");
   Rn64("0x39F890F579F92F88"); Rn64("0x93C5B5F47356388B"); Rn64("0x63DC359D8D231B78"); Rn64("0xEC16CA8AEA98AD76");
   Rn64("0x5355F900C2A82DC7"); Rn64("0x07FB9F855A997142"); Rn64("0x5093417AA8A7ED5E"); Rn64("0x7BCBC38DA25A7F3C");
   Rn64("0x19FC8A768CF4B6D4"); Rn64("0x637A7780DECFC0D9"); Rn64("0x8249A47AEE0E41F7"); Rn64("0x79AD695501E7D1E8");
   Rn64("0x14ACBAF4777D5776"); Rn64("0xF145B6BECCDEA195"); Rn64("0xDABF2AC8201752FC"); Rn64("0x24C3C94DF9C8D3F6");
   Rn64("0xBB6E2924F03912EA"); Rn64("0x0CE26C0B95C980D9"); Rn64("0xA49CD132BFBF7CC4"); Rn64("0xE99D662AF4243939");
   Rn64("0x27E6AD7891165C3F"); Rn64("0x8535F040B9744FF1"); Rn64("0x54B3F4FA5F40D873"); Rn64("0x72B12C32127FED2B");
   Rn64("0xEE954D3C7B411F47"); Rn64("0x9A85AC909A24EAA1"); Rn64("0x70AC4CD9F04F21F5"); Rn64("0xF9B89D3E99A075C2");
   Rn64("0x87B3E2B2B5C907B1"); Rn64("0xA366E5B8C54F48B8"); Rn64("0xAE4A9346CC3F7CF2"); Rn64("0x1920C04D47267BBD");
   Rn64("0x87BF02C6B49E2AE9"); Rn64("0x092237AC237F3859"); Rn64("0xFF07F64EF8ED14D0"); Rn64("0x8DE8DCA9F03CC54E");
   Rn64("0x9C1633264DB49C89"); Rn64("0xB3F22C3D0B0B38ED"); Rn64("0x390E5FB44D01144B"); Rn64("0x5BFEA5B4712768E9");
   Rn64("0x1E1032911FA78984"); Rn64("0x9A74ACB964E78CB3"); Rn64("0x4F80F7A035DAFB04"); Rn64("0x6304D09A0B3738C4");
   Rn64("0x2171E64683023A08"); Rn64("0x5B9B63EB9CEFF80C"); Rn64("0x506AACF489889342"); Rn64("0x1881AFC9A3A701D6");
   Rn64("0x6503080440750644"); Rn64("0xDFD395339CDBF4A7"); Rn64("0xEF927DBCF00C20F2"); Rn64("0x7B32F7D1E03680EC");
   Rn64("0xB9FD7620E7316243"); Rn64("0x05A7E8A57DB91B77"); Rn64("0xB5889C6E15630A75"); Rn64("0x4A750A09CE9573F7");
   Rn64("0xCF464CEC899A2F8A"); Rn64("0xF538639CE705B824"); Rn64("0x3C79A0FF5580EF7F"); Rn64("0xEDE6C87F8477609D");
   Rn64("0x799E81F05BC93F31"); Rn64("0x86536B8CF3428A8C"); Rn64("0x97D7374C60087B73"); Rn64("0xA246637CFF328532");
   Rn64("0x043FCAE60CC0EBA0"); Rn64("0x920E449535DD359E"); Rn64("0x70EB093B15B290CC"); Rn64("0x73A1921916591CBD");
   Rn64("0x56436C9FE1A1AA8D"); Rn64("0xEFAC4B70633B8F81"); Rn64("0xBB215798D45DF7AF"); Rn64("0x45F20042F24F1768");
   Rn64("0x930F80F4E8EB7462"); Rn64("0xFF6712FFCFD75EA1"); Rn64("0xAE623FD67468AA70"); Rn64("0xDD2C5BC84BC8D8FC");
   Rn64("0x7EED120D54CF2DD9"); Rn64("0x22FE545401165F1C"); Rn64("0xC91800E98FB99929"); Rn64("0x808BD68E6AC10365");
   Rn64("0xDEC468145B7605F6"); Rn64("0x1BEDE3A3AEF53302"); Rn64("0x43539603D6C55602"); Rn64("0xAA969B5C691CCB7A");
   Rn64("0xA87832D392EFEE56"); Rn64("0x65942C7B3C7E11AE"); Rn64("0xDED2D633CAD004F6"); Rn64("0x21F08570F420E565");
   Rn64("0xB415938D7DA94E3C"); Rn64("0x91B859E59ECB6350"); Rn64("0x10CFF333E0ED804A"); Rn64("0x28AED140BE0BB7DD");
   Rn64("0xC5CC1D89724FA456"); Rn64("0x5648F680F11A2741"); Rn64("0x2D255069F0B7DAB3"); Rn64("0x9BC5A38EF729ABD4");
   Rn64("0xEF2F054308F6A2BC"); Rn64("0xAF2042F5CC5C2858"); Rn64("0x480412BAB7F5BE2A"); Rn64("0xAEF3AF4A563DFE43");
   Rn64("0x19AFE59AE451497F"); Rn64("0x52593803DFF1E840"); Rn64("0xF4F076E65F2CE6F0"); Rn64("0x11379625747D5AF3");
   Rn64("0xBCE5D2248682C115"); Rn64("0x9DA4243DE836994F"); Rn64("0x066F70B33FE09017"); Rn64("0x4DC4DE189B671A1C");
   Rn64("0x51039AB7712457C3"); Rn64("0xC07A3F80C31FB4B4"); Rn64("0xB46EE9C5E64A6E7C"); Rn64("0xB3819A42ABE61C87");
   Rn64("0x21A007933A522A20"); Rn64("0x2DF16F761598AA4F"); Rn64("0x763C4A1371B368FD"); Rn64("0xF793C46702E086A0");
   Rn64("0xD7288E012AEB8D31"); Rn64("0xDE336A2A4BC1C44B"); Rn64("0x0BF692B38D079F23"); Rn64("0x2C604A7A177326B3");
   Rn64("0x4850E73E03EB6064"); Rn64("0xCFC447F1E53C8E1B"); Rn64("0xB05CA3F564268D99"); Rn64("0x9AE182C8BC9474E8");
   Rn64("0xA4FC4BD4FC5558CA"); Rn64("0xE755178D58FC4E76"); Rn64("0x69B97DB1A4C03DFE"); Rn64("0xF9B5B7C4ACC67C96");
   Rn64("0xFC6A82D64B8655FB"); Rn64("0x9C684CB6C4D24417"); Rn64("0x8EC97D2917456ED0"); Rn64("0x6703DF9D2924E97E");
   Rn64("0xC547F57E42A7444E"); Rn64("0x78E37644E7CAD29E"); Rn64("0xFE9A44E9362F05FA"); Rn64("0x08BD35CC38336615");
   Rn64("0x9315E5EB3A129ACE"); Rn64("0x94061B871E04DF75"); Rn64("0xDF1D9F9D784BA010"); Rn64("0x3BBA57B68871B59D");
   Rn64("0xD2B7ADEEDED1F73F"); Rn64("0xF7A255D83BC373F8"); Rn64("0xD7F4F2448C0CEB81"); Rn64("0xD95BE88CD210FFA7");
   Rn64("0x336F52F8FF4728E7"); Rn64("0xA74049DAC312AC71"); Rn64("0xA2F61BB6E437FDB5"); Rn64("0x4F2A5CB07F6A35B3");
   Rn64("0x87D380BDA5BF7859"); Rn64("0x16B9F7E06C453A21"); Rn64("0x7BA2484C8A0FD54E"); Rn64("0xF3A678CAD9A2E38C");
   Rn64("0x39B0BF7DDE437BA2"); Rn64("0xFCAF55C1BF8A4424"); Rn64("0x18FCF680573FA594"); Rn64("0x4C0563B89F495AC3");
   Rn64("0x40E087931A00930D"); Rn64("0x8CFFA9412EB642C1"); Rn64("0x68CA39053261169F"); Rn64("0x7A1EE967D27579E2");
   Rn64("0x9D1D60E5076F5B6F"); Rn64("0x3810E399B6F65BA2"); Rn64("0x32095B6D4AB5F9B1"); Rn64("0x35CAB62109DD038A");
   Rn64("0xA90B24499FCFAFB1"); Rn64("0x77A225A07CC2C6BD"); Rn64("0x513E5E634C70E331"); Rn64("0x4361C0CA3F692F12");
   Rn64("0xD941ACA44B20A45B"); Rn64("0x528F7C8602C5807B"); Rn64("0x52AB92BEB9613989"); Rn64("0x9D1DFA2EFC557F73");
   Rn64("0x722FF175F572C348"); Rn64("0x1D1260A51107FE97"); Rn64("0x7A249A57EC0C9BA2"); Rn64("0x04208FE9E8F7F2D6");
   Rn64("0x5A110C6058B920A0"); Rn64("0x0CD9A497658A5698"); Rn64("0x56FD23C8F9715A4C"); Rn64("0x284C847B9D887AAE");
   Rn64("0x04FEABFBBDB619CB"); Rn64("0x742E1E651C60BA83"); Rn64("0x9A9632E65904AD3C"); Rn64("0x881B82A13B51B9E2");
   Rn64("0x506E6744CD974924"); Rn64("0xB0183DB56FFC6A79"); Rn64("0x0ED9B915C66ED37E"); Rn64("0x5E11E86D5873D484");
   Rn64("0xF678647E3519AC6E"); Rn64("0x1B85D488D0F20CC5"); Rn64("0xDAB9FE6525D89021"); Rn64("0x0D151D86ADB73615");
   Rn64("0xA865A54EDCC0F019"); Rn64("0x93C42566AEF98FFB"); Rn64("0x99E7AFEABE000731"); Rn64("0x48CBFF086DDF285A");
   Rn64("0x7F9B6AF1EBF78BAF"); Rn64("0x58627E1A149BBA21"); Rn64("0x2CD16E2ABD791E33"); Rn64("0xD363EFF5F0977996");
   Rn64("0x0CE2A38C344A6EED"); Rn64("0x1A804AADB9CFA741"); Rn64("0x907F30421D78C5DE"); Rn64("0x501F65EDB3034D07");
   Rn64("0x37624AE5A48FA6E9"); Rn64("0x957BAF61700CFF4E"); Rn64("0x3A6C27934E31188A"); Rn64("0xD49503536ABCA345");
   Rn64("0x088E049589C432E0"); Rn64("0xF943AEE7FEBF21B8"); Rn64("0x6C3B8E3E336139D3"); Rn64("0x364F6FFA464EE52E");
   Rn64("0xD60F6DCEDC314222"); Rn64("0x56963B0DCA418FC0"); Rn64("0x16F50EDF91E513AF"); Rn64("0xEF1955914B609F93");
   Rn64("0x565601C0364E3228"); Rn64("0xECB53939887E8175"); Rn64("0xBAC7A9A18531294B"); Rn64("0xB344C470397BBA52");
   Rn64("0x65D34954DAF3CEBD"); Rn64("0xB4B81B3FA97511E2"); Rn64("0xB422061193D6F6A7"); Rn64("0x071582401C38434D");
   Rn64("0x7A13F18BBEDC4FF5"); Rn64("0xBC4097B116C524D2"); Rn64("0x59B97885E2F2EA28"); Rn64("0x99170A5DC3115544");
   Rn64("0x6F423357E7C6A9F9"); Rn64("0x325928EE6E6F8794"); Rn64("0xD0E4366228B03343"); Rn64("0x565C31F7DE89EA27");
   Rn64("0x30F5611484119414"); Rn64("0xD873DB391292ED4F"); Rn64("0x7BD94E1D8E17DEBC"); Rn64("0xC7D9F16864A76E94");
   Rn64("0x947AE053EE56E63C"); Rn64("0xC8C93882F9475F5F"); Rn64("0x3A9BF55BA91F81CA"); Rn64("0xD9A11FBB3D9808E4");
   Rn64("0x0FD22063EDC29FCA"); Rn64("0xB3F256D8ACA0B0B9"); Rn64("0xB03031A8B4516E84"); Rn64("0x35DD37D5871448AF");
   Rn64("0xE9F6082B05542E4E"); Rn64("0xEBFAFA33D7254B59"); Rn64("0x9255ABB50D532280"); Rn64("0xB9AB4CE57F2D34F3");
   Rn64("0x693501D628297551"); Rn64("0xC62C58F97DD949BF"); Rn64("0xCD454F8F19C5126A"); Rn64("0xBBE83F4ECC2BDECB");
   Rn64("0xDC842B7E2819E230"); Rn64("0xBA89142E007503B8"); Rn64("0xA3BC941D0A5061CB"); Rn64("0xE9F6760E32CD8021");
   Rn64("0x09C7E552BC76492F"); Rn64("0x852F54934DA55CC9"); Rn64("0x8107FCCF064FCF56"); Rn64("0x098954D51FFF6580");
   Rn64("0x23B70EDB1955C4BF"); Rn64("0xC330DE426430F69D"); Rn64("0x4715ED43E8A45C0A"); Rn64("0xA8D7E4DAB780A08D");
   Rn64("0x0572B974F03CE0BB"); Rn64("0xB57D2E985E1419C7"); Rn64("0xE8D9ECBE2CF3D73F"); Rn64("0x2FE4B17170E59750");
   Rn64("0x11317BA87905E790"); Rn64("0x7FBF21EC8A1F45EC"); Rn64("0x1725CABFCB045B00"); Rn64("0x964E915CD5E2B207");
   Rn64("0x3E2B8BCBF016D66D"); Rn64("0xBE7444E39328A0AC"); Rn64("0xF85B2B4FBCDE44B7"); Rn64("0x49353FEA39BA63B1");
   Rn64("0x1DD01AAFCD53486A"); Rn64("0x1FCA8A92FD719F85"); Rn64("0xFC7C95D827357AFA"); Rn64("0x18A6A990C8B35EBD");
   Rn64("0xCCCB7005C6B9C28D"); Rn64("0x3BDBB92C43B17F26"); Rn64("0xAA70B5B4F89695A2"); Rn64("0xE94C39A54A98307F");
   Rn64("0xB7A0B174CFF6F36E"); Rn64("0xD4DBA84729AF48AD"); Rn64("0x2E18BC1AD9704A68"); Rn64("0x2DE0966DAF2F8B1C");
   Rn64("0xB9C11D5B1E43A07E"); Rn64("0x64972D68DEE33360"); Rn64("0x94628D38D0C20584"); Rn64("0xDBC0D2B6AB90A559");
   Rn64("0xD2733C4335C6A72F"); Rn64("0x7E75D99D94A70F4D"); Rn64("0x6CED1983376FA72B"); Rn64("0x97FCAACBF030BC24");
   Rn64("0x7B77497B32503B12"); Rn64("0x8547EDDFB81CCB94"); Rn64("0x79999CDFF70902CB"); Rn64("0xCFFE1939438E9B24");
   Rn64("0x829626E3892D95D7"); Rn64("0x92FAE24291F2B3F1"); Rn64("0x63E22C147B9C3403"); Rn64("0xC678B6D860284A1C");
   Rn64("0x5873888850659AE7"); Rn64("0x0981DCD296A8736D"); Rn64("0x9F65789A6509A440"); Rn64("0x9FF38FED72E9052F");
   Rn64("0xE479EE5B9930578C"); Rn64("0xE7F28ECD2D49EECD"); Rn64("0x56C074A581EA17FE"); Rn64("0x5544F7D774B14AEF");
   Rn64("0x7B3F0195FC6F290F"); Rn64("0x12153635B2C0CF57"); Rn64("0x7F5126DBBA5E0CA7"); Rn64("0x7A76956C3EAFB413");
   Rn64("0x3D5774A11D31AB39"); Rn64("0x8A1B083821F40CB4"); Rn64("0x7B4A38E32537DF62"); Rn64("0x950113646D1D6E03");
   Rn64("0x4DA8979A0041E8A9"); Rn64("0x3BC36E078F7515D7"); Rn64("0x5D0A12F27AD310D1"); Rn64("0x7F9D1A2E1EBE1327");
   Rn64("0xDA3A361B1C5157B1"); Rn64("0xDCDD7D20903D0C25"); Rn64("0x36833336D068F707"); Rn64("0xCE68341F79893389");
   Rn64("0xAB9090168DD05F34"); Rn64("0x43954B3252DC25E5"); Rn64("0xB438C2B67F98E5E9"); Rn64("0x10DCD78E3851A492");
   Rn64("0xDBC27AB5447822BF"); Rn64("0x9B3CDB65F82CA382"); Rn64("0xB67B7896167B4C84"); Rn64("0xBFCED1B0048EAC50");
   Rn64("0xA9119B60369FFEBD"); Rn64("0x1FFF7AC80904BF45"); Rn64("0xAC12FB171817EEE7"); Rn64("0xAF08DA9177DDA93D");
   Rn64("0x1B0CAB936E65C744"); Rn64("0xB559EB1D04E5E932"); Rn64("0xC37B45B3F8D6F2BA"); Rn64("0xC3A9DC228CAAC9E9");
   Rn64("0xF3B8B6675A6507FF"); Rn64("0x9FC477DE4ED681DA"); Rn64("0x67378D8ECCEF96CB"); Rn64("0x6DD856D94D259236");
   Rn64("0xA319CE15B0B4DB31"); Rn64("0x073973751F12DD5E"); Rn64("0x8A8E849EB32781A5"); Rn64("0xE1925C71285279F5");
   Rn64("0x74C04BF1790C0EFE"); Rn64("0x4DDA48153C94938A"); Rn64("0x9D266D6A1CC0542C"); Rn64("0x7440FB816508C4FE");
   Rn64("0x13328503DF48229F"); Rn64("0xD6BF7BAEE43CAC40"); Rn64("0x4838D65F6EF6748F"); Rn64("0x1E152328F3318DEA");
   Rn64("0x8F8419A348F296BF"); Rn64("0x72C8834A5957B511"); Rn64("0xD7A023A73260B45C"); Rn64("0x94EBC8ABCFB56DAE");
   Rn64("0x9FC10D0F989993E0"); Rn64("0xDE68A2355B93CAE6"); Rn64("0xA44CFE79AE538BBE"); Rn64("0x9D1D84FCCE371425");
   Rn64("0x51D2B1AB2DDFB636"); Rn64("0x2FD7E4B9E72CD38C"); Rn64("0x65CA5B96B7552210"); Rn64("0xDD69A0D8AB3B546D");
   Rn64("0x604D51B25FBF70E2"); Rn64("0x73AA8A564FB7AC9E"); Rn64("0x1A8C1E992B941148"); Rn64("0xAAC40A2703D9BEA0");
   Rn64("0x764DBEAE7FA4F3A6"); Rn64("0x1E99B96E70A9BE8B"); Rn64("0x2C5E9DEB57EF4743"); Rn64("0x3A938FEE32D29981");
   Rn64("0x26E6DB8FFDF5ADFE"); Rn64("0x469356C504EC9F9D"); Rn64("0xC8763C5B08D1908C"); Rn64("0x3F6C6AF859D80055");
   Rn64("0x7F7CC39420A3A545"); Rn64("0x9BFB227EBDF4C5CE"); Rn64("0x89039D79D6FC5C5C"); Rn64("0x8FE88B57305E2AB6");
   Rn64("0xA09E8C8C35AB96DE"); Rn64("0xFA7E393983325753"); Rn64("0xD6B6D0ECC617C699"); Rn64("0xDFEA21EA9E7557E3");
   Rn64("0xB67C1FA481680AF8"); Rn64("0xCA1E3785A9E724E5"); Rn64("0x1CFC8BED0D681639"); Rn64("0xD18D8549D140CAEA");
   Rn64("0x4ED0FE7E9DC91335"); Rn64("0xE4DBF0634473F5D2"); Rn64("0x1761F93A44D5AEFE"); Rn64("0x53898E4C3910DA55");
   Rn64("0x734DE8181F6EC39A"); Rn64("0x2680B122BAA28D97"); Rn64("0x298AF231C85BAFAB"); Rn64("0x7983EED3740847D5");
   Rn64("0x66C1A2A1A60CD889"); Rn64("0x9E17E49642A3E4C1"); Rn64("0xEDB454E7BADC0805"); Rn64("0x50B704CAB602C329");
   Rn64("0x4CC317FB9CDDD023"); Rn64("0x66B4835D9EAFEA22"); Rn64("0x219B97E26FFC81BD"); Rn64("0x261E4E4C0A333A9D");
   Rn64("0x1FE2CCA76517DB90"); Rn64("0xD7504DFA8816EDBB"); Rn64("0xB9571FA04DC089C8"); Rn64("0x1DDC0325259B27DE");
   Rn64("0xCF3F4688801EB9AA"); Rn64("0xF4F5D05C10CAB243"); Rn64("0x38B6525C21A42B0E"); Rn64("0x36F60E2BA4FA6800");
   Rn64("0xEB3593803173E0CE"); Rn64("0x9C4CD6257C5A3603"); Rn64("0xAF0C317D32ADAA8A"); Rn64("0x258E5A80C7204C4B");
   Rn64("0x8B889D624D44885D"); Rn64("0xF4D14597E660F855"); Rn64("0xD4347F66EC8941C3"); Rn64("0xE699ED85B0DFB40D");
   Rn64("0x2472F6207C2D0484"); Rn64("0xC2A1E7B5B459AEB5"); Rn64("0xAB4F6451CC1D45EC"); Rn64("0x63767572AE3D6174");
   Rn64("0xA59E0BD101731A28"); Rn64("0x116D0016CB948F09"); Rn64("0x2CF9C8CA052F6E9F"); Rn64("0x0B090A7560A968E3");
   Rn64("0xABEEDDB2DDE06FF1"); Rn64("0x58EFC10B06A2068D"); Rn64("0xC6E57A78FBD986E0"); Rn64("0x2EAB8CA63CE802D7");
   Rn64("0x14A195640116F336"); Rn64("0x7C0828DD624EC390"); Rn64("0xD74BBE77E6116AC7"); Rn64("0x804456AF10F5FB53");
   Rn64("0xEBE9EA2ADF4321C7"); Rn64("0x03219A39EE587A30"); Rn64("0x49787FEF17AF9924"); Rn64("0xA1E9300CD8520548");
   Rn64("0x5B45E522E4B1B4EF"); Rn64("0xB49C3B3995091A36"); Rn64("0xD4490AD526F14431"); Rn64("0x12A8F216AF9418C2");
   Rn64("0x001F837CC7350524"); Rn64("0x1877B51E57A764D5"); Rn64("0xA2853B80F17F58EE"); Rn64("0x993E1DE72D36D310");
   Rn64("0xB3598080CE64A656"); Rn64("0x252F59CF0D9F04BB"); Rn64("0xD23C8E176D113600"); Rn64("0x1BDA0492E7E4586E");
   Rn64("0x21E0BD5026C619BF"); Rn64("0x3B097ADAF088F94E"); Rn64("0x8D14DEDB30BE846E"); Rn64("0xF95CFFA23AF5F6F4");
   Rn64("0x3871700761B3F743"); Rn64("0xCA672B91E9E4FA16"); Rn64("0x64C8E531BFF53B55"); Rn64("0x241260ED4AD1E87D");
   Rn64("0x106C09B972D2E822"); Rn64("0x7FBA195410E5CA30"); Rn64("0x7884D9BC6CB569D8"); Rn64("0x0647DFEDCD894A29");
   Rn64("0x63573FF03E224774"); Rn64("0x4FC8E9560F91B123"); Rn64("0x1DB956E450275779"); Rn64("0xB8D91274B9E9D4FB");
   Rn64("0xA2EBEE47E2FBFCE1"); Rn64("0xD9F1F30CCD97FB09"); Rn64("0xEFED53D75FD64E6B"); Rn64("0x2E6D02C36017F67F");
   Rn64("0xA9AA4D20DB084E9B"); Rn64("0xB64BE8D8B25396C1"); Rn64("0x70CB6AF7C2D5BCF0"); Rn64("0x98F076A4F7A2322E");
   Rn64("0xBF84470805E69B5F"); Rn64("0x94C3251F06F90CF3"); Rn64("0x3E003E616A6591E9"); Rn64("0xB925A6CD0421AFF3");
   Rn64("0x61BDD1307C66E300"); Rn64("0xBF8D5108E27E0D48"); Rn64("0x240AB57A8B888B20"); Rn64("0xFC87614BAF287E07");
   Rn64("0xEF02CDD06FFDB432"); Rn64("0xA1082C0466DF6C0A"); Rn64("0x8215E577001332C8"); Rn64("0xD39BB9C3A48DB6CF");
   Rn64("0x2738259634305C14"); Rn64("0x61CF4F94C97DF93D"); Rn64("0x1B6BACA2AE4E125B"); Rn64("0x758F450C88572E0B");
   Rn64("0x959F587D507A8359"); Rn64("0xB063E962E045F54D"); Rn64("0x60E8ED72C0DFF5D1"); Rn64("0x7B64978555326F9F");
   Rn64("0xFD080D236DA814BA"); Rn64("0x8C90FD9B083F4558"); Rn64("0x106F72FE81E2C590"); Rn64("0x7976033A39F7D952");
   Rn64("0xA4EC0132764CA04B"); Rn64("0x733EA705FAE4FA77"); Rn64("0xB4D8F77BC3E56167"); Rn64("0x9E21F4F903B33FD9");
   Rn64("0x9D765E419FB69F6D"); Rn64("0xD30C088BA61EA5EF"); Rn64("0x5D94337FBFAF7F5B"); Rn64("0x1A4E4822EB4D7A59");
   Rn64("0x6FFE73E81B637FB3"); Rn64("0xDDF957BC36D8B9CA"); Rn64("0x64D0E29EEA8838B3"); Rn64("0x08DD9BDFD96B9F63");
   Rn64("0x087E79E5A57D1D13"); Rn64("0xE328E230E3E2B3FB"); Rn64("0x1C2559E30F0946BE"); Rn64("0x720BF5F26F4D2EAA");
   Rn64("0xB0774D261CC609DB"); Rn64("0x443F64EC5A371195"); Rn64("0x4112CF68649A260E"); Rn64("0xD813F2FAB7F5C5CA");
   Rn64("0x660D3257380841EE"); Rn64("0x59AC2C7873F910A3"); Rn64("0xE846963877671A17"); Rn64("0x93B633ABFA3469F8");
   Rn64("0xC0C0F5A60EF4CDCF"); Rn64("0xCAF21ECD4377B28C"); Rn64("0x57277707199B8175"); Rn64("0x506C11B9D90E8B1D");
   Rn64("0xD83CC2687A19255F"); Rn64("0x4A29C6465A314CD1"); Rn64("0xED2DF21216235097"); Rn64("0xB5635C95FF7296E2");
   Rn64("0x22AF003AB672E811"); Rn64("0x52E762596BF68235"); Rn64("0x9AEBA33AC6ECC6B0"); Rn64("0x944F6DE09134DFB6");
   Rn64("0x6C47BEC883A7DE39"); Rn64("0x6AD047C430A12104"); Rn64("0xA5B1CFDBA0AB4067"); Rn64("0x7C45D833AFF07862");
   Rn64("0x5092EF950A16DA0B"); Rn64("0x9338E69C052B8E7B"); Rn64("0x455A4B4CFE30E3F5"); Rn64("0x6B02E63195AD0CF8");
   Rn64("0x6B17B224BAD6BF27"); Rn64("0xD1E0CCD25BB9C169"); Rn64("0xDE0C89A556B9AE70"); Rn64("0x50065E535A213CF6");
   Rn64("0x9C1169FA2777B874"); Rn64("0x78EDEFD694AF1EED"); Rn64("0x6DC93D9526A50E68"); Rn64("0xEE97F453F06791ED");
   Rn64("0x32AB0EDB696703D3"); Rn64("0x3A6853C7E70757A7"); Rn64("0x31865CED6120F37D"); Rn64("0x67FEF95D92607890");
   Rn64("0x1F2B1D1F15F6DC9C"); Rn64("0xB69E38A8965C6B65"); Rn64("0xAA9119FF184CCCF4"); Rn64("0xF43C732873F24C13");
   Rn64("0xFB4A3D794A9A80D2"); Rn64("0x3550C2321FD6109C"); Rn64("0x371F77E76BB8417E"); Rn64("0x6BFA9AAE5EC05779");
   Rn64("0xCD04F3FF001A4778"); Rn64("0xE3273522064480CA"); Rn64("0x9F91508BFFCFC14A"); Rn64("0x049A7F41061A9E60");
   Rn64("0xFCB6BE43A9F2FE9B"); Rn64("0x08DE8A1C7797DA9B"); Rn64("0x8F9887E6078735A1"); Rn64("0xB5B4071DBFC73A66");
   Rn64("0x230E343DFBA08D33"); Rn64("0x43ED7F5A0FAE657D"); Rn64("0x3A88A0FBBCB05C63"); Rn64("0x21874B8B4D2DBC4F");
   Rn64("0x1BDEA12E35F6A8C9"); Rn64("0x53C065C6C8E63528"); Rn64("0xE34A1D250E7A8D6B"); Rn64("0xD6B04D3B7651DD7E");
   Rn64("0x5E90277E7CB39E2D"); Rn64("0x2C046F22062DC67D"); Rn64("0xB10BB459132D0A26"); Rn64("0x3FA9DDFB67E2F199");
   Rn64("0x0E09B88E1914F7AF"); Rn64("0x10E8B35AF3EEAB37"); Rn64("0x9EEDECA8E272B933"); Rn64("0xD4C718BC4AE8AE5F");
   Rn64("0x81536D601170FC20"); Rn64("0x91B534F885818A06"); Rn64("0xEC8177F83F900978"); Rn64("0x190E714FADA5156E");
   Rn64("0xB592BF39B0364963"); Rn64("0x89C350C893AE7DC1"); Rn64("0xAC042E70F8B383F2"); Rn64("0xB49B52E587A1EE60");
   Rn64("0xFB152FE3FF26DA89"); Rn64("0x3E666E6F69AE2C15"); Rn64("0x3B544EBE544C19F9"); Rn64("0xE805A1E290CF2456");
   Rn64("0x24B33C9D7ED25117"); Rn64("0xE74733427B72F0C1"); Rn64("0x0A804D18B7097475"); Rn64("0x57E3306D881EDB4F");
   Rn64("0x4AE7D6A36EB5DBCB"); Rn64("0x2D8D5432157064C8"); Rn64("0xD1E649DE1E7F268B"); Rn64("0x8A328A1CEDFE552C");
   Rn64("0x07A3AEC79624C7DA"); Rn64("0x84547DDC3E203C94"); Rn64("0x990A98FD5071D263"); Rn64("0x1A4FF12616EEFC89");
   Rn64("0xF6F7FD1431714200"); Rn64("0x30C05B1BA332F41C"); Rn64("0x8D2636B81555A786"); Rn64("0x46C9FEB55D120902");
   Rn64("0xCCEC0A73B49C9921"); Rn64("0x4E9D2827355FC492"); Rn64("0x19EBB029435DCB0F"); Rn64("0x4659D2B743848A2C");
   Rn64("0x963EF2C96B33BE31"); Rn64("0x74F85198B05A2E7D"); Rn64("0x5A0F544DD2B1FB18"); Rn64("0x03727073C2E134B1");
   Rn64("0xC7F6AA2DE59AEA61"); Rn64("0x352787BAA0D7C22F"); Rn64("0x9853EAB63B5E0B35"); Rn64("0xABBDCDD7ED5C0860");
   Rn64("0xCF05DAF5AC8D77B0"); Rn64("0x49CAD48CEBF4A71E"); Rn64("0x7A4C10EC2158C4A6"); Rn64("0xD9E92AA246BF719E");
   Rn64("0x13AE978D09FE5557"); Rn64("0x730499AF921549FF"); Rn64("0x4E4B705B92903BA4"); Rn64("0xFF577222C14F0A3A");
   Rn64("0x55B6344CF97AAFAE"); Rn64("0xB862225B055B6960"); Rn64("0xCAC09AFBDDD2CDB4"); Rn64("0xDAF8E9829FE96B5F");
   Rn64("0xB5FDFC5D3132C498"); Rn64("0x310CB380DB6F7503"); Rn64("0xE87FBB46217A360E"); Rn64("0x2102AE466EBB1148");
   Rn64("0xF8549E1A3AA5E00D"); Rn64("0x07A69AFDCC42261A"); Rn64("0xC4C118BFE78FEAAE"); Rn64("0xF9F4892ED96BD438");
   Rn64("0x1AF3DBE25D8F45DA"); Rn64("0xF5B4B0B0D2DEEEB4"); Rn64("0x962ACEEFA82E1C84"); Rn64("0x046E3ECAAF453CE9");
   Rn64("0xF05D129681949A4C"); Rn64("0x964781CE734B3C84"); Rn64("0x9C2ED44081CE5FBD"); Rn64("0x522E23F3925E319E");
   Rn64("0x177E00F9FC32F791"); Rn64("0x2BC60A63A6F3B3F2"); Rn64("0x222BBFAE61725606"); Rn64("0x486289DDCC3D6780");
   Rn64("0x7DC7785B8EFDFC80"); Rn64("0x8AF38731C02BA980"); Rn64("0x1FAB64EA29A2DDF7"); Rn64("0xE4D9429322CD065A");
   Rn64("0x9DA058C67844F20C"); Rn64("0x24C0E332B70019B0"); Rn64("0x233003B5A6CFE6AD"); Rn64("0xD586BD01C5C217F6");
   Rn64("0x5E5637885F29BC2B"); Rn64("0x7EBA726D8C94094B"); Rn64("0x0A56A5F0BFE39272"); Rn64("0xD79476A84EE20D06");
   Rn64("0x9E4C1269BAA4BF37"); Rn64("0x17EFEE45B0DEE640"); Rn64("0x1D95B0A5FCF90BC6"); Rn64("0x93CBE0B699C2585D");
   Rn64("0x65FA4F227A2B6D79"); Rn64("0xD5F9E858292504D5"); Rn64("0xC2B5A03F71471A6F"); Rn64("0x59300222B4561E00");
   Rn64("0xCE2F8642CA0712DC"); Rn64("0x7CA9723FBB2E8988"); Rn64("0x2785338347F2BA08"); Rn64("0xC61BB3A141E50E8C");
   Rn64("0x150F361DAB9DEC26"); Rn64("0x9F6A419D382595F4"); Rn64("0x64A53DC924FE7AC9"); Rn64("0x142DE49FFF7A7C3D");
   Rn64("0x0C335248857FA9E7"); Rn64("0x0A9C32D5EAE45305"); Rn64("0xE6C42178C4BBB92E"); Rn64("0x71F1CE2490D20B07");
   Rn64("0xF1BCC3D275AFE51A"); Rn64("0xE728E8C83C334074"); Rn64("0x96FBF83A12884624"); Rn64("0x81A1549FD6573DA5");
   Rn64("0x5FA7867CAF35E149"); Rn64("0x56986E2EF3ED091B"); Rn64("0x917F1DD5F8886C61"); Rn64("0xD20D8C88C8FFE65F");
   Rn64("0x31D71DCE64B2C310"); Rn64("0xF165B587DF898190"); Rn64("0xA57E6339DD2CF3A0"); Rn64("0x1EF6E6DBB1961EC9");
   Rn64("0x70CC73D90BC26E24"); Rn64("0xE21A6B35DF0C3AD7"); Rn64("0x003A93D8B2806962"); Rn64("0x1C99DED33CB890A1");
   Rn64("0xCF3145DE0ADD4289"); Rn64("0xD0E4427A5514FB72"); Rn64("0x77C621CC9FB3A483"); Rn64("0x67A34DAC4356550B");
   Rn64("0xF8D626AAAF278509");


-- We know it.
--   if ((Random64[1+RandomNb-1] bit.rshift(,) 32) ~= 0xF8D626AA) { // upper half of the last element of the array
--      my_fatal("broken 64-bit types\n");
--   }

end

-- end of random.cpp




-- recog.cpp

-- functions

-- recog_draw()

function recog_draw( board )  -- bool

   local mat_info = material_info_t();  -- material_info_t[1]
   local ifelse = false;

   local me = 0;    -- int
   local opp = 0;   -- int
   local wp = 0;   -- int
   local wk = 0;   -- int
   local bk = 0;   -- int
   local wb = 0;   -- int
   local bb = 0;   -- int

   --ASSERT(622, board.sp~=nil);

   -- material

   if (board.piece_nb > 4) then
     return false;
   end

   material_get_info(mat_info,board);

   if ( bit.band( mat_info.flags, DrawNodeFlag ) == 0) then
     return false;
   end

   -- recognisers


   ifelse = true;
   if (mat_info.recog == MAT_KK) then

      -- KK

      return true;
   end

   if (mat_info.recog == MAT_KBK) then

      -- KBK (white)

      return true;
   end

   if (mat_info.recog == MAT_KKB) then

      -- KBK (black)

      return true;
   end

   if (mat_info.recog == MAT_KNK) then

      -- KNK (white)

      return true;
   end

   if (mat_info.recog == MAT_KKN) then

      -- KNK (black)

      return true;
   end

   if (mat_info.recog == MAT_KPK) then

      -- KPK (white)

      me = White;
      opp = COLOUR_OPP(me);

      wp = board.pawn[1+me][1+0];
      wk = KING_POS(board,me);
      bk = KING_POS(board,opp);

      if (SQUARE_FILE(wp) >= FileE) then
         wp = SQUARE_FILE_MIRROR(wp);
         wk = SQUARE_FILE_MIRROR(wk);
         bk = SQUARE_FILE_MIRROR(bk);
      end

      if (kpk_draw(wp,wk,bk,board.turn)) then
         return true;
      end
      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KKP) then

      -- KPK (black)

      me = Black;
      opp = COLOUR_OPP(me);

      wp = SQUARE_RANK_MIRROR(board.pawn[1+me][1+0]);
      wk = SQUARE_RANK_MIRROR(KING_POS(board,me));
      bk = SQUARE_RANK_MIRROR(KING_POS(board,opp));

      if (SQUARE_FILE(wp) >= FileE) then
         wp = SQUARE_FILE_MIRROR(wp);
         wk = SQUARE_FILE_MIRROR(wk);
         bk = SQUARE_FILE_MIRROR(bk);
      end

      if (kpk_draw(wp,wk,bk,COLOUR_OPP(board.turn))) then
         return true;
      end
      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KBKB) then

      -- KBKB

      wb = board.piece[1+White][1+1];
      bb = board.piece[1+Black][1+1];

      if (SQUARE_COLOUR(wb) == SQUARE_COLOUR(bb)) then   -- bishops on same colour
         return true;
      end
      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KBPK) then

      -- KBPK (white)

      me = White;
      opp = COLOUR_OPP(me);

      wp = board.pawn[1+me][1+0];
      wb = board.piece[1+me][1+1];
      bk = KING_POS(board,opp);

      if (SQUARE_FILE(wp) >= FileE) then
         wp = SQUARE_FILE_MIRROR(wp);
         wb = SQUARE_FILE_MIRROR(wb);
         bk = SQUARE_FILE_MIRROR(bk);
      end

      if (kbpk_draw(wp,wb,bk)) then
        return true;
      end
      ifelse = false;
   end

   if (ifelse and mat_info.recog == MAT_KKBP) then

      -- KBPK (black)

      me = Black;
      opp = COLOUR_OPP(me);

      wp = SQUARE_RANK_MIRROR(board.pawn[1+me][1+0]);
      wb = SQUARE_RANK_MIRROR(board.piece[1+me][1+1]);
      bk = SQUARE_RANK_MIRROR(KING_POS(board,opp));

      if (SQUARE_FILE(wp) >= FileE) then
         wp = SQUARE_FILE_MIRROR(wp);
         wb = SQUARE_FILE_MIRROR(wb);
         bk = SQUARE_FILE_MIRROR(bk);
      end

      if (kbpk_draw(wp,wb,bk)) then
        return true;
      end
      ifelse = false;
   end

   if (ifelse) then
      --ASSERT(623, false);
   end

   return false;
end

-- kpk_draw()

function kpk_draw( wp, wk, bk, turn )  -- bool

   local wp_file = 0;   -- int
   local wp_rank = 0;   -- int
   local wk_file = 0;   -- int
   local bk_file = 0;   -- int
   local bk_rank = 0;   -- int
   local ifelse = false;

   --ASSERT(624, SQUARE_IS_OK(wp));
   --ASSERT(625, SQUARE_IS_OK(wk));
   --ASSERT(626, SQUARE_IS_OK(bk));
   --ASSERT(627, COLOUR_IS_OK(turn));

   --ASSERT(628, SQUARE_FILE(wp)<=FileD);

   wp_file = SQUARE_FILE(wp);
   wp_rank = SQUARE_RANK(wp);

   wk_file = SQUARE_FILE(wk);

   bk_file = SQUARE_FILE(bk);
   bk_rank = SQUARE_RANK(bk);

   ifelse = true;
   if (ifelse and (bk == wp+16)) then

      if (wp_rank <= Rank6) then

         return true;

      else

         --ASSERT(629, wp_rank==Rank7);

         if (COLOUR_IS_WHITE(turn)) then
            if (wk == wp-15  or  wk == wp-17) then
              return true;
            end
         else
            if (wk ~= wp-15  and  wk ~= wp-17) then
              return true;
            end
         end
      end
      ifelse = false;
   end

   if (ifelse and (bk == wp+32)) then

      if (wp_rank <= Rank5) then

         return true;

      else

         --ASSERT(630, wp_rank==Rank6);

         if (COLOUR_IS_WHITE(turn)) then
            if (wk ~= wp-1  and  wk ~= wp+1) then
              return true;
            end
         else
            return true;
         end
      end

      ifelse = false;
   end

   if (ifelse and (wk == wp-1  or  wk == wp+1)) then

      if (bk == wk+32  and  COLOUR_IS_WHITE(turn)) then    -- opposition
         return true;
      end

      ifelse = false;
   end

   if (ifelse and (wk == wp+15  or  wk == wp+16  or  wk == wp+17)) then

      if (wp_rank <= Rank4) then
         if (bk == wk+32  and  COLOUR_IS_WHITE(turn)) then   -- opposition
            return true;
         end
      end
      ifelse = false;
   end

   -- rook pawn

   if (wp_file == FileA) then

      if (DISTANCE(bk,A8) <= 1) then
        return true;
      end

      if (wk_file == FileA) then
         if (wp_rank == Rank2) then
            wp_rank = wp_rank + 1; -- HACK
         end
         if (bk_file == FileC  and  bk_rank > wp_rank) then
            return true;
         end
      end
   end

   return false;

end

-- kbpk_draw()

function kbpk_draw ( wp, wb, bk )  -- bool

   --ASSERT(631, SQUARE_IS_OK(wp));
   --ASSERT(632, SQUARE_IS_OK(wb));
   --ASSERT(633, SQUARE_IS_OK(bk));

   if (SQUARE_FILE(wp) == FileA
     and  DISTANCE(bk,A8) <= 1
     and  SQUARE_COLOUR(wb) ~= SQUARE_COLOUR(A8)) then
      return true;
   end

   return false;
end

-- end of recog.cpp



-- search.cpp

-- functions

-- depth_is_ok()

function depth_is_ok( depth ) -- bool

   return (depth > -128)  and  (depth < DepthMax);
end

-- height_is_ok()

function height_is_ok( height ) -- bool

   return (height >= 0)  and  (height < HeightMax);
end

-- search_clear()

function search_clear() -- void

   -- SearchInput

   SearchInput.infinite = false;
   SearchInput.depth_is_limited = false;
   SearchInput.depth_limit = 0;
   SearchInput.time_is_limited = false;
   SearchInput.time_limit_1 = 0.0;
   SearchInput.time_limit_2 = 0.0;

   -- SearchInfo

   SearchInfo.can_stop = false;
   SearchInfo.stop = false;
   SearchInfo.check_nb = 10000;  -- was 100000
   SearchInfo.check_inc = 10000; -- was 100000
   SearchInfo.last_time = 0.0;

   -- SearchBest

   SearchBest.move = MoveNone;
   SearchBest.value = 0;
   SearchBest.flags = SearchUnknown;
   SearchBest.pv[1+0] = MoveNone;

   -- SearchRoot

   SearchRoot.depth = 0;
   SearchRoot.move = MoveNone;
   SearchRoot.move_pos = 0;
   SearchRoot.move_nb = 0;
   SearchRoot.last_value = 0;
   SearchRoot.bad_1 = false;
   SearchRoot.bad_2 = false;
   SearchRoot.change = false;
   SearchRoot.easy = false;
   SearchRoot.flag = false;

   -- SearchCurrent

   SearchCurrent.mate = 0;
   SearchCurrent.depth = 0;
   SearchCurrent.max_depth = 0;
   SearchCurrent.node_nb = 0;
   SearchCurrent.time = 0.0;
   SearchCurrent.speed = 0.0;
end

-- search()

function search() -- void

   local move = MoveNone;    -- int
   local depth = 0;          -- int

   --ASSERT(634, board_is_ok(SearchInput.board));

   -- opening book

   if (option_get_bool("OwnBook")  and (not SearchInput.infinite)) then

      -- no book here
      -- move = book_move(SearchInput.board);

      if (move ~= MoveNone) then

         -- play book move

         SearchBest.move = move;
         SearchBest.value = 1;
         SearchBest.flags = SearchExact;
         SearchBest.depth = 1;
         SearchBest.pv[1+0] = move;
         SearchBest.pv[1+1] = MoveNone;

         search_update_best();

         return;
      end
   end

   -- SearchInput

   gen_legal_moves(SearchInput.list,SearchInput.board);

   if ( SearchInput.list.size <= 1) then
      SearchInput.depth_is_limited = true;
      SearchInput.depth_limit = 4;        -- was 1
   end

   -- SearchInfo

 setjmp = false;
 while(true) do	-- setjmp loop


   if (setjmp) then
      setjmp = false;
      --ASSERT(635, SearchInfo.can_stop);
      --ASSERT(636, SearchBest.move~=MoveNone);
      search_update_current();
      return;
   end

   -- SearchRoot

   list_copy(SearchRoot.list,SearchInput.list);

   -- SearchCurrent

   board_copy(SearchCurrent.board,SearchInput.board);
   my_timer_reset(SearchCurrent.timer);
   my_timer_start(SearchCurrent.timer);

   -- init

   trans_inc_date(Trans);

   sort_init1();
   search_full_init(SearchRoot.list,SearchCurrent.board);

   -- iterative deepening

   for depth = 1, DepthMax-1, 1 do

      if (DispDepthStart) then
         send("info depth " .. string.format("%d",depth));
      end

      SearchRoot.bad_1 = false;
      SearchRoot.change = false;

      board_copy(SearchCurrent.board,SearchInput.board);

      if (UseShortSearch  and  depth <= ShortSearchDepth) then
         search_full_root(SearchRoot.list,SearchCurrent.board,depth,SearchShort);
         if (setjmp) then
           break;
         end
      else
         search_full_root(SearchRoot.list,SearchCurrent.board,depth,SearchNormal);
         if (setjmp) then
           break;
         end
      end

      search_update_current();

      if (DispDepthEnd) then
         send_ndtm(6);
      end

      -- update search info

      if (depth >= 1) then
        SearchInfo.can_stop = true;
      end

      if (depth == 1
        and  SearchRoot.list.size >= 2
        and  SearchRoot.list.value[1+0] >= SearchRoot.list.value[1+1] + EasyThreshold) then
         SearchRoot.easy = true;
      end

      if (UseBad  and  depth > 1) then
         SearchRoot.bad_2 = SearchRoot.bad_1;
         SearchRoot.bad_1 = false;
         --ASSERT(637, SearchRoot.bad_2==(SearchBest.value<=SearchRoot.last_value-BadThreshold));
      end

      SearchRoot.last_value = SearchBest.value;

      -- stop search?

      if (SearchInput.depth_is_limited
        and  depth >= SearchInput.depth_limit) then
         SearchRoot.flag = true;
      end

      if (SearchInput.time_is_limited
        and  SearchCurrent.time >= SearchInput.time_limit_1
        and  not SearchRoot.bad_2) then
         SearchRoot.flag = true;
      end

      if (UseEasy
        and  SearchInput.time_is_limited
        and  SearchCurrent.time >= SearchInput.time_limit_1 * EasyRatio
        and  SearchRoot.easy) then
         --ASSERT(638, not SearchRoot.bad_2);
         --ASSERT(639, not SearchRoot.change);
         SearchRoot.flag = true;
      end

      if (UseEarly
        and  SearchInput.time_is_limited
        and  SearchCurrent.time >= SearchInput.time_limit_1 * EarlyRatio
        and  not SearchRoot.bad_2
        and  not SearchRoot.change) then
         SearchRoot.flag = true;
      end

      if (SearchInfo.can_stop
        and  (SearchInfo.stop  or  (SearchRoot.flag  and  not SearchInput.infinite))) then
         return;
      end
   end

 end	-- setjmp loop

end

-- search_update_best()

function search_update_best() -- void

   local move = 0;      -- int
   local value = 0;     -- int
   local flags = 0;     -- int
   local depth = 0;     -- int
   local max_depth = 0; -- int
   local pv = nil;
   local time = 0.0;
   local node_nb = 0;                  -- sint64
   local mate = 0;                     -- int
   local move_string = string_t();     -- string
   local pv_string = string_t();       -- string

   search_update_current();

   if (DispBest) then

      move = SearchBest.move;
      value = SearchBest.value;
      flags = SearchBest.flags;
      depth = SearchBest.depth;
      pv = SearchBest.pv;

      max_depth = SearchCurrent.max_depth;
      time = SearchCurrent.time;
      node_nb = SearchCurrent.node_nb;

      move_to_string(move,move_string);
      pv_to_string(pv,pv_string);

      mate = value_to_mate(value);
      SearchCurrent.mate = mate;

      if (mate == 0) then

         -- normal evaluation

         if (flags == SearchExact) then
            send_ndtm(10);
         else
            if (flags == SearchLower) then
              send_ndtm(11);
            else
              if (flags == SearchUpper) then
                 send_ndtm(12);
              end
            end
         end

      else

         -- mate announcement

         if (flags == SearchExact) then
            send_ndtm(20);
         else
            if (flags == SearchLower) then
              send_ndtm(21);
            else
              if (flags == SearchUpper) then
                 send_ndtm(22);
              end
            end
         end

      end
   end

   -- update time-management info

   if (UseBad  and  SearchBest.depth > 1) then
      if (SearchBest.value <= SearchRoot.last_value - BadThreshold) then
         SearchRoot.bad_1 = true;
         SearchRoot.easy = false;
         SearchRoot.flag = false;
      else
         SearchRoot.bad_1 = false;
      end
   end

end

-- search_update_root()

function search_update_root() -- void

   local move = 0;       -- int
   local move_pos = 0;   -- int

   local move_string = string_t();  -- string

   if (DispRoot) then

      search_update_current();

      if (SearchCurrent.time >= 1.0) then

         move = SearchRoot.move;
         move_pos = SearchRoot.move_pos;

         move_to_string(move,move_string);

         send("info currmove " .. move_string.v .. " currmovenumber ".. string.format( "%d",move_pos+1));
      end

   end
end

-- search_update_current()

function search_update_current() -- void

   local timer = nil;
   local node_nb = 0;
   local etime = 0.0;
   local speed = 0.0;

   timer = SearchCurrent.timer;
   node_nb = SearchCurrent.node_nb;

   etime = my_timer_elapsed_real(timer);
   speed = iif(etime >= 1.0, node_nb / etime, 0.0 );

   SearchCurrent.time = etime;
   SearchCurrent.speed = speed;

end

-- search_check()

function search_check()  -- void

   -- search_send_stat();

   -- event();

   if (SearchInput.depth_is_limited
     and  SearchRoot.depth > SearchInput.depth_limit) then
      SearchRoot.flag = true;
   end

   if (SearchInput.time_is_limited
     and  SearchCurrent.time >= SearchInput.time_limit_2) then
      SearchRoot.flag = true;
   end

   if (SearchInput.time_is_limited
     and  SearchCurrent.time >= SearchInput.time_limit_1
     and  not SearchRoot.bad_1
     and  not SearchRoot.bad_2
     and  (not UseExtension  or  SearchRoot.move_pos == 0)) then
      SearchRoot.flag = true;
   end

   if (SearchInfo.can_stop
     and  (SearchInfo.stop  or  (SearchRoot.flag  and  not SearchInput.infinite))) then
      setjmp = true;  -- the same as  longjmp(SearchInfo.buf,1);
   end

end

-- search_send_stat()

function search_send_stat()  -- void

   local node_nb = 0;
   local time = 0.0;
   local speed = 0.0;

   search_update_current();

   if (DispStat  and  SearchCurrent.time >= SearchInfo.last_time + 1.0) then  -- at least one-second gap

      SearchInfo.last_time = SearchCurrent.time;

      time = SearchCurrent.time;
      speed = SearchCurrent.speed;
      node_nb = SearchCurrent.node_nb;

      send_ndtm(3);

      trans_stats(Trans);
   end

end

-- end of search.cpp



-- search_full.cpp

-- functions

-- search_full_init()

function search_full_init( list, board )

   local str1 = "";     -- string
   local tmove = 0;     -- int

   --ASSERT(640, list_is_ok(list));
   --ASSERT(641, board_is_ok(board));

   -- nil-move options

   str1 = option_get_string("nilMove Pruning");

   if (string_equal(str1,"Always")) then
      Usenil = true;
      UsenilEval = false;
   else
    if (string_equal(str1,"Fail High")) then
      Usenil = true;
      UsenilEval = true;
    else
     if (string_equal(str1,"Never")) then
       Usenil = false;
       UsenilEval = false;
     else
       --ASSERT(642, false);
       Usenil = true;
       UsenilEval = true;
     end
    end
   end

   nilReduction = option_get_int("nilMove Reduction");

   str1 = option_get_string("Verification Search");

   if (string_equal(str1,"Always")) then
      UseVer = true;
      UseVerEndgame = false;
   else
    if (string_equal(str1,"Endgame")) then
      UseVer = true;
      UseVerEndgame = true;
    else
     if (string_equal(str1,"Never")) then
      UseVer = false;
      UseVerEndgame = false;
     else
      --ASSERT(643, false);
      UseVer = true;
      UseVerEndgame = true;
     end
    end
   end

   VerReduction = option_get_int("Verification Reduction");

   -- history-pruning options

   UseHistory = option_get_bool("History Pruning");
   HistoryValue = (option_get_int("History Threshold") * 16384 + 50) / 100;

   -- futility-pruning options

   UseFutility = option_get_bool("Futility Pruning");
   FutilityMargin = option_get_int("Futility Margin");

   -- delta-pruning options

   UseDelta = option_get_bool("Delta Pruning");
   DeltaMargin = option_get_int("Delta Margin");

   -- quiescence-search options

   CheckNb = option_get_int("Quiescence Check Plies");
   CheckDepth = 1 - CheckNb;

   -- standard sort

   list_note(list);
   list_sort(list);

   -- basic sort

   tmove = MoveNone;
   if (UseTrans) then
     trans_retrieve(Trans, board.key, TransRv);
     tmove = TransRv.trans_move;
   end

   note_moves(list,board,0,tmove);
   list_sort(list);
end

-- search_full_root()

function search_full_root( list, board, depth, search_type )  -- int

   local value = 0;   -- int

   --ASSERT(644, list_is_ok(list));
   --ASSERT(645, board_is_ok(board));
   --ASSERT(646, depth_is_ok(depth));
   --ASSERT(647, search_type==SearchNormal or search_type==SearchShort);

   --ASSERT(648, list==SearchRoot.list);
   --ASSERT(649, not (list.size==0));
   --ASSERT(650, board==SearchCurrent.board);
   --ASSERT(651, board_is_legal(board));
   --ASSERT(652, depth>=1);

   value = full_root(list,board,-ValueInf, ValueInf,depth,0,search_type);
   if( setjmp ) then
     return 0;
   end

   --ASSERT(653, value_is_ok(value));
   --ASSERT(654, list.value[1+0]==value);

   return value;
end

-- full_root()

function full_root( list, board, alpha, beta, depth, height, search_type )  -- int

   local old_alpha = 0;    -- int
   local value = 0;        -- int
   local best_value = 0;   -- int
   local i = 0;            -- int
   local move = 0;         -- int
   local new_depth;        -- int
   local undo = undo_t();  -- undo_t[1]
   local new_pv = {};      -- int[HeightMax];

   --ASSERT(655, list_is_ok(list));
   --ASSERT(656, board_is_ok(board));
   --ASSERT(657, range_is_ok(alpha,beta));
   --ASSERT(658, depth_is_ok(depth));
   --ASSERT(659, height_is_ok(height));
   --ASSERT(660, search_type==SearchNormal or search_type==SearchShort);

   --ASSERT(661, list.size==SearchRoot.list.size);
   --ASSERT(662, not (list.size==0));
   --ASSERT(663, board.key==SearchCurrent.board.key);
   --ASSERT(664, board_is_legal(board));
   --ASSERT(665, depth>=1);

   -- init

   SearchCurrent.node_nb = SearchCurrent.node_nb + 1;
   SearchInfo.check_nb = SearchInfo.check_nb - 1;

   for i = 0, list.size-1, 1 do
     list.value[1+i] = ValueNone;
   end

   old_alpha = alpha;
   best_value = ValueNone;

   -- move loop

   for i = 0, list.size-1, 1 do

      move = list.move[1+i];

      SearchRoot.depth = depth;
      SearchRoot.move = move;
      SearchRoot.move_pos = i;
      SearchRoot.move_nb = list.size;

      search_update_root();

      new_depth = full_new_depth(depth,move,board,board_is_check(board) and list.size==1,true);

      move_do(board,move,undo);

      if (search_type == SearchShort  or  best_value == ValueNone) then   -- first move
         value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,NodePV);
         if( setjmp ) then
           return 0;
         end
      else  -- other moves
         value = -full_search(board,-alpha-1,-alpha,new_depth,height+1,new_pv,NodeCut);
         if( setjmp ) then
           return 0;
         end
         if (value > alpha) then   --  and  value < beta
            SearchRoot.change = true;
            SearchRoot.easy = false;
            SearchRoot.flag = false;
            search_update_root();
            value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,NodePV);
            if( setjmp ) then
              return 0;
            end
         end
      end

      move_undo(board,move,undo);

      if (value <= alpha) then    -- upper bound
         list.value[1+i] = old_alpha;
      else
       if (value >= beta) then    -- lower bound
         list.value[1+i] = beta;
       else      -- alpha < value < beta => exact value
         list.value[1+i] = value;
       end
      end

      if (value > best_value  and  (best_value == ValueNone  or  value > alpha)) then

         SearchBest.move = move;
         SearchBest.value = value;
         if (value <= alpha) then    -- upper bound
            SearchBest.flags = SearchUpper;
         else
          if (value >= beta) then    -- lower bound
            SearchBest.flags = SearchLower;
          else      -- alpha < value < beta => exact value
            SearchBest.flags = SearchExact;
          end
         end
         SearchBest.depth = depth;
         pv_cat(SearchBest.pv,new_pv,move);

         search_update_best();
      end

      if (value > best_value) then
         best_value = value;
         if (value > alpha) then
            if (search_type == SearchNormal) then
              alpha = value;
            end
            if (value >= beta) then
              break;
            end
         end
      end
   end

   --ASSERT(666, value_is_ok(best_value));

   list_sort(list);

   --ASSERT(667, SearchBest.move==list.move[1+0]);
   --ASSERT(668, SearchBest.value==best_value);

   if (UseTrans  and  best_value > old_alpha  and  best_value < beta) then
      pv_fill(SearchBest.pv, 0, board);
   end

   return best_value;

end

-- full_search()

function full_search( board, alpha, beta, depth, height, pv, node_type )  -- int

   local in_check = false;       -- bool
   local single_reply = false;   -- bool
   local tmove = 0;       -- int
   local tdepth = 0;      -- int

   local min_value = 0;   -- int
   local max_value = 0;   -- int
   local old_alpha = 0;   -- int
   local value = 0;       -- int
   local best_value = 0;  -- int

   local bmove = int_t(); -- int
   local move = 0;        -- int

   local best_move = 0;   -- int
   local new_depth = 0;   -- int
   local played_nb = 0;   -- int
   local i = 0;           -- int
   local opt_value = 0;   -- int
   local reduced = false;      -- bool
   local attack = attack_t();  -- attack_t[1]
   local sort = sort_t();      -- sort_t[1]
   local undo = undo_t();      -- undo_t[1]
   local new_pv = {};          -- int[HeightMax]
   local played = {};          -- int[256]
   local gotocut = false;
   local cont = false;

   --ASSERT(669, board.sp~=nil);
   --ASSERT(670, range_is_ok(alpha,beta));
   --ASSERT(671, depth_is_ok(depth));
   --ASSERT(672, height_is_ok(height));
   -- --ASSERT(673, pv[1+0]~=nil);
   --ASSERT(674, node_type==NodePV or node_type==NodeCut or node_type==NodeAll);

   --ASSERT(675, board_is_legal(board));

   -- horizon?

   if (depth <= 0) then
     return full_quiescence(board,alpha,beta,0,height,pv);
   end

   -- init

   SearchCurrent.node_nb = SearchCurrent.node_nb + 1;
   SearchInfo.check_nb = SearchInfo.check_nb - 1;
   pv[1+0] = MoveNone;

   if (height > SearchCurrent.max_depth) then
     SearchCurrent.max_depth = height;
   end

   if (SearchInfo.check_nb <= 0) then
      SearchInfo.check_nb = SearchInfo.check_nb + SearchInfo.check_inc;
      search_check();
      if( setjmp ) then
        return 0;
      end
   end

   -- draw?

   if (board_is_repetition(board)  or  recog_draw(board)) then
     return ValueDraw;
   end

   -- mate-distance pruning

   if (UseDistancePruning) then

      -- lower bound

      value = (height+2-ValueMate); -- does not work if the current position is mate
      if (value > alpha  and  board_is_mate(board)) then
         value = (height-ValueMate);
      end

      if (value > alpha) then
         alpha = value;
         if (value >= beta) then
           return value;
         end
      end

      -- upper bound

      value = -(height+1-ValueMate);

      if (value < beta) then
         beta = value;
         if (value <= alpha) then
           return value;
         end
      end
   end

   -- transposition table

   tmove = MoveNone;

   if (UseTrans  and  depth >= TransDepth) then

     if( trans_retrieve(Trans, board.key, TransRv)) then

         tmove = TransRv.trans_move;

         -- trans_move is now updated

         if (node_type ~= NodePV) then

            if (UseMateValues) then

               if (TransRv.trans_min_value > ValueEvalInf  and  TransRv.trans_min_depth < depth) then
                  TransRv.trans_min_depth = depth;
               end

               if (TransRv.trans_max_value < -ValueEvalInf  and  TransRv.trans_max_depth < depth) then
                  TransRv.trans_max_depth = depth;
               end
            end

            min_value = -ValueInf;

            if ( TransRv.trans_min_depth >= depth ) then
               min_value = value_from_trans(TransRv.trans_min_value,height);
               if (min_value >= beta) then
                 return min_value;
               end
            end

            max_value = ValueInf;

            if ( TransRv.trans_max_depth >= depth ) then
               max_value = value_from_trans(TransRv.trans_max_value,height);
               if (max_value <= alpha) then
                 return max_value;
               end
            end

            if (min_value == max_value) then
              return min_value; -- exact match
            end
         end
      end
   end

   -- height limit

   if (height >= HeightMax-1) then
     return evalpos(board);
   end

   -- more init

   old_alpha = alpha;
   best_value = ValueNone;
   best_move = MoveNone;
   played_nb = 0;

   attack_set(attack,board);
   in_check = ATTACK_IN_CHECK(attack);

   -- nil-move pruning

   if (Usenil  and  depth >= nilDepth  and  node_type ~= NodePV) then

      if (not in_check
        and  not value_is_mate(beta)
        and  do_nil(board)
        and  (not UsenilEval  or  depth <= nilReduction+1  or  evalpos(board) >= beta)) then

         -- nil-move search

         new_depth = depth - nilReduction - 1;

         move_do_nil(board,undo);
         value = -full_search(board,-beta,-beta+1,new_depth,height+1,new_pv,-node_type);
         if( setjmp ) then
           return 0;
         end
         move_undo_nil(board,undo);

         -- verification search

         if (UseVer  and  depth > VerReduction) then

            if (value >= beta  and  (not UseVerEndgame  or  do_ver(board))) then

               new_depth = depth - VerReduction;
               --ASSERT(676, new_depth>0);

               value = full_no_nil(board,alpha,beta,new_depth,height,new_pv,NodeCut,tmove, bmove);
               move = bmove.v;

               if( setjmp ) then
                 return 0;
               end
               if (value >= beta) then
                  --ASSERT(677, move==new_pv[1+0]);
                  played[1+played_nb] = move;
                  played_nb = played_nb + 1;
                  best_move = move;
                  best_value = value;
                  pv_copy(pv,new_pv);
                  gotocut = true;
               end
            end
         end

         -- pruning

         if ((not gotocut) and value >= beta) then

            if (value > ValueEvalInf) then
              value = ValueEvalInf; -- do not return unproven mates
            end
            --ASSERT(678, not value_is_mate(value));

            -- pv_cat(pv,new_pv,Movenil);

            best_move = MoveNone;
            best_value = value;
            gotocut = true;
         end
      end
   end

 if(not gotocut) then  -- [1]

   -- Internal Iterative Deepening

   if (UseIID  and  depth >= IIDDepth  and  node_type == NodePV  and  tmove == MoveNone) then

      new_depth = depth - IIDReduction;
      --ASSERT(679, new_depth>0);

      value = full_search(board,alpha,beta,new_depth,height,new_pv,node_type);
      if( setjmp ) then
        return 0;
      end
      if (value <= alpha) then
         value = full_search(board,-ValueInf,beta,new_depth,height,new_pv,node_type);
         if( setjmp ) then
           return 0;
         end
      end

      tmove = new_pv[1+0];
   end

   -- move generation

   sort_init2(sort,board,attack,depth,height,tmove);

   single_reply = false;
   if (in_check  and  sort.list.size == 1) then
     single_reply = true; -- HACK
   end

   -- move loop

   opt_value = ValueInf;

   while(true) do

      move = sort_next(sort);
      if(move == MoveNone) then
        break
      end

      -- extensions

      new_depth = full_new_depth(depth,move,board,single_reply,node_type==NodePV);

      -- history pruning

      reduced = false;

      if (UseHistory  and  depth >= HistoryDepth  and  node_type ~= NodePV) then
         if (not in_check  and  played_nb >= HistoryMoveNb  and  new_depth < depth) then
            --ASSERT(680, best_value~=ValueNone);
            --ASSERT(681, played_nb>0);
            --ASSERT(682, sort.pos>0 and move==sort.list.move[1+sort.pos-1]);
            value = sort.value; -- history score
            if (value < HistoryValue) then
               --ASSERT(683, value>=0 and value<16384);
               --ASSERT(684, move~=tmove);
               --ASSERT(685, not move_is_tactical(move,board));
               --ASSERT(686, not move_is_check(move,board));
               new_depth = new_depth - 1;
               reduced = true;
            end
         end
      end

      -- futility pruning

      if (UseFutility  and  depth == 1  and  node_type ~= NodePV) then

         if ((not in_check)  and  new_depth == 0  and  (not move_is_tactical(move,board))
                   and  (not move_is_dangerous(move,board))) then

            --ASSERT(687, not move_is_check(move,board));

            -- optimistic evaluation

            if (opt_value == ValueInf) then
               opt_value = evalpos(board) + FutilityMargin;
               --ASSERT(688, opt_value<ValueInf);
            end

            value = opt_value;

            -- pruning

            if (value <= alpha) then

               if (value > best_value) then
                  best_value = value;
                  pv[1+0] = MoveNone;
               end

               cont = true;
            end
         end
      end

     if(cont) then  -- continue [1]
       cont = false;
     else

      -- recursive search

      move_do(board,move,undo);

      if (node_type ~= NodePV  or  best_value == ValueNone) then    -- first move
         value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,-node_type);
         if( setjmp ) then
           return 0;
         end
      else       -- other moves
         value = -full_search(board,-alpha-1,-alpha,new_depth,height+1,new_pv,NodeCut);
         if( setjmp ) then
           return 0;
         end
         if (value > alpha) then    --  and  value < beta
            value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,NodePV);
            if( setjmp ) then
              return 0;
            end
         end
      end

      -- history-pruning re-search

      if (HistoryReSearch  and  reduced  and  value >= beta) then

         --ASSERT(689, node_type~=NodePV);

         new_depth = new_depth + 1;
         --ASSERT(690, new_depth==depth-1);

         value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,-node_type);
         if( setjmp ) then
           return 0;
         end
      end

      move_undo(board,move,undo);

      played[1+played_nb] = move;
      played_nb = played_nb + 1;

      if (value > best_value) then
         best_value = value;
         pv_cat(pv,new_pv,move);
         if (value > alpha) then
            alpha = value;
            best_move = move;
            if (value >= beta) then
              gotocut = true;
              break;
            end
         end
      end

      if (node_type == NodeCut) then
        node_type = NodeAll;
      end

     end  -- continue [1]

   end


 if(not gotocut) then  -- [2]

   -- ALL node

   if (best_value == ValueNone) then    -- no legal move
      if (in_check) then
         --ASSERT(691, board_is_mate(board));
         return (height-ValueMate);
      else
         --ASSERT(692, board_is_stalemate(board));
         return ValueDraw;
      end
   end

 end -- goto cut [2]
 end -- goto cut [1]

-- cut:

   --ASSERT(693, value_is_ok(best_value));

   -- move ordering

   if (best_move ~= MoveNone) then

      good_move(best_move,board,depth,height);

      if (best_value >= beta  and  (not move_is_tactical(best_move,board))) then

         --ASSERT(694, played_nb>0 and played[1+played_nb-1]==best_move);

         for i = 0, played_nb-2, 1 do
            move = played[1+i];
            --ASSERT(695, move~=best_move);
            history_bad(move,board);
         end

         history_good(best_move,board);
      end
   end

   -- transposition table

   if (UseTrans  and  depth >= TransDepth) then

      tmove = best_move;
      tdepth = depth;
      TransRv.trans_min_value = iif( best_value > old_alpha,  value_to_trans(best_value,height) , -ValueInf );
      TransRv.trans_max_value = iif( best_value < beta , value_to_trans(best_value,height) , ValueInf );

      trans_store(Trans,board.key, tmove, tdepth, TransRv);
   end

   return best_value;

end


-- full_no_nil()

function full_no_nil( board, alpha,  beta, depth, height, pv, node_type, tmove,  b_move )  -- int

   local value = 0;            -- int
   local best_value = 0;       -- int
   local move = 0;             -- int
   local new_depth = 0;        -- int

   local attack = attack_t();  -- attack_t[1]
   local sort = sort_t();      -- sort_t[1]
   local undo = undo_t();      -- undo_t[1]
   local new_pv = {};          -- int[HeightMax]
   local gotocut = false;

   --ASSERT(696, board.sp~=nil);
   --ASSERT(697, range_is_ok(alpha,beta));
   --ASSERT(698, depth_is_ok(depth));
   --ASSERT(699, height_is_ok(height));
   -- --ASSERT(700, pv[1+0]~=nil);
   --ASSERT(701, node_type==NodePV or node_type==NodeCut or node_type==NodeAll);
   --ASSERT(702, tmove==MoveNone or move_is_ok(tmove));
   --ASSERT(703, best_move~=nil);

   --ASSERT(704, board_is_legal(board));
   --ASSERT(705, not board_is_check(board));
   --ASSERT(706, depth>=1);

   -- init

   SearchCurrent.node_nb = SearchCurrent.node_nb + 1;
   SearchInfo.check_nb = SearchInfo.check_nb - 1;
   pv[1+0] = MoveNone;

   if (height > SearchCurrent.max_depth) then
     SearchCurrent.max_depth = height;
   end

   if (SearchInfo.check_nb <= 0) then
      SearchInfo.check_nb = SearchInfo.check_nb + SearchInfo.check_inc;
      search_check();
      if( setjmp ) then
        return 0;
      end
   end

   attack_set(attack,board);
   --ASSERT(707, not ATTACK_IN_CHECK(attack));

   b_move.v = MoveNone;
   best_value = ValueNone;

   -- move loop

   sort_init2(sort,board,attack,depth,height,tmove);


   while(true) do

      move = sort_next(sort);
      if(move == MoveNone) then
        break
      end

      new_depth = full_new_depth(depth,move,board,false,false);

      move_do(board,move,undo);
      value = -full_search(board,-beta,-alpha,new_depth,height+1,new_pv,-node_type);
      if( setjmp ) then
         return 0;
      end
      move_undo(board,move,undo);

      if (value > best_value) then
         best_value = value;
         pv_cat(pv,new_pv,move);
         if (value > alpha) then
            alpha = value;
            b_move.v = move;
            if (value >= beta) then
              gotocut = true;
              break;
            end
         end
      end

   end

 if(not gotocut) then  -- [1]

   -- ALL node

   if (best_value == ValueNone) then     -- no legal move => stalemate
      --ASSERT(708, board_is_stalemate(board));
      best_value = ValueDraw;
   end

 end -- goto cut [1]

-- cut:

   --ASSERT(709, value_is_ok(best_value));

   return best_value;

end

-- full_quiescence()

function full_quiescence( board, alpha, beta, depth, height, pv ) -- int

   local in_check = false;     -- bool
   local old_alpha = 0;        -- int

   local value = 0;            -- int
   local best_move = 0;        -- int
   local best_value = 0;       -- int
   local opt_value = 0;        -- int
   local move = 0;             -- int

   local to = 0;               -- int
   local capture = 0;          -- int

   local attack = attack_t();  -- attack_t[1]
   local sort = sort_t();      -- sort_t[1]
   local undo = undo_t();      -- undo_t[1]
   local new_pv = {};          -- int[HeightMax]

   local gotocut = false;
   local cont = false;

   --ASSERT(710, board.sp~=nil);
   --ASSERT(711, range_is_ok(alpha,beta));
   --ASSERT(712, depth_is_ok(depth));
   --ASSERT(713, height_is_ok(height));
   -- --ASSERT(714, pv[1+0]~=nil);

   --ASSERT(715, board_is_legal(board));
   --ASSERT(716, depth<=0);

   -- init

   SearchCurrent.node_nb = SearchCurrent.node_nb + 1;
   SearchInfo.check_nb = SearchInfo.check_nb - 1;
   pv[1+0] = MoveNone;

   if (height > SearchCurrent.max_depth) then
     SearchCurrent.max_depth = height;
   end

   if (SearchInfo.check_nb <= 0) then
      SearchInfo.check_nb = SearchInfo.check_nb + SearchInfo.check_inc;
      search_check();
      if( setjmp ) then
        return 0;
      end
   end

   -- draw?

   if (board_is_repetition(board)  or  recog_draw(board)) then
     return ValueDraw;
   end

   -- mate-distance pruning

   if (UseDistancePruning) then

      -- lower bound

      value = (height+2-ValueMate); -- does not work if the current position is mate
      if (value > alpha  and  board_is_mate(board)) then
        value = (height-ValueMate);
      end

      if (value > alpha) then
         alpha = value;
         if (value >= beta) then
           return value;
         end
      end

      -- upper bound

      value = -(height+1-ValueMate);

      if (value < beta) then
         beta = value;
         if (value <= alpha) then
           return value;
         end
      end
   end

   -- more init

   attack_set(attack,board);
   in_check = ATTACK_IN_CHECK(attack);

   if (in_check) then
      --ASSERT(717, depth<0);
      depth = depth + 1; -- in-check extension
   end

   -- height limit

   if (height >= HeightMax-1) then
     return evalpos(board);
   end

   -- more init

   old_alpha = alpha;
   best_value = ValueNone;
   best_move = MoveNone;

   -- if (UseDelta)
   opt_value = ValueInf;

   if (not in_check) then

      -- lone-king stalemate?

      if (simple_stalemate(board)) then
        return ValueDraw;
      end

      -- stand pat

      value = evalpos(board);

      --ASSERT(718, value>best_value);
      best_value = value;
      if (value > alpha) then
         alpha = value;
         if (value >= beta) then
           gotocut = true;
         end
      end

      if ((not gotocut) and UseDelta) then
         opt_value = value + DeltaMargin;
         --ASSERT(719, opt_value<ValueInf);
      end
   end

 if(not gotocut) then  -- [1]

   -- move loop

   sort_init_qs(sort,board,attack,depth>=CheckDepth);


   while(true) do

      move = sort_next_qs(sort);
      if(move == MoveNone) then
        break
      end


      -- delta pruning

      if (UseDelta  and  beta == old_alpha+1) then

         if ((not in_check) and (not move_is_check(move,board)) and (not capture_is_dangerous(move,board))) then

            --ASSERT(720, move_is_tactical(move,board));

            -- optimistic evaluation

            value = opt_value;

            to = MOVE_TO(move);
            capture = board.square[1+to];

            if (capture ~= Empty) then
               value = value + ValuePiece[1+capture];
            else
             if (MOVE_IS_EN_PASSANT(move)) then
               value = value + ValuePawn;
             end
            end

            if (MOVE_IS_PROMOTE(move)) then
              value = value + ValueQueen - ValuePawn;
            end

            -- pruning

            if (value <= alpha) then

               if (value > best_value) then
                  best_value = value;
                  pv[1+0] = MoveNone;
               end

               cont = true;
            end
         end
      end

     if(cont) then  -- continue [1]
       cont = false;
     else

      move_do(board,move,undo);
      value = -full_quiescence(board,-beta,-alpha,depth-1,height+1,new_pv);
      if( setjmp ) then
        return 0;
      end
      move_undo(board,move,undo);

      if (value > best_value) then
         best_value = value;
         pv_cat(pv,new_pv,move);
         if (value > alpha) then
            alpha = value;
            best_move = move;
            if (value >= beta) then
              gotocut = true;
              break;
            end
         end
      end

     end  -- continue [1]

   end

 if(not gotocut) then  -- [2]

   -- ALL node

   if (best_value == ValueNone) then        -- no legal move
      --ASSERT(721, board_is_mate(board));
      return (height-ValueMate);
   end

 end -- goto cut [2]
 end -- goto cut [1]

-- cut:

   --ASSERT(722, value_is_ok(best_value));

   return best_value;

end

-- full_new_depth()

function full_new_depth( depth, move, board, single_reply, in_pv )  -- int
   local new_depth = 0;   -- int
   local b = false;       -- bool

   --ASSERT(723, depth_is_ok(depth));
   --ASSERT(724, move_is_ok(move));
   --ASSERT(725, board.sp~=nil);
   --ASSERT(726, single_reply==true or single_reply==false);
   --ASSERT(727, in_pv==true or in_pv==false);

   --ASSERT(728, depth>0);

   new_depth = depth - 1;

   b = b or (single_reply  and  ExtendSingleReply);
   b = b or (in_pv  and  MOVE_TO(move) == board.cap_sq and  see_move(move,board) > 0)  -- recapture
   b = b or (in_pv  and  PIECE_IS_PAWN(MOVE_PIECE(move,board))
               and  PAWN_RANK(MOVE_TO(move),board.turn) == Rank7
               and  see_move(move,board) >= 0);
   b = b or move_is_check(move,board);
   if(b) then
      new_depth = new_depth + 1;
   end

   --ASSERT(729, new_depth>=0 and new_depth<=depth);

   return new_depth;
end

-- do_nil()

function do_nil( board )  -- bool

   --ASSERT(730, board.sp~=nil);

   -- use nil move if the side-to-move has at least one piece

   return (board.piece_size[1+board.turn] >= 2); -- king + one piece
end

-- do_ver()

function do_ver( board )  -- bool

   --ASSERT(731, board.sp~=nil);

   -- use verification if the side-to-move has at most one piece

   return (board.piece_size[1+board.turn] <= 2); -- king + one piece
end

-- pv_fill()

function pv_fill( pv, at, board ) -- void

   local move = 0;   -- int
   local tmove = 0;  -- int
   local tdepth = 0; -- int

   local undo = undo_t();      -- undo_t[1]

   --ASSERT(732, pv[1+at]~=nil);
   --ASSERT(733, board.sp~=nil);

   --ASSERT(734, UseTrans);

   move = pv[1+at];

   if (move ~= MoveNone  and  move ~= Movenil) then

      move_do(board,move,undo);
      pv_fill(pv, at+1,board);
      move_undo(board,move,undo);

      tmove = move;
      tdepth = -127; -- HACK
      TransRv.trans_min_value = -ValueInf;
      TransRv.trans_max_value = ValueInf;

      trans_store(Trans, board.key, tmove, tdepth, TransRv);
   end
end

-- move_is_dangerous()

function move_is_dangerous( move, board )  -- bool

   local piece = 0;   -- int

   --ASSERT(735, move_is_ok(move));
   --ASSERT(736, board.sp~=nil);

   --ASSERT(737, not move_is_tactical(move,board));

   piece = MOVE_PIECE(move,board);

   if (PIECE_IS_PAWN(piece) and  PAWN_RANK(MOVE_TO(move),board.turn) >= Rank7) then
      return true;
   end

   return false;
end

-- capture_is_dangerous()

function capture_is_dangerous( move, board )  -- bool

   local piece = 0;     -- int
   local capture = 0;   -- int

   --ASSERT(738, move_is_ok(move));
   --ASSERT(739, board.sp~=nil);

   --ASSERT(740, move_is_tactical(move,board));

   piece = MOVE_PIECE(move,board);

   if (PIECE_IS_PAWN(piece) and  PAWN_RANK(MOVE_TO(move),board.turn) >= Rank7) then
      return true;
   end

   capture = move_capture(move,board);

   if (PIECE_IS_QUEEN(capture)) then
     return true;
   end

   if (PIECE_IS_PAWN(capture) and  PAWN_RANK(MOVE_TO(move),board.turn) <= Rank2) then
      return true;
   end

   return false;
end

-- simple_stalemate()

function simple_stalemate( board )  -- bool

   local me = 0          -- int
   local opp = 0;        -- int
   local king = 0;       -- int
   local opp_flag = 0;   -- int
   local from = 0;       -- int
   local to = 0;         -- int
   local capture = 0;    -- int
   local inc_ptr = 0;    -- int
   local inc = 0;        -- int

   --ASSERT(741, board.sp~=nil);

   --ASSERT(742, board_is_legal(board));
   --ASSERT(743, not board_is_check(board));

   -- lone king?

   me = board.turn;
   if (board.piece_size[1+me] ~= 1  or  board.pawn_size[1+me] ~= 0) then
     return false; -- no
   end

   -- king in a corner?

   king = KING_POS(board,me);
   if (king ~= A1  and  king ~= H1  and  king ~= A8  and  king ~= H8) then
     return false; -- no
   end

   -- init

   opp = COLOUR_OPP(me);
   opp_flag = COLOUR_FLAG(opp);

   -- king can move?

   from = king;

   inc_ptr = 0;
   while(true) do
      inc = KingInc[1+inc_ptr];
      if( inc == IncNone ) then
        break;
      end

      to = from + inc;
      capture = board.square[1+to];
      if (capture == Empty  or  FLAG_IS(capture,opp_flag)) then
         if (not is_attacked(board,to,opp)) then
           return false; -- legal king move
         end
      end

      inc_ptr = inc_ptr + 1;
   end


   -- no legal move

   --ASSERT(744, board_is_stalemate( board ));

   return true;
end

-- end of search_full.cpp



-- see.cpp

-- types

-- functions

-- see_move()

function see_move( move, board )  -- int

   local att = 0;              -- int
   local def = 0;              -- int
   local from = 0;             -- int
   local to = 0;               -- int
   local value = 0;            -- int
   local piece_value = 0;      -- int
   local piece = 0;            -- int
   local capture = 0;          -- int
   local pos = 0;              -- int
   local alists = alists_t();  -- alists_t[1]
   local alist = nil;          -- alist_t *

   --ASSERT(745, move_is_ok(move));
   --ASSERT(746, board.sp~=nil);

   -- init

   from = MOVE_FROM(move);
   to = MOVE_TO(move);

   -- move the piece

   piece_value = 0;

   piece = board.square[1+from];
   --ASSERT(747, piece_is_ok(piece));

   att = PIECE_COLOUR(piece);
   def = COLOUR_OPP(att);

   -- promote

   if (MOVE_IS_PROMOTE(move)) then
      --ASSERT(748, PIECE_IS_PAWN(piece));
      piece = move_promote(move);
      --ASSERT(749, piece_is_ok(piece));
      --ASSERT(750, COLOUR_IS(piece,att));
   end

   piece_value = piece_value + ValuePiece[1+piece];

   -- clear attacker lists

   alist_clear(alists.alist[1+Black]);
   alist_clear(alists.alist[1+White]);

   -- find hidden attackers

   alists_hidden(alists,board,from,to);

   -- capture the piece

   value = 0;

   capture = board.square[1+to];

   if (capture ~= Empty) then

      --ASSERT(751, piece_is_ok(capture));
      --ASSERT(752, COLOUR_IS(capture,def));

      value = value + ValuePiece[1+capture];
   end

   -- promote

   if (MOVE_IS_PROMOTE(move)) then
      value = value + ValuePiece[1+piece] - ValuePawn;
   end

   -- en-passant

   if (MOVE_IS_EN_PASSANT(move)) then
      --ASSERT(753, value==0);
      --ASSERT(754, PIECE_IS_PAWN(board.square[1+SQUARE_EP_DUAL(to)]));
      value = value + ValuePawn;
      alists_hidden(alists,board,SQUARE_EP_DUAL(to),to);
   end

   -- build defender list

   alist = alists.alist[1+def];

   alist_build(alist,board,to,def);
   if (alist.size == 0) then
     return value; -- no defender => stop SEE
   end

   -- build attacker list

   alist = alists.alist[1+att];

   alist_build(alist,board,to,att);

   -- remove the moved piece (if it's an attacker)

   pos = 0;
   while( pos<alist.size  and  alist.square[1+pos] ~= from ) do
     pos = pos + 1;
   end

   if (pos < alist.size) then
     alist_remove(alist,pos);
   end

   -- SEE search

   value = value - see_rec(alists,board,def,to,piece_value);

   return value;

end

-- see_square()

function see_square( board, to, colour )  -- int

   local att = 0;              -- int
   local def = 0;              -- int
   local piece_value = 0;      -- int
   local piece = 0;            -- int
   local alists = alists_t();  -- alists_t[1]
   local alist = nil;          -- alist_t *

   --ASSERT(755, board.sp~=nil);
   --ASSERT(756, SQUARE_IS_OK(to));
   --ASSERT(757, COLOUR_IS_OK(colour));

   --ASSERT(758, COLOUR_IS(board.square[1+to],COLOUR_OPP(colour)));

   -- build attacker list

   att = colour;

   alist = alists.alist[1+att];

   alist_clear(alist);

   alist_build(alist,board,to,att);

   if (alist.size == 0) then
     return 0; -- no attacker => stop SEE
   end

   -- build defender list

   def = COLOUR_OPP(att);
   alist = alists.alist[1+def];

   alist_clear(alist);

   alist_build(alist,board,to,def);

   -- captured piece

   piece = board.square[1+to];
   --ASSERT(759, piece_is_ok(piece));
   --ASSERT(760, COLOUR_IS(piece,def));

   piece_value = ValuePiece[1+piece];

   -- SEE search

   return see_rec(alists,board,att,to,piece_value);

end

-- see_rec()

function see_rec( alists, board, colour, to, piece_value )  -- int

   local from = 0;    -- int
   local piece = 0;   -- int
   local value = 0;   -- int

   --ASSERT(761, alists.alist[1+colour]~=nil);
   --ASSERT(762, board.sp~=nil);
   --ASSERT(763, COLOUR_IS_OK(colour));
   --ASSERT(764, SQUARE_IS_OK(to));
   --ASSERT(765, piece_value>0);

   -- find the least valuable attacker

   from = alist_pop(alists.alist[1+colour],board);
   if (from == SquareNone) then
     return 0; -- no more attackers
   end

   -- find hidden attackers

   alists_hidden(alists,board,from,to);

   -- calculate the capture value

   value = piece_value; -- captured piece
   if (value == ValueKing) then
     return value; -- do not allow an answer to a king capture
   end

   piece = board.square[1+from];
   --ASSERT(766, piece_is_ok(piece));
   --ASSERT(767, COLOUR_IS(piece,colour));
   piece_value = ValuePiece[1+piece];

   -- promote

   if (piece_value == ValuePawn  and  SquareIsPromote[1+to]) then    -- HACK: PIECE_IS_PAWN(piece)
      --ASSERT(768, PIECE_IS_PAWN(piece));
      piece_value = ValueQueen;
      value = value + ValueQueen - ValuePawn;
   end

   value = value - see_rec(alists,board,COLOUR_OPP(colour),to,piece_value);

   if (value < 0) then
     value = 0;
   end

   return value;

end

-- alist_build()

function alist_build( alist, board, to, colour )  -- int

   local ptr = 0;    -- int
   local from = 0;   -- int
   local piece = 0;  -- int
   local delta = 0;  -- int
   local inc = 0;    -- int
   local sq = 0;     -- int
   local pawn = 0;   -- int

   --ASSERT(769, alist.size~=nil);
   --ASSERT(770, board.sp~=nil);
   --ASSERT(771, SQUARE_IS_OK(to));
   --ASSERT(772, COLOUR_IS_OK(colour));

   -- piece attacks

   ptr = 0;
   while(true) do

      from = board.piece[1+colour][1+ptr];

      if(from==SquareNone) then
        break;
      end

      piece = board.square[1+from];
      delta = to - from;

      if (PSEUDO_ATTACK(piece,delta)) then

         inc = DELTA_INC_ALL(delta);
         --ASSERT(773, inc~=IncNone);

         sq = from;
         while(true) do

            sq = sq + inc;
            if (sq == to) then  -- attack
               alist_add(alist,from,board);
               break;
            end

            if(board.square[1+sq] ~= Empty) then
               break;
            end

         end
      end

      ptr = ptr + 1;
   end

   -- pawn attacks

   inc = PawnMoveInc[1+colour];
   pawn = PawnMake[1+colour];

   from = to - (inc-1);
   if (board.square[1+from] == pawn) then
     alist_add(alist,from,board);
   end

   from = to - (inc+1);
   if (board.square[1+from] == pawn) then
     alist_add(alist,from,board);
   end

end

-- alists_hidden()

function alists_hidden( alists, board, from, to )  -- int

   local inc = 0;     -- int
   local sq = 0;      -- int
   local piece = 0;   -- int

   --ASSERT(775, board.sp~=nil);
   --ASSERT(776, SQUARE_IS_OK(from));
   --ASSERT(777, SQUARE_IS_OK(to));

   inc = DELTA_INC_LINE(to-from);

   if (inc ~= IncNone)  then  -- line

      sq = from;

      while(true) do
        sq = sq - inc;
        piece = board.square[1+sq];
        if ( piece~= Empty) then
          break;
        end
      end

      if (SLIDER_ATTACK(piece,inc)) then

         --ASSERT(778, piece_is_ok(piece));
         --ASSERT(779, PIECE_IS_SLIDER(piece));

         alist_add(alists.alist[1+PIECE_COLOUR(piece)],sq,board);
      end
   end

end

-- alist_clear()

function alist_clear( alist )

   --ASSERT(780, alist.size~=nil);

   alist.size = 0;
   alist.square = {};

end


-- alist_add()

function alist_add( alist, square, board )  -- int

   local piece = 0;   -- int
   local size = 0;    -- int
   local pos = 0;     -- int

   --ASSERT(781, alist.size~=nil);
   --ASSERT(782, SQUARE_IS_OK(square));
   --ASSERT(783, board.sp~=nil);

   -- insert in MV order

   piece = board.square[1+square];

   alist.size = alist.size + 1; -- HACK
   size = alist.size;

   --ASSERT(784, size>0 and size<16);

   pos = size-1;
   while( pos > 0  and  piece > board.square[1+alist.square[1+pos-1]]) do    -- HACK
      --ASSERT(785, pos>0 and pos<size);
      alist.square[1+pos] = alist.square[1+pos-1];
      pos = pos - 1;
   end

   --ASSERT(786, pos>=0 and pos<size);
   alist.square[1+pos] = square;

end

-- alist_remove()

function alist_remove( alist, pos )  -- int

   local size = 0;  -- int
   local i = 0;     -- int

   --ASSERT(787, alist.size~=nil);
   --ASSERT(788, pos>=0 and pos<alist.size);

   size = alist.size;
   alist.size = alist.size - 1;     -- HACK

   --ASSERT(789, size>=1);

   --ASSERT(790, pos>=0 and pos<size);

   for i = pos, size-2, 1 do
      --ASSERT(791, i>=0 and i<size-1);
      alist.square[1+i] = alist.square[1+i+1];
   end

end

-- alist_pop()

function alist_pop( alist, board )  -- int

   local sq = 0;     -- int
   local size = 0;   -- int

   --ASSERT(792, alist.size~=nil);
   --ASSERT(793, board.sp~=nil);

   sq = SquareNone;

   size = alist.size;

   if (size ~= 0) then
      size = size - 1;
      --ASSERT(794, size>=0);
      sq = alist.square[1+size];
      alist.size = size;
   end

   return sq;

end

-- end of see.cpp



-- sort.cpp



-- functions

-- sort_init()

function sort_init1() -- void

   local i = 0;        -- int
   local height = 0;   -- int
   local pos = 0;      -- int

   -- killer

   for height = 0, HeightMax-1, 1 do
      Killer[1+height] = {};
      for i = 0, 1, 1 do
        Killer[1+height][1+i] = MoveNone;
      end
   end

   -- history

   for i = 0, HistorySize-1, 1 do
      History[1+i] = 0;
      HistHit[1+i] = 1;
      HistTot[1+i] = 1;
   end

   -- Code[]

   for pos = 0, CODE_SIZE-1, 1 do
     Code[1+pos] = GEN_ERROR;
   end

   pos = 0;

   -- main search

   PosLegalEvasion = pos;
   Code[1+0] = GEN_LEGAL_EVASION;
   Code[1+1] = GEN_END;

   PosSEE = 2;
   Code[1+2] = GEN_TRANS;
   Code[1+3] = GEN_GOOD_CAPTURE;
   Code[1+4] = GEN_KILLER;
   Code[1+5] = GEN_QUIET;
   Code[1+6] = GEN_BAD_CAPTURE;
   Code[1+7] = GEN_END;

   -- quiescence search

   PosEvasionQS = 8;
   Code[1+8] = GEN_EVASION_QS;
   Code[1+9] = GEN_END;

   PosCheckQS = 10;
   Code[1+10] = GEN_CAPTURE_QS;
   Code[1+11] = GEN_CHECK_QS;
   Code[1+12] = GEN_END;

   PosCaptureQS = 13;
   Code[1+13] = GEN_CAPTURE_QS;
   Code[1+14] = GEN_END;

   pos = 15;

   --ASSERT(795, pos<CODE_SIZE);

end

-- sort_init()

function sort_init2( sort, board, attack, depth, height, trans_killer ) -- void
   --ASSERT(796, sort.depth~=nil);
   --ASSERT(797, board.sp~=nil);
   --ASSERT(798, attack~=nil);
   --ASSERT(799, depth_is_ok(depth));
   --ASSERT(800, height_is_ok(height));
   --ASSERT(801, trans_killer==MoveNone or move_is_ok(trans_killer));

   sort.board = board;
   sort.attack = attack;

   sort.depth = depth;
   sort.height = height;

   sort.trans_killer = trans_killer;
   sort.killer_1 = Killer[1+sort.height][1+0];
   sort.killer_2 = Killer[1+sort.height][1+1];

   if (ATTACK_IN_CHECK(sort.attack)) then

      gen_legal_evasions(sort.list,sort.board,sort.attack);
      note_moves(sort.list,sort.board,sort.height,sort.trans_killer);
      list_sort(sort.list);

      sort.gen = PosLegalEvasion + 1;
      sort.test = TEST_NONE;

   else  -- not in check

      sort.list.size = 0;
      sort.gen = PosSEE;

   end

   sort.pos = 0;
end

-- sort_next()

function sort_next( sort )  -- int

   local move = 0;   -- int
   local gen = 0;    -- int
   local nocont = false;
   local ifelse = false;

   --ASSERT(802, sort.pos~=nil);

   while (true) do

      while (sort.pos < sort.list.size) do

         nocont = true;

         -- next move

         move = sort.list.move[1+sort.pos];
         sort.value = 16384; -- default score
         sort.pos = sort.pos + 1;

         --ASSERT(803, move~=MoveNone);

         -- test

         ifelse = true;
         if (ifelse and (sort.test == TEST_NONE)) then
		    ifelse = false;
         end

         if (ifelse and (sort.test == TEST_TRANS_KILLER)) then

            if (nocont and not move_is_pseudo(move,sort.board)) then
              nocont = false;
            end
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_GOOD_CAPTURE)) then

            --ASSERT(804, move_is_tactical(move,sort.board));

            if (nocont and move == sort.trans_killer) then
              nocont = false;
            end

            if (nocont and not capture_is_good(move,sort.board)) then
              LIST_ADD(sort.bad,move);
              nocont = false;
            end

            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_BAD_CAPTURE)) then

            --ASSERT(805, move_is_tactical(move,sort.board));
            --ASSERT(806, not capture_is_good(move,sort.board));

            --ASSERT(807, move~=sort.trans_killer);
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_KILLER)) then

            if (nocont and move == sort.trans_killer) then
              nocont = false;
            end
            if (nocont and not quiet_is_pseudo(move,sort.board)) then
              nocont = false;
            end
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            --ASSERT(808, (not nocont) or (not move_is_tactical(move,sort.board)));

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_QUIET)) then

            --ASSERT(809, not move_is_tactical(move,sort.board));

            if (nocont and move == sort.trans_killer) then
              nocont = false;
            end
            if (nocont and move == sort.killer_1) then
              nocont = false;
            end
            if (nocont and move == sort.killer_2) then
              nocont = false;
            end
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            if (nocont) then
              sort.value = history_prob(move,sort.board);
            end

            ifelse = false;
         end

         if (ifelse) then

            --ASSERT(810, false);

            return MoveNone;
         end

         if (nocont) then

           --ASSERT(811, pseudo_is_legal(move,sort.board));
           return move;

         end -- otherwise continue

      end

      -- next stage

      gen = Code[1+sort.gen];
      sort.gen = sort.gen + 1;

      ifelse = true;

      if (ifelse and (gen == GEN_TRANS)) then

         LIST_CLEAR(sort.list);
         if (sort.trans_killer ~= MoveNone) then
           LIST_ADD(sort.list,sort.trans_killer);
         end

         sort.test = TEST_TRANS_KILLER;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_GOOD_CAPTURE)) then

         gen_captures(sort.list,sort.board);
         note_mvv_lva(sort.list,sort.board);
         list_sort(sort.list);

         LIST_CLEAR(sort.bad);

         sort.test = TEST_GOOD_CAPTURE;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_BAD_CAPTURE)) then

         list_copy(sort.list,sort.bad);

         sort.test = TEST_BAD_CAPTURE;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_KILLER)) then

         LIST_CLEAR(sort.list);
         if (sort.killer_1 ~= MoveNone) then
           LIST_ADD(sort.list,sort.killer_1);
         end
         if (sort.killer_2 ~= MoveNone) then
           LIST_ADD(sort.list,sort.killer_2);
         end

         sort.test = TEST_KILLER;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_QUIET)) then

         gen_quiet_moves(sort.list,sort.board);
         note_quiet_moves(sort.list,sort.board);
         list_sort(sort.list);

         sort.test = TEST_QUIET;

         ifelse = false;
      end

      if (ifelse) then

         --ASSERT(812, gen==GEN_END);

         return MoveNone;
      end

      sort.pos = 0;

   end

   return MoveNone;
end

-- sort_init_qs()

function sort_init_qs( sort, board, attack, check )  -- bool

   --ASSERT(813, sort.pos~=nil);
   --ASSERT(814, board.sp~=nil);
   --ASSERT(815, attack~=nil);
   --ASSERT(816, check==true or check==false);

   sort.board = board;
   sort.attack = attack;

   if (ATTACK_IN_CHECK(sort.attack)) then
      sort.gen = PosEvasionQS;
   else
    if (check) then
      sort.gen = PosCheckQS;
    else
      sort.gen = PosCaptureQS;
    end
   end

   LIST_CLEAR(sort.list);
   sort.pos = 0;

end

-- sort_next_qs()

function sort_next_qs( sort )  -- int

   local move = 0;   -- int
   local gen = 0;    -- int
   local nocont = false;
   local ifelse = false;

   --ASSERT(817, sort.pos~=nil);

   while (true) do

      while (sort.pos < sort.list.size) do

         nocont = true;

         -- next move

         move = sort.list.move[1+sort.pos];
         sort.pos = sort.pos + 1;

         --ASSERT(818, move~=MoveNone);

         -- test

         ifelse = true;

         if (ifelse and (sort.test == TEST_LEGAL)) then

            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_CAPTURE_QS)) then

            --ASSERT(819, move_is_tactical(move,sort.board));

            if (nocont and not capture_is_good(move,sort.board)) then
              nocont = false;
            end
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse and (sort.test == TEST_CHECK_QS)) then

            --ASSERT(820, not move_is_tactical(move,sort.board));
            --ASSERT(821, move_is_check(move,sort.board));

            if (nocont and see_move(move,sort.board) < 0) then
              nocont = false;
            end
            if (nocont and not pseudo_is_legal(move,sort.board)) then
              nocont = false;
            end

            ifelse = false;
         end

         if (ifelse) then

            --ASSERT(822, false);
            return MoveNone;

         end

         if (nocont) then

           --ASSERT(823, pseudo_is_legal(move,sort.board));
           return move;

         end

      end

      -- next stage

      gen = Code[1+sort.gen];
      sort.gen = sort.gen + 1;

      ifelse = true;

      if (ifelse and (gen == GEN_EVASION_QS)) then

         gen_pseudo_evasions(sort.list,sort.board,sort.attack);
         note_moves_simple(sort.list,sort.board);
         list_sort(sort.list);

         sort.test = TEST_LEGAL;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_CAPTURE_QS)) then

         gen_captures(sort.list,sort.board);
         note_mvv_lva(sort.list,sort.board);
         list_sort(sort.list);

         sort.test = TEST_CAPTURE_QS;

         ifelse = false;
      end

      if (ifelse and (gen == GEN_CHECK_QS)) then

         gen_quiet_checks(sort.list,sort.board);

         sort.test = TEST_CHECK_QS;

         ifelse = false;
      end

      if (ifelse) then

         --ASSERT(824, gen==GEN_END);

         return MoveNone;
      end

      sort.pos = 0;
   end

   --ASSERT(1824, false);
   return MoveNone;
end

-- good_move()

function good_move( move, board, depth, height )  -- int

   local index = 0;   -- int
   local i = 0;       -- int

   --ASSERT(825, move_is_ok(move));
   --ASSERT(826, board.sp~=nil);
   --ASSERT(827, depth_is_ok(depth));
   --ASSERT(828, height_is_ok(height));

   if (move_is_tactical(move,board)) then
     return;
   end

   -- killer

   if (Killer[1+height][1+0] ~= move) then
      Killer[1+height][1+1] = Killer[1+height][1+0];
      Killer[1+height][1+0] = move;
   end

   --ASSERT(829, Killer[1+height][1+0]==move);
   --ASSERT(830, Killer[1+height][1+1]~=move);

   -- history

   index = history_index(move,board);

   History[1+index] = History[1+index] + ( depth * depth );          -- HISTORY_INC()

   if (History[1+index] >= HistoryMax) then
      for i = 0, HistorySize-1, 1 do
         History[1+i] = (History[1+i] + 1) / 2;
      end
   end

end

-- history_good()

function history_good( move, board )  -- void

   local index = 0;   -- int

   --ASSERT(831, move_is_ok(move));
   --ASSERT(832, board.sp~=nil);

   if (move_is_tactical(move,board)) then
     return;
   end

   -- history

   index = history_index(move,board);

   HistHit[1+index] = HistHit[1+index] + 1;
   HistTot[1+index] = HistTot[1+index] + 1;

   if (HistTot[1+index] >= HistoryMax) then
      HistHit[1+index] = (HistHit[1+index] + 1) / 2;
      HistTot[1+index] = (HistTot[1+index] + 1) / 2;
   end

   --ASSERT(833, HistHit[1+index]<=HistTot[1+index]);
   --ASSERT(834, HistTot[1+index]<HistoryMax);
end

-- history_bad()

function history_bad( move, board )  -- void

   local index = 0;   -- int

   --ASSERT(835, move_is_ok(move));
   --ASSERT(836, board.sp~=nil);

   if (move_is_tactical(move,board)) then
     return;
   end

   -- history

   index = history_index(move,board);

   HistTot[1+index] = HistTot[1+index] + 1;

   if (HistTot[1+index] >= HistoryMax) then
      HistHit[1+index] = (HistHit[1+index] + 1) / 2;
      HistTot[1+index] = (HistTot[1+index] + 1) / 2;
   end

   --ASSERT(837, HistHit[1+index]<=HistTot[1+index]);
   --ASSERT(838, HistTot[1+index]<HistoryMax);

end

-- note_moves()

function note_moves( list, board, height,  trans_killer )  -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(839, list_is_ok(list));
   --ASSERT(840, board.sp~=nil);
   --ASSERT(841, height_is_ok(height));
   --ASSERT(842, trans_killer==MoveNone or move_is_ok(trans_killer));

   size = list.size;

   if (size >= 2) then
      for i = 0, size-1, 1 do
         move = list.move[1+i];
         list.value[1+i] = move_value(move,board,height,trans_killer);
      end
   end

end

-- note_captures()

function note_captures( list, board ) -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(843, list_is_ok(list));
   --ASSERT(844, board.sp~=nil);

   size = list.size;

   if (size >= 2) then
      for i = 0, size-1, 1 do
         move = list.move[1+i];
         list.value[1+i] = capture_value(move,board);
      end
   end

end

-- note_quiet_moves()

function note_quiet_moves( list, board ) -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(845, list_is_ok(list));
   --ASSERT(846, board.sp~=nil);

   size = list.size;

   if (size >= 2) then
      for i = 0, size-1, 1 do
         move = list.move[1+i];
         list.value[1+i] = quiet_move_value(move,board);
      end
   end

end

-- note_moves_simple()

function note_moves_simple( list, board ) -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(847, list_is_ok(list));
   --ASSERT(848, board.sp~=nil);

   size = list.size;

   if (size >= 2) then
      for i = 0, size-1, 1 do
         move = list.move[1+i];
         list.value[1+i] = move_value_simple(move,board);
      end
   end

end

-- note_mvv_lva()

function note_mvv_lva( list, board ) -- void

   local size = 0;   -- int
   local i = 0;      -- int
   local move = 0;   -- int

   --ASSERT(849, list_is_ok(list));
   --ASSERT(850, board.sp~=nil);

   size = list.size;

   if (size >= 2) then
      for i = 0, size-1, 1 do
         move = list.move[1+i];
         list.value[1+i] = mvv_lva(move,board);
      end
   end

end

-- move_value()

function move_value( move, board, height, trans_killer )  -- int

   local value = 0;   -- int

   --ASSERT(851, move_is_ok(move));
   --ASSERT(852, board.sp~=nil);
   --ASSERT(853, height_is_ok(height));
   --ASSERT(854, trans_killer==MoveNone or move_is_ok(trans_killer));

   if (move == trans_killer) then    -- transposition table killer
      value = TransScore;
   else
    if (move_is_tactical(move,board)) then   -- capture or promote
      value = capture_value(move,board);
    else
     if (move == Killer[1+height][1+0]) then   -- killer 1
       value = KillerScore;
     else
      if (move == Killer[1+height][1+1]) then  -- killer 2
       value = KillerScore - 1;
      else      -- quiet move
       value = quiet_move_value(move,board);
      end
     end
    end
   end

   return value;

end

-- capture_value()

function capture_value( move, board )  -- int

   local value = 0;   -- int

   --ASSERT(855, move_is_ok(move));
   --ASSERT(856, board.sp~=nil);

   --ASSERT(857, move_is_tactical(move,board));

   value = mvv_lva(move,board);

   if (capture_is_good(move,board)) then
      value = value + GoodScore;
   else
      value = value + BadScore;
   end

   --ASSERT(858, value>=-30000 and value<=30000);

   return value;

end

-- quiet_move_value()

function quiet_move_value( move, board )  -- int

   local value = 0;   -- int
   local index = 0;   -- int

   --ASSERT(859, move_is_ok(move));
   --ASSERT(860, board.sp~=nil);

   --ASSERT(861, not move_is_tactical(move,board));

   index = history_index(move,board);

   value = HistoryScore + History[1+index];
   --ASSERT(862, value>=HistoryScore and value<=KillerScore-4);

   return value;

end

-- move_value_simple()

function move_value_simple( move, board )  -- int

   local value = 0;   -- int

   --ASSERT(863, move_is_ok(move));
   --ASSERT(864, board.sp~=nil);

   value = HistoryScore;
   if (move_is_tactical(move,board)) then
     value = mvv_lva(move,board);
   end

   return value;

end

-- history_prob()

function history_prob( move, board )  -- int

   local value = 0;   -- int
   local index = 0;   -- int

   --ASSERT(865, move_is_ok(move));
   --ASSERT(866, board.sp~=nil);

   --ASSERT(867, not move_is_tactical(move,board));

   index = history_index(move,board);

   --ASSERT(868, HistHit[1+index]<=HistTot[1+index]);
   --ASSERT(869, HistTot[1+index]<HistoryMax);

   value = (HistHit[1+index] * 16384) / HistTot[1+index];
   --ASSERT(870, value>=0 and value<=16384);

   return value;

end

-- capture_is_good()

function capture_is_good( move, board )  -- bool

   local piece = 0;     -- int
   local capture = 0;   -- int

   --ASSERT(871, move_is_ok(move));
   --ASSERT(872, board.sp~=nil);

   --ASSERT(873, move_is_tactical(move,board));

   -- special cases

   if (MOVE_IS_EN_PASSANT(move)) then
     return true;
   end
   if (move_is_under_promote(move)) then
     return false; -- REMOVE ME?
   end

   -- captures and queen promotes

   capture = board.square[1+MOVE_TO(move)];

   if (capture ~= Empty) then

      -- capture

      --ASSERT(874, move_is_capture(move,board));

      if (MOVE_IS_PROMOTE(move)) then
        return true; -- promote-capture
      end

      piece = board.square[1+MOVE_FROM(move)];
      if (ValuePiece[1+capture] >= ValuePiece[1+piece]) then
        return true;
      end
   end

   return (see_move(move,board) >= 0);

end

-- mvv_lva()

function mvv_lva( move, board )  -- int

   local piece = 0;     -- int
   local capture = 0;   -- int
   local promote = 0;   -- int
   local value = 0;     -- int

   --ASSERT(875, move_is_ok(move));
   --ASSERT(876, board.sp~=nil);

   --ASSERT(877, move_is_tactical(move,board));

   if (MOVE_IS_EN_PASSANT(move)) then   -- en-passant capture

      value = 5; -- PxP

   else

    capture = board.square[1+MOVE_TO(move)];

    if (capture~= Empty) then   -- normal capture

      piece = board.square[1+MOVE_FROM(move)];

      value = (PieceOrder[1+capture] * 6) - PieceOrder[1+piece] + 5;
      --ASSERT(878, value>=0 and value<30);

    else   -- promote

      --ASSERT(879, MOVE_IS_PROMOTE(move));

      promote = move_promote(move);

      value = PieceOrder[1+promote] - 5;
      --ASSERT(880, value>=-4 and value<0);
    end
   end

   --ASSERT(881, value>=-4 and value<30);

   return value;

end

-- history_index()

function history_index( move, board )  -- int

   local index = 0;   -- int

   --ASSERT(882, move_is_ok(move));
   --ASSERT(883, board.sp~=nil);

   --ASSERT(884, not move_is_tactical(move,board));

   index = (PieceTo12[1+board.square[1+MOVE_FROM(move)]] * 64) + SquareTo64[1+MOVE_TO(move)];

   --ASSERT(885, index>=0 and index<HistorySize);

   return index;

end

-- end of sort.cpp


-- square.cpp

-- functions

-- square_init()

function square_init() -- void

   local sq = 0;   -- int

   -- SquareTo64[]

   for sq = 0, SquareNb-1, 1 do
     SquareTo64[1+sq] = -1;
   end

   for sq = 0, 63, 1 do
      SquareTo64[1+SquareFrom64[1+sq]] = sq;
   end

   -- SquareIsPromote[]

   for sq = 0, SquareNb-1, 1 do
      SquareIsPromote[1+sq] = SQUARE_IS_OK(sq)  and  (SQUARE_RANK(sq) == Rank1  or  SQUARE_RANK(sq) == Rank8);
   end

end

-- file_from_char()

function file_from_char(c)  -- int

   --ASSERT(886, c>="a" and c<="h");

   return FileA + (string.byte(c,1) - string.byte("a",1));
end

-- rank_from_char()

function rank_from_char(c)  -- int

   --ASSERT(887, c>="1" and c<="8");

   return Rank1 + (string.byte(c,1) - string.byte("1",1));
end

-- file_to_char()

function file_to_char( file )  -- char

   --ASSERT(888, file>=FileA and file<=FileH);

   return string.format("%c", string.byte("a",1) + (file - FileA));
end

-- rank_to_char()

function rank_to_char( rank )  -- int

   --ASSERT(889, rank>=Rank1 and rank<=Rank8);

   return string.format("%c", string.byte("1",1) + (rank - Rank1));

end

-- square_to_string()

function square_to_string( square, str1 )  -- bool

   --ASSERT(890, SQUARE_IS_OK(square));
   --ASSERT(891, str1.v~=nil);

   str1.v = "";
   str1.v = str1.v .. file_to_char(SQUARE_FILE(square));
   str1.v = str1.v .. rank_to_char(SQUARE_RANK(square));

   return true;
end

-- square_from_string()

function square_from_string( str1 )  -- int

   local file = 0;   -- int
   local rank = 0;   -- int
   local c1 = " ";   -- char
   local c2 = " ";   -- char

   --ASSERT(893, str1.v~=nil);

   c1 = string.sub( str1.v, 1, 1 );
   if (c1 < "a"  or  c1 > "h") then
     return SquareNone;
   end
   c2 = string.sub( str1.v, 2, 2 );
   if (c2 < "1"  or  c2 > "8") then
     return SquareNone;
   end

   file = file_from_char(c1);
   rank = rank_from_char(c2);

   return SQUARE_MAKE(file,rank);
end

-- end of square.cpp


-- trans.cpp

-- functions

-- trans_is_ok()

function trans_is_ok( trans )  -- bool

   local date = 0;   -- int

   if ((trans.table == nil) or (trans.size == 0)) then
     return false;
   end

   if ((trans.mask == 0)  or  (trans.mask >= trans.size)) then
     return false;
   end

   if (trans.date >= DateSize) then
     return false;
   end

   for date = 0, DateSize-1, 1 do
      if (trans.age[1+date] ~= trans_age(trans,date)) then
        return false;
      end
   end

   return true;

end


-- trans_alloc()

function trans_alloc( trans )

   trans.size = TransSize;
   trans.mask = trans.size - 1;   -- 2^x -1

   trans_clear(trans);

   --ASSERT(900, trans_is_ok(trans));
end


-- trans_clear()

function trans_clear( trans ) -- void

   local clear_entry = nil;     -- entry_t *

   local index = 0;                   -- uint32

   --ASSERT(902, trans.size~=nil);

   trans_set_date(trans,0);
   trans.table = {};            -- will define objects while searching

end


-- trans_cl_I()

function trans_cl_I( trans, index ) -- void

   local clear_entry = nil;     -- entry_t *

   trans.table[1+index] = entry_t();

   clear_entry = trans.table[1+index];

   clear_entry.lock = 0;
   clear_entry.move = MoveNone;
   clear_entry.depth = DepthNone;
   clear_entry.date = trans.date;
   clear_entry.move_depth = DepthNone;
   clear_entry.flags = 0;
   clear_entry.min_depth = DepthNone;
   clear_entry.max_depth = DepthNone;
   clear_entry.min_value = -ValueInf;
   clear_entry.max_value = ValueInf;

   --ASSERT(903, entry_is_ok(clear_entry));

end


-- trans_inc_date()

function trans_inc_date( trans )  -- void

   --ASSERT(904, trans.size~=nil);

   trans_set_date(trans,(trans.date+1)%DateSize);
end

-- trans_set_date()

function trans_set_date( trans, date )  -- void

   local date1 = 0;

   --ASSERT(905, trans.size~=nil);
   --ASSERT(906, date>=0 and date<DateSize);

   trans.date = date;

   for date1 = 0, DateSize-1, 1 do
      trans.age[1+date1] = trans_age(trans,date1);
   end

   trans.used = 0;
   trans.read_nb = 0;
   trans.read_hit = 0;
   trans.write_nb = 0;
   trans.write_hit = 0;
   trans.write_collision = 0;

end

-- trans_age()

function trans_age( trans, date )  -- int

   local age = 0;   -- int

   --ASSERT(907, trans.size~=nil);
   --ASSERT(908, date>=0 and date<DateSize);

   age = trans.date - date;
   if (age < 0) then
     age = age + DateSize;
   end

   --ASSERT(909, age>=0 and age<DateSize);

   return age;

end

-- trans_store()

function trans_store( trans, key, move, depth, Tset )  -- void

   local entry = nil;        -- entry_t *
   local best_entry = nil;   -- entry_t *
   local ei = 0;             -- int
   local i = 0;              -- int
   local score = 0;          -- int
   local best_score = 0;     -- int
   local nw_rc = false;

   --ASSERT(910, trans_is_ok(trans));
   --ASSERT(911, move>=0 and move<65536);
   --ASSERT(912, depth>=-127 and depth<=127);
   --ASSERT(913, Tset.trans_min_value>=-ValueInf and Tset.trans_min_value<=ValueInf);
   --ASSERT(914, Tset.trans_max_value>=-ValueInf and Tset.trans_max_value<=ValueInf);
   --ASSERT(915, Tset.trans_min_value<=Tset.trans_max_value);

   -- init

   trans.write_nb = trans.write_nb + 1;

   -- probe

   best_entry = nil;
   best_score = -32767;

   ei = trans_entry(trans,key);

   for i = 0, ClusterSize-1 , 1 do

      entry = trans.table[1+ei+i];

      if (entry ~= nil and entry.lock ~= nil) then

       if (entry.lock == KEY_LOCK(key)) then

         -- hash hit => update existing entry

         trans.write_hit = trans.write_hit + 1;
         if (entry.date ~= trans.date) then
           trans.used = trans.used + 1;
         end

         entry.date = trans.date;

         if (depth > entry.depth) then
           entry.depth = depth; -- for replacement scheme
         end

         if (move ~= MoveNone  and  depth >= entry.move_depth) then
            entry.move_depth = depth;
            entry.move = move;
         end

         if (Tset.trans_min_value > -ValueInf  and  depth >= entry.min_depth) then
            entry.min_depth = depth;
            entry.min_value = Tset.trans_min_value;
         end

         if (Tset.trans_max_value < ValueInf  and  depth >= entry.max_depth) then
            entry.max_depth = depth;
            entry.max_value = Tset.trans_max_value;
         end

         --ASSERT(916, entry_is_ok(entry));

         return;
       end

      else

        trans_cl_I( trans, ei+i );   -- create a new entry record
        nw_rc = true;

        entry = trans.table[1+ei+i];

      end

      -- evaluate replacement score

      score = (trans.age[1+entry.date] * 256) - entry.depth;
      --ASSERT(917, score>-32767);

      if (score > best_score) then
         best_entry = entry;
         best_score = score;
      end

      if(nw_rc) then
        break;
      end

   end

   -- "best" entry found

   entry = best_entry;
   --ASSERT(918, entry.lock~=nil);
   --ASSERT(919, entry.lock~=KEY_LOCK(key));

   if (entry.lock ~= 0) then     -- originally entry.date == trans.date
      trans.write_collision = trans.write_collision + 1;
   else
      trans.used = trans.used + 1;
   end

   -- store

   entry.lock = KEY_LOCK(key);
   entry.date = trans.date;

   entry.depth = depth;

   entry.move_depth = iif( move ~= MoveNone, depth, DepthNone );
   entry.move = move;

   entry.min_depth = iif(Tset.trans_min_value > -ValueInf, depth, DepthNone );
   entry.max_depth = iif(Tset.trans_max_value < ValueInf, depth, DepthNone );
   entry.min_value = Tset.trans_min_value;
   entry.max_value = Tset.trans_max_value;

   --ASSERT(921, entry_is_ok(entry));

end

-- trans_retrieve()

function trans_retrieve( trans, key, Ret )  -- bool

   local entry = nil;   -- entry_t *
   local ei = 0;        -- int
   local i = 0;         -- int

   --ASSERT(922, trans_is_ok(trans));

   -- init

   trans.read_nb = trans.read_nb + 1;

   -- probe

   ei = trans_entry(trans,key);

   for i = 0, ClusterSize-1 , 1 do

      entry = trans.table[1+ei+i];
	  
	  if (entry ~= nil and entry.lock ~= nil) then

       if (entry.lock == KEY_LOCK(key)) then

         -- found

         trans.read_hit = trans.read_hit + 1;
         if (entry.date ~= trans.date) then
           entry.date = trans.date;
         end

         Ret.trans_move = entry.move;

         Ret.trans_min_depth = entry.min_depth;
         Ret.trans_max_depth = entry.max_depth;
         Ret.trans_min_value = entry.min_value;
         Ret.trans_max_value = entry.max_value;

         return true;
	   end
	   
	  else
         return false;
      end
   end

   -- not found

   return false;
end

-- trans_stats()

function trans_stats( trans ) -- void

   local full = 0.0;       -- double
   local hit = 0.0;        -- double
   local collision = 0.0;  -- double
   local s = "";

   --ASSERT(928, trans_is_ok(trans));

   full = iif(trans.size>0, trans.used / trans.size, 0);
   hit = iif(trans.read_nb>0, trans.read_hit / trans.read_nb, 0);
   collision = iif(trans.write_nb>0, trans.write_collision / trans.write_nb, 0);

   s = s .. "\n" .. "hash trans info";
   s = s .." hashfull " .. string.format("%d",full*100.0) .. "%";
   s = s .." hits " .. string.format("%d",hit*100.0) .. "%";
   s = s .." collisions " .. string.format("%d",collision*100.0) .. "%";

   full = iif(Material.size>0, Material.used / Material.size, 0);
   hit = iif(Material.read_nb>0, Material.read_hit / Material.read_nb, 0);
   collision = iif(Material.write_nb>0, Material.write_collision / Material.write_nb, 0);

   s = s .. "\n" .. "hash material info";
   s = s .." hashfull " .. string.format("%d",full*100.0) .. "%";
   s = s .." hits " .. string.format("%d",hit*100.0) .. "%";
   s = s .." collisions " .. string.format("%d",collision*100.0) .. "%";

   full = iif(Pawn.size>0, Pawn.used / Pawn.size, 0);
   hit = iif(Pawn.read_nb>0, Pawn.read_hit /Pawn.read_nb, 0);
   collision = iif(Pawn.write_nb>0, Pawn.write_collision / Pawn.write_nb, 0);

   s = s .. "\n" .. "hash pawn info";
   s = s .." hashfull " .. string.format("%d",full*100.0) .. "%";
   s = s .." hits " .. string.format("%d",hit*100.0) .. "%";
   s = s .." collisions " .. string.format("%d",collision*100.0) .. "%";
   s = s .. "\n";

   send( s );
end

-- trans_entry()

function trans_entry( trans, key ) -- int - index to entry_t

   local index = 0;  -- uint32

   --ASSERT(929, trans_is_ok(trans));

   if (UseModulo) then
      index = KEY_INDEX(key) % (trans.mask + 1);
   else
      index =  bit.band( KEY_INDEX(key) , trans.mask);
   end

   --ASSERT(930, index<=trans.mask);

   return index;

end

-- entry_is_ok()

function entry_is_ok( entry )  -- bool

   if (entry.date ~= nil and entry.date >= DateSize) then
     return false;
   end

   if (entry.move == MoveNone  and  entry.move_depth ~= DepthNone) then
     return false;
   end
   if (entry.move ~= MoveNone  and  entry.move_depth == DepthNone) then
     return false;
   end

   if (entry.min_value == -ValueInf  and  entry.min_depth ~= DepthNone) then
     return false;
   end
   if (entry.min_value >  -ValueInf  and  entry.min_depth == DepthNone) then
     return false;
   end

   if (entry.max_value == ValueInf  and  entry.max_depth ~= DepthNone) then
     return false;
   end
   if (entry.max_value <  ValueInf  and  entry.max_depth == DepthNone) then
     return false;
   end

   return true;
end

-- end of trans.cpp



-- util.cpp

-- my_timer_reset()

function my_timer_reset( timer )

   --ASSERT(944, timer.start_real~=nil);

   timer.start_real = 0.0;
   timer.elapsed_real = 0.0;
   timer.running = false;

end

-- my_timer_start()

function my_timer_start( timer )

   --ASSERT(945, timer.start_real~=nil);

   --ASSERT(946, timer.start_real==0.0);
   --ASSERT(948, not timer.running);

   timer.running = true;
   timer.start_real = os.clock();

end

-- my_timer_stop()

function my_timer_stop( timer )

   --ASSERT(949, timer.start_real~=nil);

   --ASSERT(950, timer.running);

   timer.elapsed_real = timer.elapsed_real + os.clock() - timer.start_real;
   timer.start_real = 0.0;
   timer.running = false;

end

-- my_timer_elapsed_real()

function my_timer_elapsed_real( timer ) -- int

   --ASSERT(951, timer.start_real~=nil);

   if (timer.running) then
     timer.elapsed_real = (os.clock() - timer.start_real);
   end

   return timer.elapsed_real;
end


-- end of util.cpp



-- value.cpp

-- functions

-- value_init()

function value_init()

   local piece = 0;   -- int

   -- ValuePiece[]

   for piece = 0, 1, 1 do
    ValuePiece[1+piece] = -1;
   end

   ValuePiece[1+Empty] = 0; -- needed?
   ValuePiece[1+Edge]  = 0; -- needed?

   ValuePiece[1+WP] = ValuePawn;
   ValuePiece[1+WN] = ValueKnight;
   ValuePiece[1+WB] = ValueBishop;
   ValuePiece[1+WR] = ValueRook;
   ValuePiece[1+WQ] = ValueQueen;
   ValuePiece[1+WK] = ValueKing;

   ValuePiece[1+BP] = ValuePawn;
   ValuePiece[1+BN] = ValueKnight;
   ValuePiece[1+BB] = ValueBishop;
   ValuePiece[1+BR] = ValueRook;
   ValuePiece[1+BQ] = ValueQueen;
   ValuePiece[1+BK] = ValueKing;
end

-- value_is_ok()

function value_is_ok( value )  -- bool

   if (value < -ValueInf  or  value > ValueInf) then
     return false;
   end

   return true;
end

-- range_is_ok()

function range_is_ok( min, max )  -- bool

   if (not value_is_ok(min)) then
     return false;
   end
   if (not value_is_ok(max)) then
     return false;
   end

   if (min >= max) then
     return false; -- alpha-beta-like ranges cannot be nil
   end

   return true;
end

-- value_is_mate()

function value_is_mate( value )  -- bool

   --ASSERT(954, value_is_ok(value));

   if (value < -ValueEvalInf  or  value > ValueEvalInf) then
     return true;
   end

   return false;
end

-- value_to_trans()

function value_to_trans( value, height )  -- int

   --ASSERT(955, value_is_ok(value));
   --ASSERT(956, height_is_ok(height));

   if (value < -ValueEvalInf) then
      value = value - height;
   else
    if (value > ValueEvalInf) then
      value = value + height;
    end
   end

   --ASSERT(957, value_is_ok(value));

   return value;

end

-- value_from_trans()

function value_from_trans( value, height )  -- int

   --ASSERT(958, value_is_ok(value));
   --ASSERT(959, height_is_ok(height));

   if (value < -ValueEvalInf) then
      value = value + height;
   else
    if (value > ValueEvalInf) then
      value = value - height;
    end
   end

   --ASSERT(960, value_is_ok(value));

   return value;

end

-- value_to_mate()

function value_to_mate( value )  -- int

   local dist = 0;   -- int

   --ASSERT(961, value_is_ok(value));

   if (value < -ValueEvalInf) then

      dist = (ValueMate + value) / 2;
      --ASSERT(962, dist>0);

      return -dist;

   else
    if (value > ValueEvalInf) then

      dist = (ValueMate - value + 1) / 2;
      --ASSERT(963, dist>0);

      return dist;
    end
   end

   return 0;
end

-- end of value.cpp



-- vector.cpp

-- functions

function vector_init() -- void

   local delta = 0;   -- int
   local x = 0;       -- int
   local y = 0;       -- int
   local dist = 0;    -- int
   local tmp = 0;     -- int

   -- Distance[]

   for delta = 0, DeltaNb-1, 1 do
     Distance[1+delta] = -1;
   end

   for y = -7, 7, 1 do

      for x = -7, 7, 1 do

         delta = y * 16 + x;
         --ASSERT(964, delta_is_ok(delta));

         dist = 0;

         tmp = x;
         if (tmp < 0) then
           tmp = -tmp;
         end
         if (tmp > dist) then
           dist = tmp;
         end

         tmp = y;
         if (tmp < 0) then
           tmp = -tmp;
         end
         if (tmp > dist) then
           dist = tmp;
         end

         Distance[1+DeltaOffset+delta] = dist;
      end
   end

end


-- delta_is_ok()

function delta_is_ok( delta )  -- bool

   if (delta < -119  or  delta > 119) then
     return false;
   end

   if ( bit.band(delta,0xF) == 8) then
     return false;     -- HACK: delta % 16 would be ill-defined for negative numbers
   end

   return true;
end


-- inc_is_ok()

function inc_is_ok( inc )  -- bool

   local dir = 0;   -- int

   for dir = 0, 7, 1 do
      if (KingInc[1+dir] == inc) then
        return true;
      end
   end

   return false;
end

-- end of vector.cpp


-- main.cpp

-- functions

-- main()

function main()

   -- init

   print( VERSION );

   option_init();

   square_init();
   piece_init();
   pawn_init_bit();
   value_init();
   vector_init();
   attack_init();
   move_do_init();

   random_init();
   hash_init();

   inits();
   setstartpos();

end

-- end of main.cpp

function ClearAll()    -- just clear all to be sure that nothing left

   search_clear();
   trans_clear(Trans);
   pawn_clear();
   material_clear();

end


-- randomized simplest opening case...
function randomopening( mvlist )   -- bool

   local tm = "";   -- string
   local l = 0;     -- int
   local i = 0;  -- int
   local j = 0;  -- int
   local mv_l = string.len( mvlist );  -- int
   local fmv = {};  -- move 1
   local m = "";    -- string
   
   if(mv_l<6) then

     tm = string.format( "%s", os.time() );
     l = string.len( tm );
     i = tonumber( string.sub( tm, l, l ) );

     if( mv_l == 0 ) then
       fmv = { "e2-e4", "d2-d4", "Ng1-f3", "Nb1-c3", "c2-c4", "g2-g3", "e2-e4", "c2-c3", "e2-e4", "d2-d4" };
     else
       fmv = { "e7-e5", "d7-d5", "Ng8-f6", "Nb8-c6", "c7-c5", "g7-g6", "c7-c5", "c7-c6", "e7-e6", "g7-g6" };
     end

     m = fmv[1+i];
     j = iif( string.len( m )>5, 1, 0 );
     bestmv = string.sub(m,1+j,2+j) .. string.sub(m,4+j,5+j);
     bestmv2 = m;

     return true;
   end

   return false;

end

-- AI vs AI game for testing...
function autogame()

  local pgn = "";
  local mc = 0;
  local mlist = "";

  print("Autogame!");

  printboard();

  while(true) do

    if( not randomopening( mlist ) ) then
      do_input( "go movetime 1");
      print("nodes: " .. SearchCurrent.node_nb);	-- to see performance
    end

    if(mc%2==0) then
      pgn = pgn..string.format( "%d",math.floor(mc/2)+1 )..".";
    end
    pgn = pgn..bestmv2.." ";

    mlist = mlist .. " " .. bestmv;

    do_input( "position moves" .. mlist );
    printboard();

    print(pgn);

    if( board_is_mate(  SearchInput.board ) ) then
      print("Checkmate! " .. iif( SearchInput.board.turn == White, "0-1", "1-0" ));
      break;
    end
    if( board_is_stalemate( SearchInput.board ) ) then
      print("Stalemate  1/2-1/2");
      break;
    end

    mc = mc + 1;
  end
end

-- .......................
--
-- here it starts...
--
-- .......................

  main();  -- initialize and set up starting position

--  do_input( "help" );
--  do_input( "position moves e2e4 e7e5 g1f3 g8f6 f1c4 f8c5 e1g1 e8g8" );
--  do_input( "position moves h2h3 a7a5 h3h4 a5a4 b2b4" );
--  do_input( "position moves b2b4 a7a5 a2a3 a5b4 c1b2 b4a3 b1c3 a3b2 h2h3 b2a1n h3h4 a1c2" );
--  do_input( "position moves b2b4 g7g6 b4b5 c7c5 b5c6" );
--  do_input( "position fen 7k/Q7/2P2K2/8/8/8/8/8 w - - 70 1" );
--  printboard();
--  do_input( "go");
--  do_input( "go depth 5");
--  do_input( "go movetime 5");


-- checkmate in 3 moves    1.Bf7+ Kxf7 2.Qxg6+ Ke7 3.Qe6#
--  ShowInfo = true;
--  do_input( "position fen r3kr2/pbq5/2pRB1p1/8/4QP2/2P3P1/PP6/2K5 w q - 0 36" );
--  printboard();
--  do_input( "go movetime 15");


  autogame();


