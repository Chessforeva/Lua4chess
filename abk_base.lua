-- Lua (www.lua.org) chess opening reader
-- for Arena standard
-- http://chessforeva.blogspot.com
-- original algorithm source: http://www.talkchess.com/forum/viewtopic.php?t=20661&postdays=0&postorder=asc&topic_view=flat&start=20


-- this loads and executes other .lua file
function dofile (filename)
  local f = assert(loadfile(filename))
  return f()
end
dofile( "c0_chess_subroutine.lua" );    -- chess logic


function readNumb(s,from,to,signed)
  local b=1;
  local r=0;
  local i=from;
  while i<=to do
    r=r+(b*string.byte(s,i));
    i=i+1;
    b=b*256;
  end
  if signed and string.byte(s,to)==255 then
    r=r-b;
  end
  return r;
end

-- this reads all games from memory
function getallvariants()

  c0_LuaChess.c0_get_moves_from_PGN("");
  c0_LuaChess.c0_PG_viewer = false; -- prep.

  local ply = 1;
  local errors = 0;
  local moves = {};
  local node = {};
  local z ={};
  local i = 0;
  local j = 0;
  node[1]=900;
  print( "Prepares list of variants");
  while(ply > 0) do
    z[ply] = binBase[node[ply]-900+1];
    moves[ply]= z[ply].uci;
    
    local m=1;
    local mlist = "";
    local ml = "";
    local uci = "";

    while(m<=ply) do
        uci = moves[m];
        local uciq = uci;
        if string.len(uciq)>4 then
            uciq = string.sub(uciq,1,4) ..
                    "[" .. string.upper( string.sub(uciq,5,5) ) .. "]";
        end
        mlist=mlist .. uciq;
        if(m<ply) then
            if(m>1) then
                ml=ml.." ";
            end
            ml=ml .. uci;
        end

        m = m + 1;
    end
        
    j = j + 1;
    csvrows[j] = '"' .. ml .. '","' ..  uci .. '",' ..
        z[ply].priority .. ',' .. z[ply].cnt_games .. ',' ..
        z[ply].won_games .. ',' .. z[ply].lost_games;
    
    local PGN = c0_LuaChess.c0_put_to_PGN(mlist);
    if c0_LuaChess.c0_errflag then
        errors = errors + 1;
    else
        i = i + 1;
        variants[i] = PGN;

        if i%100==0 then
            print(i);
        end
    end    
        
    if z[ply].first_child>0 then
        node[ply+1] =  z[ply].first_child;
        ply=ply+1;
    else
        node[ply] =  z[ply].next_sibling;

        while(ply>0 and node[ply]<0) do
            ply = ply-1;
            if ply>0 then
                node[ply] = binBase[node[ply]-900+1].next_sibling;
            end
        end

    end

  end
  print( c0_LuaChess.ToString(i) .." variants in memory, " ..
      c0_LuaChess.ToString(errors)  .. " could not read");

  -- rem it when processing to large csv
  printallvariants();

  writealltocsv();
end

-- this prints all games
function printallvariants()
  local i=1;
  print( "Printing" );
  while i<=table.getn(variants) do
    print(variants[i]);
    i = i + 1;
  end
end

-- this writes to csv
function writealltocsv()
  -- will be fast on next starting
  local csvfile = io.open("output.csv", "w")
  csvfile:write( "startpos_uci, move, priority, games, won, lost");
  csvfile:write( "\n" );
  local j=1;
  print( "Writing to file: output.csv" );
  while j<=table.getn(csvrows) do
    csvfile:write( csvrows[j] );
    csvfile:write( "\n" );
    j = j + 1;
  end
  csvfile:close();
end

-- this reads all the .abk file into memory
function readAbkFile(filename)
  local in_file = assert(io.open(filename, "rb"));
  local header = in_file:read(13);
  local Comment = in_file:read(121);
  local Author = in_file:read(81);
  local skipheader = in_file:read(0x6270-(13+121+81)); -- 900 x 28
  
  -- comment at
  local k=0;
  local buf;
  print( "Reading from file " .. filename);
  while true do
    buf = in_file:read(28);

    if not buf then break end;
    k = k+1;

    local move_from=string.byte( buf,1);
    local move_fh=(move_from % 8);
    local move_fv=(move_from-move_fh)/8;
    local move_to=string.byte( buf,2);
    local move_th=(move_to % 8);
    local move_tv=(move_to-move_th)/8;
    binBase[k]={};
    local uci=string.char(97+move_fh)..string.char(49+move_fv)..
        string.char(97+move_th)..string.char(49+move_tv);
    local promoted=math.abs(string.byte( buf,3));
    if promoted~=0 then
        uci = uci .. string.sub("rnbq",promoted);
    end
    binBase[k].uci = uci;
    binBase[k].priority=string.byte( buf,4);
    binBase[k].cnt_games=readNumb(buf,5,8,false);  -- unsigned int
	binBase[k].won_games=readNumb(buf,9,12,false);
    binBase[k].lost_games=readNumb(buf,13,16,false);
    binBase[k].hz=readNumb(buf,17,20,true);
    binBase[k].first_child=readNumb(buf,21,24,true); -- next move (answer), signed
    binBase[k].next_sibling=readNumb(buf,25,28,true); -- other legal move at the same ply, signed

    if k%1000==0 then
      print(k);
    end
  end
  in_file:close();
  getallvariants();
end


binBase = {};
variants = {};
csvrows = {};

-- scan .abk file
readAbkFile("book_tiny.abk");

