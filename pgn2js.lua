----------------------------------------------
--
-- reads .pgn file and creates .js short version
--
--   as param: set fname to .pgn filename
--

-- this loads and executes other .lua file
function dofile (filename)
  local f = assert(loadfile(filename))
  return f()
end
dofile( "c0_chess_subroutine.lua" );	-- chess logic

local CR =  string.char(13); -- string.char(10)


-------- processes a .pgn file
function encodefile( f )

local fz = string.gsub( f, ".pgn", "" );

local i = assert(io.open(f, "r"));
local o = assert(io.open(fz .. ".js", "w"));
local block = 0;
local S = "";
local gm = 0;
local Wout = "";
local sitewas = nil;
local datewas = nil;

o:write("var pgn_" .. fz .. " = {");
o:write("event:");

local wasEv = false;

while true do
  local l = i:read();

  
  if (l==nil) or string.find(string.upper(l),"EVENT ")~=nil then
    if block == 1 then
		block = 0

		c0_LuaChess.c0_fischer = false;
		c0_LuaChess.c0_start_FEN = "";
		c0_LuaChess.c0_side =1					-- This side is white.   For black set -1
		c0_LuaChess.c0_set_start_position("")		    -- Set the initial position...
		c0_PGN_short = true; 
		c0_PG_sh = "";
		
		local mlist = c0_LuaChess.c0_get_moves_from_PGN(S);

				
		local k = 1;
		local ks = "";
		local Z = c0_LuaChess.c0_PGN_header;
		Wout = "";
		local dtwas = false;

		
		while string.len(Z)>0 do
			
			k = 1;
			while true do
				local CC = string.sub(Z,k,k);
				if(CC==string.char(13) or CC==string.char(10)) then
					break
				end
				k = k + 1;
			end
			
			if k>1 then
				ks = string.sub(Z,1,k-1);
			end
			
			Z = string.sub(Z,k+1);
			if k>1 then
				
				while string.len(ks)>0 and string.byte(ks,1)<=32 do
					ks = string.sub(ks,2);
				end
				
				local Q = ks;

				local Qa = string.find(Q,'"');
				if Qa~=nil then
					Q = string.sub(Q,Qa+1);
					Qa = string.find(Q,'"');
					if Qa~=nil then
						Q = string.sub(Q,1,Qa-1);
					end
				end
				Q = string.gsub( Q, "'", "" );
				Q = string.gsub( Q, "&", " and " );

				if string.upper(string.sub(ks,1,6))=="EVENT " then
					if wasEv==false  then
						wasEv = true;
						o:write('"' .. Q .. '"' .. ",");
						o:write("games:["..CR);
						
					end
					Wout = Wout .. '"';
					Fischer = false;
					Fen = "";
				end
				
				if string.upper(string.sub(ks,1,6))=="WHITE " then
					Wout = Wout .. "[W_".. Q.."]";
				end
				if string.upper(string.sub(ks,1,6))=="BLACK " then
					Wout = Wout .. "[B_".. Q.."]";
				end
				
				if string.upper(string.sub(ks,1,9))=="WHITEELO " then
					Wout = Wout .. "[w_".. Q.."]";
				end
				if string.upper(string.sub(ks,1,9))=="BLACKELO " then
					Wout = Wout .. "[b_".. Q.."]";
				end
				
				if string.upper(string.sub(ks,1,5))=="SITE " then
					--Wout = Wout .. "[s_".. Q.."]";
					sitewas = Q;
				end	
				if string.upper(string.sub(ks,1,4))=="FEN " then
					Wout = Wout .. "[F_".. Q.."]";
					Fen = Q;
				end	
				if string.upper(string.sub(ks,1,6))=="SETUP " then
					Wout = Wout .. "[S_".. Q.."]";
					Fischer = true;
				end					
				if string.upper(string.sub(ks,1,6))=="ROUND " then
					Wout = Wout .. "[R_".. Q.."]";
				end
				if dtwas==false and string.upper(string.sub(ks,1,5))=="DATE " then
					Wout = Wout .. "[D_".. Q.."]";
					dtwas = true;
					if datewas== nil then
						datewas = Q;
					end
				end
				if dtwas==false and string.upper(string.sub(ks,1,10))=="EVENTDATE " then
					Wout = Wout .. "[D_".. Q.."]";
					dtwas = true;
					if datewas== nil then
						datewas = Q;
					end
				end
				
				if string.upper(string.sub(ks,1,4))=="ECO " then
					Wout = Wout .. "[C_".. Q.."]";
				end
				
				if string.upper(string.sub(ks,1,7))=="RESULT " then
					local Rz=Q;
					if string.find(Q,"2")~=nil or string.find(Q,"5")~=nil then
						Rz="0.5";
					end
					Wout = Wout .. "[Z_".. Rz.."]";
				end
			end
			
		end
		
		local m4 = c0_LuaChess.c0_PG_sh;
		Wout = Wout .. m4;
		if c0_LuaChess.c0_errflag then
			Wout = Wout .. "[ERROR]";
		end
		
	-- for debug purposes, slow
	if true then
		c0_LuaChess.c0_set_FEN (c0_LuaChess.c0_start_FEN)
		c0_LuaChess.c0_set_start_position("")		    -- Set the initial position...
				
		c0_LuaChess.c0_short2list();
		
		local m2 = c0_LuaChess.c0_moveslist;
		c0_LuaChess.c0_PG_sh = "";

		if mlist~=m2 then
			c0_LuaChess.printout ("pgn:" .. S);
			c0_LuaChess.printout ("L:" .. mlist);
			c0_LuaChess.printout ("S:" .. m4);
			c0_LuaChess.printout ("R:" .. m2);
			break
		end
	end
		Wout = Wout .. '",' .. CR;
		
		gm = gm + 1;
		if(gm % 10 == 0) then
			print(gm);
		end
		
		o:write( Wout );
		
		S = "";
	end
	
	block = 1;

  end
  
  if(l==nil) then
    print(gm);
	break;
  end
  
  if block == 1 then
	if(string.sub( string.upper(l),0,9 )~="[VARIANT ") then
		S = S .. " " .. l;
	end
  end
  
end

o:write('"');
if datewas~=nil then
	o:write(datewas);
end
o:write('"],');

if(sitewas~=nil) then
	o:write('site:"'..sitewas .. '",');
end
					
o:write('count:'.. string.format("%s",gm) ..CR);
o:write("};"..CR);

i:close();
o:close();


end


fname = "tourn.pgn"

print(fname);
encodefile(fname);




