# --------------------------------------------------------------------
# An implementation of a "weave" maze generator. Weave mazes are those
# with passages that pass both over and under other passages. The
# technique used in this program was described to me by Robin Houston,
# and works by first decorating the blank grid with the over/under
# crossings, and then using Kruskal's algorithm to fill out the rest
# of the grid. (Kruskal's is very well-suited to this approach, since
# it treats the cells as separate sets and joins them together.)
# --------------------------------------------------------------------
# NOTE: the display routine used in this script requires a terminal
# that supports ANSI escape sequences. Windows users, sorry. :(
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# 1. Allow the maze to be customized via command-line parameters
# --------------------------------------------------------------------

width     = (ARGV[0] || 10).to_i
height    = (ARGV[1] || width).to_i
max_fails = (ARGV[2] || 5).to_i
seed      = (ARGV[3] || rand(0xFFFF_FFFF)).to_i
delay     = (ARGV[4] || 0.01).to_f

srand(seed)

# --------------------------------------------------------------------
# 2. Set up constants to aid with describing the passage directions
# --------------------------------------------------------------------

N, S, E, W, U = 0x1, 0x2, 0x4, 0x8, 0x10
DX            = { E => 1, W => -1, N =>  0, S => 0 }
DY            = { E => 0, W =>  0, N => -1, S => 1 }
OPPOSITE      = { E => W, W =>  E, N =>  S, S => N }

# --------------------------------------------------------------------
# 3. Data structures and methods to assist the algorithm
# --------------------------------------------------------------------

EW, NS, SE, SW, NE, NW = [0x80, 0x82, 0x8C, 0x90, 0x94, 0x98].map { |v| "\xE2\x94#{v.chr}" }
NSE, NSW, EWS, EWN     = [0x9C, 0xA4, 0xAC, 0xB4].map { |v| "\xE2\x94#{v.chr}" }

TILES = {
  0       => ["\e[47m   \e[m", "\e[47m   \e[m"],
  N       => ["#{NS} #{NS}", "#{NE}#{EW}#{NW}"],
  S       => ["#{SE}#{EW}#{SW}", "#{NS} #{NS}"],
  E       => ["#{SE}#{EW}#{EW}", "#{NE}#{EW}#{EW}"],
  W       => ["#{EW}#{EW}#{SW}", "#{EW}#{EW}#{NW}"],
  N|S     => ["#{NS} #{NS}", "#{NS} #{NS}"],
  N|W     => ["#{NW} #{NS}", "#{EW}#{EW}#{NW}"],
  N|E     => ["#{NS} #{NE}", "#{NE}#{EW}#{EW}"],
  S|W     => ["#{EW}#{EW}#{SW}", "#{SW} #{NS}"],
  S|E     => ["#{SE}#{EW}#{EW}", "#{NS} #{SE}"],
  E|W     => ["#{EW}#{EW}#{EW}", "#{EW}#{EW}#{EW}"],
  N|S|E   => ["#{NS} #{NE}", "#{NS} #{SE}"],
  N|S|W   => ["#{NW} #{NS}", "#{SW} #{NS}"],
  E|W|N   => ["#{NW} #{NE}", "#{EW}#{EW}#{EW}"],
  E|W|S   => ["#{EW}#{EW}#{EW}", "#{SW} #{SE}"],
  N|S|E|W => ["#{NW} #{NE}", "#{SW} #{SE}"],
  N|S|U   => ["#{NSW} #{NSE}", "#{NSW} #{NSE}"],
  E|W|U   => ["#{EWN}#{EW}#{EWN}", "#{EWS}#{EW}#{EWS}"]
}

def display_maze(grid)
  print "\e[H" # move to upper-left
  grid.each do |row|
    2.times do |i|
      row.each { |cell| print TILES[cell][i] }
      puts
    end
  end
end

class Tree
  attr_accessor :parent

  def initialize
    @parent = nil
  end

  def root
    @parent ? @parent.root : self
  end

  def connected?(tree)
    root == tree.root
  end

  def connect(tree)
    tree.root.parent = self
  end
end

grid = Array.new(height) { Array.new(width, 0) }
sets = Array.new(height) { Array.new(width) { Tree.new } }

# build the list of edges
edges = []
height.times do |y|
  width.times do |x|
    edges << [x, y, N] if y > 0
    edges << [x, y, W] if x > 0
  end
end

edges = edges.sort_by{rand}

# --------------------------------------------------------------------
# 4. Build the over/under locations
# --------------------------------------------------------------------

fails = 0
while fails < max_fails
  cx = rand(width-2) + 1
  cy = rand(height-2) + 1

  nx, ny = cx, cy-1
  wx, wy = cx-1, cy
  ex, ey = cx+1, cy
  sx, sy = cx, cy+1
  
  if grid[cy][cx] != 0 ||
      sets[ny][nx].connected?(sets[sy][sx]) ||
      sets[ey][ex].connected?(sets[wy][wx])
    fails += 1
    next
  end
  
  sets[ny][nx].connect(sets[sy][sx])
  sets[ey][ex].connect(sets[wy][wx])
  fails = 0

  if rand(2) == 0
    grid[cy][cx] = E|W|U
  else
    grid[cy][cx] = N|S|U
  end

  grid[ny][nx] |= S
  grid[wy][wx] |= E
  grid[ey][ex] |= W
  grid[sy][sx] |= N

  edges.delete_if do |x, y, dir|
    (x == cx && y == cy) ||
    (x == ex && y == ey && dir == W) ||
    (x == sx && y == sy && dir == N)
  end
end

print "\e[2J" # clear the screen

display_maze(grid)
puts
puts "--- PRESS ENTER TO BEGIN ---"
STDIN.gets

at_exit do # show the cursor on exit
  print "\e[?25h"
  STDOUT.flush
end
print "\e[2J\e[?25l" # clear the screen and hide the cursor

# --------------------------------------------------------------------
# 5. Kruskal's algorithm
# --------------------------------------------------------------------

until edges.empty?
  x, y, direction = edges.pop
  nx, ny = x + DX[direction], y + DY[direction]

  set1, set2 = sets[y][x], sets[ny][nx]

  unless set1.connected?(set2)
    display_maze(grid)
    sleep(delay)

    set1.connect(set2)
    grid[y][x] |= direction
    grid[ny][nx] |= OPPOSITE[direction]
  end
end

display_maze(grid)

# --------------------------------------------------------------------
# 6. Show the parameters used to build this maze, for repeatability
# --------------------------------------------------------------------

puts "#{$0} #{width} #{height} #{max_fails} #{seed}"
