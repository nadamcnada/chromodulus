class_name GameText
extends RefCounted
## Static player-facing text for the How to Play and Scoring System popups.
## Named per-version so each game version can supply its own content.

const CLASSIC_HOW_TO_PLAY_BBCODE := (
	"[font_size=28][b]How to Play — Chromodulus (Base)[/b][/font_size]\n\n" +
	"[b]Objective[/b]\n" +
	"Chromodulus is played on a 7x7 grid of chromo-numerical squares - each cell has a color (Red, Green, Blue, White, Yellow, Purple or Aqua) and a number (0-9). You add squares from your hand onto the grid to build chromatic and numerical patterns of 4 or more cells in a row, column, or diagonal - the more and longer the patterns, the higher your score.\n\n" +
	"[b]The Grid[/b]\n" +
	"At the start of a game all 49 cells are randomly filled with Red, Green, Blue or White, each paired with a random number 0-9.\n\n" +
	"[b]Playing a Square[/b]\n" +
	"Click a square in your hand to select it, then click a grid cell to place it there. Placing a square changes the target cell in two ways:\n" +
	"[indent]- [b]Color:[/b] the played color combines with the cell's existing color (see the Color Combination table below). Some combinations are Not Allowed - you can't play that color there. Cells highlighted while a square is selected show where it's legal to place it.\n" +
	"- [b]Number:[/b] the played number is added to the cell's number, wrapping with modular arithmetic (e.g. 9 + 2 = 1). Playing a 0 leaves the number unchanged.[/indent]\n\n" +
	"[b]Color Combination Table[/b]\n" +
	"White + Red/Green/Blue -> Red/Green/Blue\n" +
	"Red + Green -> Yellow, Red + Blue -> Purple, Red + Red -> Not Allowed\n" +
	"Green + Red -> Yellow, Green + Blue -> Aqua, Green + Green -> Not Allowed\n" +
	"Blue + Red -> Purple, Blue + Green -> Aqua, Blue + Blue -> Not Allowed\n" +
	"Yellow + Blue -> White (Yellow + Red/Green -> Not Allowed)\n" +
	"Purple + Green -> White (Purple + Red/Blue -> Not Allowed)\n" +
	"Aqua + Red -> White (Aqua + Green/Blue -> Not Allowed)\n\n" +
	"This forces a color cycle: once a cell becomes Red, Green or Blue, you must cycle through the other two primaries before repeating one, until the cell returns to White - at which point any color can be played on it again.\n\n" +
	"[b]Wildcards[/b]\n" +
	"[indent]- [b]Color Wildcard:[/b] has a preset number; choose the color (Red, Green or Blue) when you play it.\n" +
	"- [b]Number Wildcard:[/b] has a preset color; choose the number (0-9) when you play it.\n" +
	"- [b]Chromodulus Wildcard:[/b] choose both color and number when you play it.\n" +
	"- [b]Invert Wildcard:[/b] click it, then click another square in your hand to apply it to. That square will subtract (larger number minus smaller number) instead of add, when it's later played.[/indent]\n" +
	"All wildcards must be played or discarded during the turn you draw them.\n\n" +
	"[b]Turn-10 Mode[/b]\n" +
	"Each of the first four draws deals you 10 squares. You must discard between 3 and 5 of them, meaning you play between 5 and 7. Once you've played 7 you must discard the rest; once you've discarded 5 you must play the rest.\n\n" +
	"After four draws, your fifth and final draw is sized from your total discards across those four draws: you receive half that total (rounded up). In the final draw you may play as few or as many squares as you like - when you're finished, press [b]End Game[/b] to calculate your score.\n\n" +
	"[b]Undo[/b]\n" +
	"The Undo button reverts your most recent action (up to 10 moves back), fully restoring the grid, hand, discards and wildcard choices from before that action.\n\n" +
	"[b]Controls[/b]\n" +
	"Click a square, then click a grid cell to place it, or click Discard Selected to discard it instead."
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
