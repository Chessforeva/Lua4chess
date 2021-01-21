-- Lua (www.lua.org) for chess logic with samples
-- Board in variables, moves, FEN & PGN functions
-- A ready code for free usage in any type of project
-- no clock, no chess engine 
-- http://chessforeva.blogspot.com

--

-- this loads and executes other .lua file
function dofile (filename)
  local f = assert(loadfile(filename))
  return f()
end
dofile( "c0_chess_subroutine.lua" );	-- chess logic


-- Call samples...
c0_LuaChess.a_SAMPLES ()
