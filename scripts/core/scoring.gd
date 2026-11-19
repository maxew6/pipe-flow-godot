class_name Scoring
extends RefCounted
## Star rating from the number of taps used versus the level's par.
## Par = the fewest clockwise taps needed to reach the stored solution.


static func stars_for(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= par + maxi(3, ceili(float(par) * 0.5)):
		return 2
	return 1
