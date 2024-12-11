This is a small sample of Lua based chess to run from command line.

1. GarboChess.bat - good port of chess engine to Lua
 (ported from javascript)

2. fruit21chess.bat - good port of Fruit chess engine to Lua
 (ported from C++)

3. EmulatedOliThink.bat - kind of scientific port of a 64bit chess engine.
  NOT a useful Lua chess AI. Anyway, interesting to see checkmate at the end:)

4. c0_chess.bat - a lua library for chess

5. sargon.bat - Sargon assembler code of 80s ported to lua
   history at wikispaces chessprogramming about Dan Spracklen
   Just fast and simply positional. Not strong, improvable.

6. LuaJester.bat - Very good chess program for 32-bits, and fast. Almost best what lua can perform.

7. OwlChess.bat - a port of an old '92-95 Owl Chess program
 in Borland Turbo C (from javascript port). Good and well documented.
 It was written when no 64 bits seemed useful. :)
 This version sometimes crashes on LuaJIT.

Other:
---------

1. polybase.bat - a polyglot opening book reader sample on
	book_small.bin and book_tiny.bin

2. abkbase.bat - an Arena book reader sample

3. pgn2js.bat - prepares pgn file to .js, see samples at
	https://gitlab.com/chessforeva/pgn2web

Win64 folder:
------------------------------------ (updated dec.2024)

1. chesslib.bat -  a sample of u64chesslib.dll library usage in Lua
                    It does most of chess logic at C-level. Intended for python, works on Lua too.

2. exehandler.lua - a sample of Stockfish usage from Lua - run in background, go search, read bestmove, release
                      (requires executable of chess engine, works also with LuaJIT)

Also lua to loadfile:
---------------------
i64.lua - emulated 64bit variables to get working (1<<63)

noBitOp.lua -  can be used instead of BitOp (but slower)

c0_chess_subroutine.lua - chess logic, not a fastest code


