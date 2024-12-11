--
-- At first,
--  download and place Stockfish chess engine in this folder
--

-- ExeHandler64.dll usage in Lua

ffi = package.preload.ffi()

eh_dll = ffi.load("ExeHandler64.dll")

ffi.cdef([[
	char* char_100kb_buffer(int);
	int add_process(char*,char*);
	int put_stdin(int,char*);
	int get_stdout(int,char*);
	int get_status(int);
	int kill_process(int);
	int release_all();
	int assign_memory_i_n(int,int,int);
	int getfrom_memory_i_n(int,int);
	int add_process_i(int,int);
	int put_stdin_i(int,int);
	int get_stdout_i(int,int);
]])

------------------------------------------------------

function sleep (a) 
    local sec = tonumber(os.clock() + a)
    while (os.clock() < sec) do 
    end 
end

function assignmemory( chunk, str )
   local i = 0
   local L = string.len(str)
   while (i<L) do
     local b = string.byte( str, i+1 )
     eh_dll.assign_memory_i_n( chunk, i, b )
     i = i + 1
   end
end


function readfrommemory( chunk )
   local i = 0
   local c = 1
   local str = ""
   while (c>0) do
     c = eh_dll.getfrom_memory_i_n( chunk, i )
     str = str .. string.char( c )
     i = i + 1
   end
   return str
end

------------------------------------------------------
-- samples of usage


Prog = eh_dll.char_100kb_buffer(0)
Args = eh_dll.char_100kb_buffer(1)
--
-- Stockfish chess engine
--
assignmemory( 0, "stockfish-windows-x86-64.exe" .. string.char(0))
assignmemory( 1, "" .. string.char(0))

Id = eh_dll.add_process_i( 0, 1 )
print(Id)

sleep(1)

-- 10K buffer for data from Stockfish....
Stdout = eh_dll.char_100kb_buffer(4)
Stdin = eh_dll.char_100kb_buffer(5)

-- Prepare Stdin
assignmemory( 5, "go depth 4" .. string.char(10) .. string.char(0))

-- Go and search
wrote1 = eh_dll.put_stdin_i( Id, 5 )
print(wrote1)

sleep(1)

-- display results
T = 0
while(T<5) do
 read1 = eh_dll.get_stdout_i( Id, 4 )
 if (read1 > 0) then
   -- can analyse Stockfish results...
   print(read1)
   s = readfrommemory( 4 )
   print( s )
 end
 T = T + 1
 sleep(1)
end

print(eh_dll.get_status(Id))

eh_dll.kill_process(Id)

print( eh_dll.get_status(Id) )

eh_dll.release_all()

print("Ok")


-----------------------------------------------------
-- Output:
-- 
-- 11932
-- 11
-- 726
-- Stockfish 17 by the Stockfish developers (see AUTHORS file)
-- info string Available processors: 0-3
-- info string Using 1 thread
-- info string NNUE evaluation using nn-1111cefa1111.nnue (133MiB, (22528, 3072, 15, 32, 1))
-- info string NNUE evaluation using nn-37f18f62d772.nnue (6MiB, (22528, 128, 15, 32, 1))
-- info depth 1 seldepth 2 multipv 1 score cp 13 nodes 20 nps 10000 hashfull 0 tbhits 0 time 2 pv e2e4
-- info depth 2 seldepth 2 multipv 1 score cp 14 nodes 48 nps 24000 hashfull 0 tbhits 0 time 2 pv c2c3
-- info depth 3 seldepth 2 multipv 1 score cp 22 nodes 76 nps 38000 hashfull 0 tbhits 0 time 2 pv e2e4
-- info depth 4 seldepth 2 multipv 1 score cp 22 nodes 97 nps 48500 hashfull 0 tbhits 0 time 2 pv e2e4
-- bestmove e2e4
-- 
-- 3
-- 0
-- Ok
-- 