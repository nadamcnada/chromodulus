class_name GameText
extends RefCounted
## Static player-facing text for the How to Play and Scoring System pages.

const HOW_TO_PLAY_BBCODE := (
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

const SCORING_SYSTEM_BBCODE := (
	"[font_size=28][b]Scoring System[/b][/font_size]\n\n" +
	"Patterns are scored along rows, columns and diagonals (including off-center diagonals), reading in either direction. A pattern needs 4 or more cells in sequence; only the single longest qualifying pattern in a line is scored - shorter sub-sequences within it are not scored again.\n\n" +
	"[font_size=20][b]Numerical Patterns[/b][/font_size]\n" +
	"[b]Run[/b] - consecutive numbers, e.g. 1234 or 7890 (0 may only sit before 1 or after 9 - no wraparound).\n" +
	"[indent]4 cells = 5 pts, 5 = 10 pts, 6 = 20 pts, 7 = 40 pts[/indent]\n" +
	"[b]Cluster[/b] - the same number repeated, e.g. 9999.\n" +
	"[indent]4 cells = 5 pts, 5 = 10 pts, 6 = 20 pts, 7 = 40 pts[/indent]\n" +
	"[b]Alternating Run[/b] - a repeating block of 2+ numbers, repeated at least twice, e.g. 121212 or 385385.\n" +
	"[indent]4 cells = 2 pts, 5 = 5 pts, 6 = 10 pts, 7 = 20 pts[/indent]\n" +
	"[b]Pyramid[/b] - a palindrome with no immediately repeated number, e.g. 12321 or 47074. Length must be exactly 5 or 7.\n" +
	"[indent]5 cells = 5 pts, 7 cells = 20 pts[/indent]\n\n" +
	"[font_size=20][b]Chromatic Patterns[/b][/font_size]\n" +
	"[b]Monochrome[/b] - the same color repeated, e.g. RRRR.\n" +
	"[indent]4 cells = 2 pts, 5 = 5 pts, 6 = 10 pts, 7 = 20 pts[/indent]\n" +
	"[b]Alternating Colors[/b] - a repeating block of 2+ colors, repeated at least twice, e.g. RYRY.\n" +
	"[indent]4 cells = 2 pts, 5 = 5 pts, 6 = 10 pts, 7 = 20 pts[/indent]\n" +
	"[b]Color Pyramid[/b] - a color palindrome with no immediately repeated color. Length must be exactly 5 or 7.\n" +
	"[indent]5 cells = 5 pts, 7 cells = 20 pts[/indent]\n" +
	"[b]Spectrum[/b] - one of the six exact 7-color rainbow sequences (RYGABPR, RPBAGYR, GABPRYG, GYRPBAG, BPRYGAB, BAGYRPB).\n" +
	"[indent]7 cells = 40 pts[/indent]\n" +
	"[b]One of Each Color[/b] - all seven colors present, any order, across a full 7-cell line.\n" +
	"[indent]7 cells = 40 pts[/indent]\n\n" +
	"[font_size=20][b]Combining Numeric + Chromatic[/b][/font_size]\n" +
	"When a numeric pattern and a chromatic pattern occupy the exact same cells, their combined points are [b]doubled[/b].\n" +
	"Five special pairings score a [b]quadruple[/b] instead: Pyramid + Color Pyramid (matching structure), Alternating Run + Alternating Colors (matching structure), Run + One of Each Color (7 cells), Cluster + Monochrome (7 cells), and Run + Spectrum (7 cells).\n\n" +
	"[font_size=20][b]Nexus[/b][/font_size]\n" +
	"A Nexus cell belongs to two or more separately scored patterns (e.g. where a row pattern crosses a column pattern).\n" +
	"[indent]2 patterns link = 20 pts, 3 link = 40 pts, 4+ link = 80 pts[/indent]\n\n" +
	"[font_size=20][b]2D Patterns[/b][/font_size]\n" +
	"If the exact same pattern repeats in adjacent parallel rows or columns (aligned cell-for-cell), every repeated line's score is multiplied: 2 lines = x4, 3 = x8, 4 = x16, 5 = x20, 6 = x24, 7 = x28. 2D bonuses apply to rows and columns only, never diagonals, and apply separately to the numeric and chromatic portions of a pattern."
)
