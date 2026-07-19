class_name GameText
extends RefCounted
## Static player-facing text for the How to Play and Scoring System popups.
## Named per-version so each game version can supply its own content.

const CLASSIC_HOW_TO_PLAY_BBCODE := (
	"[font_size=28][b]Chromodulus Classic - How to Play[/b][/font_size]\n\n" +

	"[font_size=20][b]Overview[/b][/font_size]\n" +
	"Chromodulus is a game that is played on a 7x7 grid. The cells of the grid are pre-filled with \"chromo-numerical\" squares, which are Red, Green, Blue or White in color, and also feature a single-digit number (0-9). The player then adds squares that they draw from a stock deck of squares. The color of the square being played changes the color of the cell being played upon, and the number of the square being played combines with the number being played upon to change the number. The objective of the game is to create numerical and chromatic patterns to maximize the total score. These are chromatic, numerical, and chromatic-numerical patterns across rows, columns and diagonals. The patterns must be 4 cells/squares or more in sequence (see patterns below). Bonus points are awarded for intersecting patterns (a.k.a. Nexus Cells).\n\n" +

	"[font_size=20][b]Game Mechanics[/b][/font_size]\n" +
	"The game starts with a pre-filled grid. There are four initial draws of 10 squares each to the player's hand. During each of these draws, the player can play up to 7 squares. When ready for the next draw, the player presses the \"Next Draw\" button. In the fifth and final draw, the player can play up to ten out of the ten squares drawn. When ready, the player presses the End Game button.\n\n" +

	"[font_size=20][b]Color Transformations[/b][/font_size]\n" +
	"Existing Color + Added Color = New Color\n" +
	"[indent]White + Red = Red\n" +
	"White + Green = Green\n" +
	"White + Blue = Blue\n" +
	"Red + Green = Yellow\n" +
	"Red + Blue = Purple\n" +
	"Red + Red = Not Allowed\n" +
	"Green + Red = Yellow\n" +
	"Green + Blue = Aqua\n" +
	"Green + Green = Not Allowed\n" +
	"Blue + Red = Purple\n" +
	"Blue + Green = Aqua\n" +
	"Blue + Blue = Not Allowed\n" +
	"Yellow + Red = Not Allowed\n" +
	"Yellow + Green = Not Allowed\n" +
	"Yellow + Blue = White\n" +
	"Purple + Red = Not Allowed\n" +
	"Purple + Blue = Not Allowed\n" +
	"Purple + Green = White\n" +
	"Aqua + Blue = Not Allowed\n" +
	"Aqua + Green = Not Allowed\n" +
	"Aqua + Red = White[/indent]\n" +
	"This system forces a color cycle where one each of Red, Green and Blue must be played before one of these colors can repeat. Once the cell color becomes or returns to White, then any of the squares in the player's hand can be played on that cell.\n\n" +

	"[font_size=20][b]Number Transformations[/b][/font_size]\n" +
	"The number of the square from the player's hand is added to the number of the cell upon which it is played. For example, a Red-2 square added to a Green-3 cell results in a Yellow-5.\n" +
	"Modular arithmetic is used to keep all numbers single digit. For example, a Red-9 square added to a Green-2 cell results in a Yellow-1 (9 + 2 = 1).\n\n" +

	"[font_size=20][b]Wildcards[/b][/font_size]\n" +
	"[indent]1. [b]Color Wildcard:[/b] has a preset number; the player decides the color of their choice upon placement (Red, Blue or Green).\n" +
	"2. [b]Number Wildcard:[/b] has a preset color; the player decides the number of their choice upon placement.\n" +
	"3. [b]Chromodulus Wildcard:[/b] the player decides both number and color upon placement.\n" +
	"4. [b]Invert Wildcard:[/b] the player applies this to a square they are placing onto the grid, which subtracts the square from the hand from the square in the grid where it is being placed.[/indent]\n" +
	"To play a Wildcard square, the player clicks on that square. A dialogue window will appear. If it is a Color Wildcard, the player is presented with these options: Red, Green, Blue, Cancel. If it is a Number Wildcard, the player is presented with these options: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9. If it is a Chromodulus Wildcard, the player is presented with both the Color and Number options. For the Invert Wildcard, the player is given the option to apply it to a square in their hand. All wildcards must be played or discarded during the turn in which they are drawn.\n\n" +

	"[font_size=20][b]Scoring Patterns[/b][/font_size]\n" +
	"All patterns must be chromo-numerical (color + number pattern).\n" +
	"• All patterns work the same in forward and reverse - e.g. 12345 = 54321\n" +
	"• There must be 4+ to make a pattern, the longer the better (more points)\n" +
	"• Some patterns require more than 4 cards minimum\n" +
	"• Nexus cells: added points for cells that are part of more than one pattern, the lynchpin cell where two patterns intersect\n" +
	"Note: White (W) is also eligible to be part of a pattern.\n\n" +

	"[b]Chromo-Numerical Patterns[/b]\n\n" +
	"[b]Run — Same Color[/b] (e.g. Red-1, Red-2, Red-3, Red-4)\n" +
	"[indent]Run (0-9)\n" +
	"• A Run is defined as: for every adjacent pair, the difference is either +1 or -1 across the sequence\n" +
	"• Wrapped runs are not allowed (e.g. 8901)\n" +
	"• Minimum of 4 cells/squares (e.g. 1234 or 3456)\n" +
	"• Up to 7 cells/squares long (e.g. 3456789)\n" +
	"• 0 can be at the beginning before \"1\" or at the end after \"9\" (e.g. 0123 or 7890)[/indent]\n\n" +

	"[b]Cluster — Same Color[/b] (e.g. Red-2, Red-2, Red-2, Red-2)\n" +
	"[indent]Cluster (22222)\n" +
	"• All same number\n" +
	"• Minimum of 4 cells/squares (e.g. 9999)[/indent]\n\n" +

	"[font_size=20][b]Scoring System[/b][/font_size]\n" +
	"Note: If multiple pattern definitions match the same exact cells, only the highest scoring pattern is awarded.\n\n" +
	"[b]Cluster — Same Color:[/b]\n" +
	"[indent]4 cells in sequence = 2pts\n" +
	"5 cells in sequence = 5pts\n" +
	"6 cells in sequence = 10pts\n" +
	"7 cells in sequence = 20pts[/indent]\n" +
	"[b]Run — Same Color:[/b]\n" +
	"[indent]4 cells in sequence = 2pts\n" +
	"5 cells in sequence = 5pts\n" +
	"6 cells in sequence = 10pts\n" +
	"7 cells in sequence = 20pts[/indent]\n\n" +

	"[b]Nexus:[/b]\n" +
	"[indent]Links 2 numerical patterns = 20pts\n" +
	"Links 3 numerical patterns = 40pts\n" +
	"Links 4+ numerical patterns = 80pts each[/indent]\n\n" +
	"Nexus Note: A Nexus is a cell that belongs to at least two independently scored patterns. Patterns sharing only endpoints still count. A pattern cannot intersect itself."
)

const CLASSIC_SCORING_SYSTEM_BBCODE := (
	"[font_size=28][b]Chromodulus Classic Scoring System[/b][/font_size]\n\n" +
	"• All patterns must be chromo-numerical (color + number pattern).\n" +
	"• All patterns work the same in forward and reverse - e.g. 12345 = 54321\n" +
	"• There must be 4+ to make a pattern, the longer the better (more points)\n" +
	"• Some patterns require more than 4 cards minimum\n" +
	"• Nexus cells: added points for cells that are part of more than one pattern, the lynchpin cell where two patterns intersect\n\n" +
	"Note: White (W) is also eligible to be part of a pattern.\n\n" +
	"[font_size=20][b]Chromo-Numerical Patterns[/b][/font_size]\n\n" +
	"[b]Run — Same Color[/b] (e.g. Red-1, Red-2, Red-3, Red-4)\n" +
	"[indent]Run (0-9)\n" +
	"• A Run is defined as: for every adjacent pair, the difference is either +1 or -1 across the sequence\n" +
	"• Wrapped runs are not allowed (e.g. 8901)\n" +
	"• Minimum of 4 cells/squares (e.g. 1234 or 3456)\n" +
	"• Up to 7 cells/squares long (e.g. 3456789)\n" +
	"• 0 can be at the beginning before \"1\" or at the end after \"9\" (e.g. 0123 or 7890)[/indent]\n\n" +
	"[b]Cluster — Same Color[/b] (e.g. Red-2, Red-2, Red-2, Red-2)\n" +
	"[indent]Cluster (22222)\n" +
	"• All same number\n" +
	"• Minimum of 4 cells/squares (e.g. 9999)[/indent]\n\n" +
	"[font_size=20][b]Scoring System[/b][/font_size]\n" +
	"Note: If multiple pattern definitions match the same exact cells, only the highest scoring pattern is awarded.\n\n" +
	"[b]Cluster — Same Color:[/b]\n" +
	"[indent]4 cells in sequence = 2pts\n" +
	"5 cells in sequence = 5pts\n" +
	"6 cells in sequence = 10pts\n" +
	"7 cells in sequence = 20pts[/indent]\n" +
	"[b]Run — Same Color:[/b]\n" +
	"[indent]4 cells in sequence = 2pts\n" +
	"5 cells in sequence = 5pts\n" +
	"6 cells in sequence = 10pts\n" +
	"7 cells in sequence = 20pts[/indent]\n\n" +
	"[b]Nexus:[/b]\n" +
	"[indent]Links 2 numerical patterns = 20pts\n" +
	"Links 3 numerical patterns = 40pts\n" +
	"Links 4+ numerical patterns = 80pts each[/indent]\n\n" +
	"Nexus Note: A Nexus is a cell that belongs to at least two independently scored patterns. Patterns sharing only endpoints still count. A pattern cannot intersect itself."
)
