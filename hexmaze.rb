#!/usr/bin/ruby
DEBUG = true
# constants for storing borders as bits in an 8-bit value
#   _ _ NW SW S SE NE N
# e.g.: 00001001 is only N and S borders, etc.
# the two highest-order bits are reserved for IN and FRONTIER status
N, NE, SE, S, SW, NW = 1, 2, 4, 8, 16, 32
IN, FRONTIER = 64, 128

NONE = 0
ALLSIDES = N + NE + SE + S + SW + NW

OPPOSITE = { N => S, NE => SW, SE => NW,
             S => N, SW => NE, NW => SE }
DIRNAME  = { N => "N", NE => "NE", SE => "SE",
             S => "S", SW => "SW", NW => "NW",
             IN => "IN", FRONTIER => "FRONTIER" }

EMPTY = 0
PLAYER, ENEMY, SHELL = 1, 2, 4

class HexMaze
  # Store the borders/values in a 2-dimentional rectangular array
  # that will be sheared or rotated later into hexes:
  def initialize *args
    @width = args[0].to_i
    @height = ( args[1] || @width ).to_i
    @borders = Array.new(@height) { Array.new(@width, 0) }
    @values = Array.new(@height) { Array.new(@width, 0) }
  end

  def height
    return @height
  end

  def width
    return @width
  end

  def [](x,y)
    return @values[y][x]
  end

  def []=(x,y,val)
    @values[y][x] = val
  end

  def setValue(x,y,val)
    @values[y][x] = val
  end

  def borders(x,y)
    return @borders[y][x]
  end

  # set all border flags at once
  def setBorders(x,y,flags)
    @borders[y][x] = flags
  end

  # set 'dir' border on
  def setBorderOn(x,y,dir)
    if ! self.border?(x,y,dir) then
      @borders[y][x] = (@borders[y][x] | dir)
    end
  end

  # set 'dir' border off
  def setBorderOff(x,y,dir)
    if self.border?(x,y,dir) then
      @borders[y][x] -= dir
    end
  end

  # is 'dir' border on?
  def border?(x,y,dir)
    return ((@borders[y][x] & dir) == dir)
  end

  # return the set of (existing) neighbor cells
  def neighbors(x, y)
    n = []
    n << [x  , y+1] if (y+1 < self.height)            # N     __/0+\__
    n << [x+1, y  ] if (x+1 < self.width)             # NE   /-+\__/+0\
    n << [x+1, y-1] if (x+1 < self.width) && (y > 0)  # SE   \__/00\__/
    n << [x  , y-1] if (y > 0)                        # S    /-0\__/+-\
    n << [x-1, y  ] if (x > 0)                        # SW   \__/0-\__/
    n << [x-1, y+1] if (x > 0) && (y+1 < self.height) # NW      \__/
    n
  end

  # draw borders around edges of map
  def drawBorders
    for x in 0...width do # bottom and top
      self.setBorderOn(x,0,S)
      self.setBorderOn(x,0,SE)
      self.setBorderOn(x,height-1,N)
      self.setBorderOn(x,height-1,NW)
    end
    for y in 0...height do # left and right
      self.setBorderOn(0,y,S)
      self.setBorderOn(0,y,SW)
      self.setBorderOn(width-1,y,N)
      self.setBorderOn(width-1,y,NE)
    end
  end

  def displayCellValues
    displayScreen @values
  end

  def displayBorderValues
    displayScreen @borders
  end

  # print out a character grid of arbitrary height and width
  # with (0,0) in the lower left
  def displayScreen s
    rows = s.count
    labelWidth = rows.to_s.size
    for y in (rows - 1).downto(0) do
      printf "%#{labelWidth}s: |", y
      s[y].each_line do |x|
        printf "%3s ", x
      end 
      puts "|"
    end
  end

  #  __/11\__
  # /01\__/10\
  # \__/00\__/
  #    \__/
  def display
    screenHeight = @width + @height
    screenWidth = (@width * 3) + (@height - 1) * 3 + 1
    horizontalOffset = @height * 3 - 3
    screen = Array.new(screenHeight) { ' ' * screenWidth }
    for row in 0...@values.count do
      for col in 0...@values[row].count do
        x = horizontalOffset + (3 * col) - (3 * row)
        y = row + col
        val = @values[row][col]
        b = @borders[row][col]
        # screen[y][x..x+3]   = '\\__/'
        # screen[y+1][x..x+3] = "/%2s\\" % val
        # 
        # bottom half: \__/
        screen[y][x] = '\\' if (b & SW == SW)
        screen[y][x+1..x+2] = '__' if (b & S == S)
        screen[y][x+3] = '/' if (b & SE == SE)
        # top half: /  \
        screen[y+1][x] = '/' if (b & NW == NW)
        # screen[y+1][x+1..x+2] = ".."
        # screen[y+1][x+1..x+2] = "~~" if (b & FRONTIER == FRONTIER)
        #screen[y+1][x+1..x+2] = "  " if (b & IN == IN)
        screen[y+1][x+1..x+2] = case val
                                  when EMPTY, nil then "  "
                                  when PLAYER then "/\\"
                                  when ENEMY then "}{"
                                  when SHELL then "<>"
                                  else "%2s" % val
                                end
        if y+2 < screenHeight then
          screen[y+2][x+1..x+2] = '__' if (b & N == N)
        end
        screen[y+1][x+3] = '\\' if (b & NE == NE)
      end
    end
    displayScreen(screen)
  end

  def exercise
    puts "Maze of #{self.height} rows and #{self.width} cols:"
    [:displayCellValues, :display].each do |work|
      self.send(work)
      gets()
    end
  end

  # Mark a cell as being in the frontier (for Primm's algorithm),
  # which defines the set of cells adjacent to currently IN cells.
  # Don't add cells already IN the maze or in the FRONTIER.
  def add_frontier(x, y, frontier)
    if x >= 0 && y >= 0 &&
      y < self.height && x < self.width &&
      ! self.border?(x,y,IN) &&
      ! frontier.include?([x,y]) then
        self.setBorderOn(x, y, FRONTIER)
        frontier << [x,y]
    end
  end

  # Mark a cell as IN the maze and add all neighbors to the FRONTIER.
  # Turn on all borders when a cell becomes IN; we'll turn one off soon
  def mark(x, y, frontier)
    self.setBorders(x,y,ALLSIDES)
    self.setBorderOn(x,y,IN)
    add_frontier(x+1, y+1, frontier) # N   +y  __/++\__  +x
    add_frontier(x+1, y  , frontier) # NE     /0+\__/+0\ 
    add_frontier(x  , y-1, frontier) # SE     \__/00\__/
    add_frontier(x-1, y-1, frontier) # S      /-0\__/0-\
    add_frontier(x-1, y  , frontier) # SW     \__/--\__/
    add_frontier(x  , y+1, frontier) # NW  -x    \__/    -y
  end

  # Return neighbors that are already IN the maze
  def neighborsIn(x, y)
    n = []
    n << [x+1, y+1] if (x+1 < self.width) && (y+1 < self.height) && self.border?(x+1,y+1,IN) # N
    n << [x+1, y  ] if (x+1 < self.width) && self.border?(x+1,y,IN) #NE
    n << [x  , y-1] if (y > 0) && self.border?(x,y-1,IN) # SE
    n << [x-1, y-1] if (x > 0) && (y > 0) && self.border?(x-1,y-1,IN) # S
    n << [x-1, y  ] if (x > 0) && self.border?(x-1,y,IN) # SW
    n << [x  , y+1] if (y+1 < self.height) && self.border?(x,y+1,IN) # NW
    return n
  end

  # Return the direction from (fx,fy) -> (tx,ty) which must be adjacent
  def direction (fx, fy, tx, ty)
    #puts "(#{fx},#{fy}) -> (#{tx},#{ty})"
    return case
      when (fx < tx  && fy < ty)  then N   #  +y  __/++\__  +x
      when (fx < tx  && fy == ty) then NE  #     /0+\__/+0\
      when (fx == tx && fy > ty)  then SE  #     \__/00\__/
      when (fx > tx  && fy > ty)  then S   #     /-0\__/0-\
      when (fx > tx  && fy == ty) then SW  #     \__/--\__/
      when (fx == tx && fy < ty)  then NW  #  -x    \__/    -y
    end
  end

  # Return distance (in hexes) from (fx,fy) -> (tx,ty)
  def distance (fx, fy, tx, ty)
    dx = tx - fx
    dy = ty - fy
    if (dx <=> 0) == (dy <=> 0) then
      return [dx.abs, dy.abs].max
    else
      return dx.abs + dy.abs
    end
  end

  # Return the line-of-sight path (as a list of (x,y) coords) from (fx,fy) -> (tx, ty)
  # using modified Bresenham's line algorithm (using integers only)
  def los (fx, fy, tx, ty)
    pathlist = []
    dx = (tx - fx).abs
    dy = (ty - fy).abs
    x, y = fx, fy
    
    sig = (dx <=> 0 ) == (dy <=> 0)
    if (dx < 0) then xone = -1 else xone = 1 end
    if (dy < 0) then yone = -1 else yone = 1 end
    if (dx % 2) then
      dx *= 2
      dy *= 2
    end
    dx = dx.abs
    dy = dy.abs
    factor = dx/2

    # ONLY WORKS FOR DX>DY
    
    # puts "... adding (#{x},#{y}) to path"
    pathlist << [x,y]

    steps = 0
    while (x != tx) or (y != ty) do
      steps += 1
      if (steps > 10) then
        puts "ABORT - too many steps"
        exit
      end
      factor += dy
      if (factor >= dx) then
        factor -= dx
        if (sig) then
          x += xone
          y += yone
        else
          x += xone
          pathlist << [x,y]
          y += yone
        end
      else
        x += xone
      end
      pathlist << [x,y]
    end
    return pathlist
  end #los

  # Use Primm's algorithm to generate a maze of hex borders
  def primm *args
    disp = (args[0] || false) # if true, animate display as we create it
    frontier = []
    startx=rand(width)
    starty=rand(height)
    mark(startx, starty, frontier)
    
    print "\e[2J" if disp # clear the screen
  
    until frontier.empty?
      x, y = frontier.delete_at(rand(frontier.length))
    
      # mark cell as IN (which turns on all borders and removes FRONTIER)
      mark(x, y, frontier)
    
      # pick a random IN neighbor
      n = neighborsIn(x, y)
      nx, ny = n[rand(n.length)]
      dir = direction(x, y, nx, ny)
      
      # turn off the borders from the new cell back to the IN cell
      self.setBorderOff(x, y, dir)
      self.setBorderOff(nx, ny, OPPOSITE[dir])
    
      print "\e[H" if disp # move to upper-left
      self.display if disp
      sleep 0.01
    end
  end # primm
end # Class HexMaze

width  = (ARGV[0] || 10).to_i
height = (ARGV[1] || width).to_i
seed   = (ARGV[2] || rand(0xFFFF_FFFF)).to_i

srand(seed)
maze = HexMaze.new(width, height)
#maze.drawBorders
maze.primm true

px = rand(width).to_i
py = rand(height).to_i
maze[px,py]=PLAYER
rx = rand(width).to_i
ry = rand(height).to_i
maze[rx,ry]=ENEMY
p = maze.los(px,py,rx,ry)
p.each do |x,y|
  if maze[x,y] != PLAYER and maze[x,y] != ENEMY then
    maze[x,y]=SHELL
  end
end

#puts "\nValues:"
#maze.displayCellValues
#puts "\nBorders:"
#maze.displayBorderValues
#puts " "

print "\e[H" # move to upper-left
maze.display

puts "#{$0} #{width} #{height} #{seed}"

dist = maze.distance(px,py,rx,ry)
puts "Distance from (#{px},#{py}) to (#{rx},#{ry}) = #{dist}"

print "LOS: "
p.each do |x,y|
  print "(#{x},#{y}) "
end
puts ""
