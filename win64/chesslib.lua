
-- u64chesslib.dll usage in Lua

ffi = package.preload.ffi()

chesslib = ffi.load("u64chesslib.dll")

ffi.cdef([[
	void setstartpos();
	char* sboard();
	char* uniq();
	void setasuniq(char*);
	char* getfen();
	void setfen(char*);
	int movegen();
	char* legalmoves();
	int ucimove(char*);
	int parseucimoves(char*);
	void undomove();
	char* parsepgn(char*);
	bool ischeck();
	bool ischeckmate();
	int sidetomove();
	int swaptomove();
	//unsigned long long polyglotkey();
	char* spolyglotkey();
	int i_movegen(int);
	void i_domove(int);
	char* i_moveinfo(int);
	void i_skipmove(int);
	int piecescount();
	int whitecount();
	int blackcount();
	int materialdiff();
	bool seemslegitpos();
]])

------------------------------------------------------
-- samples of usage

chesslib.setstartpos()
print( ffi.string( chesslib.sboard() ) )


print("1.Starting position....")
chesslib.setstartpos()

-- display chess board to console
print( ffi.string( chesslib.sboard() ) )
print( ffi.string( chesslib.uniq() ) )
print( ffi.string( chesslib.getfen() ) )

print( ffi.string( chesslib.spolyglotkey() ) )
print( chesslib.piecescount() )
print( chesslib.whitecount() )
print( chesslib.blackcount() )
-- this is kinda indicator of material, nothing precise
print( chesslib.materialdiff() )


now_tomove = chesslib.swaptomove()
-- now opponent should move from same position (nullmove)
-- swap back
chesslib.swaptomove()

if( chesslib.sidetomove() == 0) then
  print("white to move")
else  
  print("black to move")
end


chesslib.movegen()
print( ffi.string( chesslib.legalmoves() ) )

print("2.Moving e4 ......")
print( chesslib.ucimove( ffi.new("char[10]","e2e4") ) )

print( ffi.string( chesslib.sboard() ) )
print( ffi.string( chesslib.getfen() ) )
-- get 70 bytes unique string as a key for this position
savepos = ffi.string( chesslib.uniq() )

print("3.Moving back....")
chesslib.undomove()
print( ffi.string( chesslib.getfen() ) )

chesslib.setasuniq( ffi.new("char[72]", savepos ) )
print( ffi.string( chesslib.sboard() ) )

u2 = ffi.new("char[99]", "e7e5 g1f3 d7d6" )
print( chesslib.parseucimoves( u2 ) )
print( ffi.string( chesslib.sboard() ) )

-- Try to set strange chess position
-- Validator when generating chess positions
print( chesslib.seemslegitpos() )
chesslib.setfen( ffi.new("char[80]", "PPPPPPPP w") )
print( chesslib.seemslegitpos() )


------------------------------------------------------
print("4.Iterations. Solve puzzle....")

-- Functions i_movegen, i_domove, undomove are iterable in depth.
-- ucimove, movegen, legalmoves are slower. Do not use them in for-loops.
-- Anyway, write it in C if really need performance.

print("Solve checkmate in 2 moves, the right move is 1.Rd8 Kd3 2.Nc5#")

chesslib.setfen( ffi.new("char[80]", "7R/1B1N4/8/3r4/1K2k3/8/5Q2/8 w") )
print( chesslib.piecescount() )
print( chesslib.materialdiff() )

print( ffi.string( chesslib.sboard() ) )

-- depth 0 white 1. move
i0 = 0
i0_to = chesslib.i_movegen(0)

while(i0<i0_to) do

  chesslib.i_domove(0)

  can_escape = true

  -- depth 1 black 1... move
  i1 = 0
  i1_to = chesslib.i_movegen(1)
  
  while(i1<i1_to) do
    chesslib.i_domove(1)

    -- depth 2 white 2. move
    yee = false
    -- if no moves then stalemate
	
    i2 = 0
    i2_to = chesslib.i_movegen(2)
    while(i2<i2_to) do
      chesslib.i_domove(2)

      if chesslib.ischeckmate() then
        -- i0,i1,i2 represent moves
        yee = true
      end

      chesslib.undomove()
      if(yee) then
        break
      end
	  
	  i2 = i2 + 1
    end
	
    chesslib.undomove()

    can_escape = not yee
    if can_escape then
      break
    end
	
	i1 = i1 + 1
	
  end

  chesslib.undomove()

  if(not can_escape) then

    chesslib.movegen()
    mv = ffi.string( chesslib.legalmoves() ).."  "
    while i0>0 do
       mv = string.sub( mv, string.find( mv, " ", 1 )+1 )
	   i0 = i0 - 1
    end
	mv = string.sub( mv, 1, string.find( mv, " " ) )
    
    print("Lua says")
    print( mv )
    break
  end	

  i0 = i0 + 1
end

------------------------------------------------------
print("5.Move info and skips....")

-- Looking for move that checkmates
-- goes this move and prints position

chesslib.setstartpos()

u2 = ffi.new("char[99]", "1.g4 e5 2.f3" )

chesslib.parsepgn( u2 )
-- depth 0 white 1. move

i0 = 0
i0_to = chesslib.i_movegen(0)

while(i0<i0_to) do

  m = ffi.string( chesslib.i_moveinfo(0) )

  --
  -- m[1]=piece
  -- m[2],m[3]=fromsquare "e2"
  -- m[4]=goes '-' or captures 'x'
  -- m[5],m[6]=tosquare "e4"
  -- m[7]=promoted piece
  -- m[8]=check flag '+'
  -- m[9]=checkmate flag '#'
  -- m[10]=piece captured
  -- m[11]=castling identifier
  --

  if(string.sub(m,9,9)=="#") then
    print(m)
    chesslib.i_domove(0)
    print( ffi.string( chesslib.sboard() ) )
    chesslib.undomove()

  else
    chesslib.i_skipmove(0)

  end

  i0 = i0 + 1
end

print("Ok")


