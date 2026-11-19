"""Chapter 1 - EASY - 'Learn to Read the Pipes' (levels 1-20)."""
from designer import LevelDef

CHAPTER = 1
DIFFICULTY = 'easy'
NAME = 'Learn to Read the Pipes'


def levels():
    L = []

    # ---- 1-3: straight and elbow pipes -------------------------------------------------
    l = LevelDef(1, 'The First Turn', 'Tap a pipe to turn it. Join the tank to the tap, then press Start Water.',
                 3, 2, 0, 1, seed=11, wrong=1.0, par=(2, 4), tags=['elbow', 'tutorial'])
    l.route([(0, 0), (1, 0), (1, 1), (2, 1)]); L.append(l)

    l = LevelDef(2, 'Down the Pipe', 'Straight pipes carry water in a line. Elbows turn it a quarter.',
                 3, 3, 0, 2, seed=12, wrong=1.0, par=(3, 6), tags=['straight', 'elbow'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)]); L.append(l)

    l = LevelDef(3, 'The Staircase', 'Line up every opening with the next pipe along the route.',
                 4, 3, 0, 2, seed=13, wrong=0.9, par=(4, 8), tags=['elbow', 'turns'])
    l.route([(0, 0), (1, 0), (1, 1), (2, 1), (2, 2), (3, 2)]); L.append(l)

    # ---- 4-6: multiple turns, route planning --------------------------------------------
    l = LevelDef(4, 'Switchback', 'Long routes need a plan. Work from the tank toward the tap.',
                 4, 4, 0, 3, seed=14, wrong=0.85, par=(6, 13), tags=['turns', 'planning'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (1, 1), (1, 2), (2, 2), (3, 2), (3, 3)]); L.append(l)

    l = LevelDef(5, 'Planning Ahead', 'Look at where the water must end up before you turn anything.',
                 5, 3, 2, 0, seed=15, wrong=0.85, par=(5, 12), tags=['turns', 'planning'])
    l.route([(0, 2), (1, 2), (1, 1), (2, 1), (3, 1), (3, 0), (4, 0)]); L.append(l)

    l = LevelDef(6, 'The Detour', 'Not every pipe is already facing the right way. A short one to catch your breath.',
                 5, 4, 0, 3, seed=16, wrong=0.7, par=(5, 11), tags=['turns', 'recovery'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (3, 1), (3, 2), (3, 3), (4, 3)]); L.append(l)

    # ---- 7-9: distractors and misleading orientations -----------------------------------
    l = LevelDef(7, 'Look-Alikes', 'Some pipes are decoys. Only one route really reaches the tap.',
                 4, 4, 0, 3, seed=17, wrong=0.85, par=(6, 14), types='IL', density=0.3, tags=['decoys', 'lure'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (3, 2), (3, 3)])
    l.lure([(1, 2), (1, 3), (2, 3)], bait=(2, 2)); L.append(l)

    l = LevelDef(8, 'The False Shortcut', 'A line that looks finished is not always connected to anything useful.',
                 5, 3, 1, 1, seed=18, wrong=0.85, par=(6, 14), types='IL', density=0.55, tags=['decoys', 'lure', 'shortcut'])
    l.route([(0, 1), (0, 2), (1, 2), (2, 2), (2, 1), (3, 1), (4, 1)])
    l.lure([(0, 0), (1, 0), (2, 0), (3, 0)], bait=(0, 1)); L.append(l)

    l = LevelDef(9, 'Mixed Signals', 'Trust the openings, not the shape of the line.',
                 5, 4, 0, 3, seed=19, wrong=0.8, par=(8, 16), types='ILI', density=0.62, tags=['decoys', 'lure'])
    l.route([(0, 0), (0, 1), (1, 1), (2, 1), (2, 2), (2, 3), (3, 3), (4, 3)])
    l.lure([(2, 0), (3, 0), (4, 0)], bait=(2, 1)); L.append(l)

    # ---- 10-12: caps and sealed ends ------------------------------------------------------
    l = LevelDef(10, 'Seal the Leak', 'A tee has a spare opening. Seal it with an end cap, or the water leaks.',
                 4, 3, 1, 1, seed=20, wrong=1.0, par=(3, 9), tags=['cap', 'tee', 'tutorial'])
    l.route([(0, 1), (1, 1), (2, 1), (3, 1)]).branch((2, 1), [(2, 0)]); L.append(l)

    l = LevelDef(11, 'Cap Orientation', 'A cap only seals an end when its opening faces the pipe.',
                 4, 4, 1, 2, seed=21, wrong=0.9, par=(6, 13), types='IL', density=0.3, tags=['cap', 'tee'])
    l.route([(0, 1), (1, 1), (2, 1), (2, 2), (3, 2)]).branch((1, 1), [(1, 0)]).branch((2, 2), [(2, 3)]); L.append(l)

    l = LevelDef(12, 'Spare Opening', 'Even a corner can have a spare side. Find the cap that belongs to it.',
                 4, 3, 0, 1, seed=22, wrong=0.9, par=(5, 12), types='IL', density=0.55, tags=['cap', 'tee', 'decoy-cap'])
    l.route([(0, 0), (1, 0), (1, 1), (2, 1), (3, 1)]).branch((1, 0), [(2, 0)])
    l.decoy(3, 0, 'C').decoy(3, 2, 'C'); L.append(l)

    # ---- 13-15: junctions and branches ------------------------------------------------------
    l = LevelDef(13, 'Junction Trouble', 'A junction splits the flow. Every branch has to end in a cap.',
                 4, 3, 0, 0, seed=23, wrong=0.9, par=(5, 12), types='IL', density=0.6, tags=['tee', 'branch'])
    l.route([(0, 0), (1, 0), (2, 0), (3, 0)]).branch((1, 0), [(1, 1), (1, 2)]); L.append(l)

    l = LevelDef(14, 'Crossroads', 'A cross opens all four sides and never turns. Seal the two it does not need.',
                 5, 3, 1, 1, seed=24, wrong=1.0, par=(5, 12), types='ILC', density=0.65, tags=['cross', 'cap', 'tutorial'])
    l.route([(0, 1), (1, 1), (2, 1), (3, 1), (4, 1)]).branch((2, 1), [(2, 0)]).branch((2, 1), [(2, 2)]); L.append(l)

    l = LevelDef(15, 'Two Branches', 'Two junctions, two spurs. Count the openings before you start.',
                 5, 4, 0, 3, seed=25, wrong=0.85, par=(10, 20), types='ILC', density=0.5, tags=['tee', 'branch', 'cap'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (3, 2), (3, 3), (4, 3)])
    l.branch((2, 0), [(3, 0), (4, 0)]).branch((2, 2), [(1, 2), (0, 2)]); L.append(l)

    # ---- 16-18: small boards, several plausible routes ------------------------------------
    l = LevelDef(16, 'Two Ways Home', 'Two routes work. Which one costs fewer turns?',
                 3, 3, 1, 1, seed=26, wrong=0.8, solutions=(2, 2), par=(2, 8), tags=['two-routes', 'efficiency'])
    l.route([(0, 1), (0, 0), (1, 0), (2, 0), (2, 1)]).alt([(0, 1), (0, 2), (1, 2), (2, 2), (2, 1)]); L.append(l)

    l = LevelDef(17, 'The Tempting Loop', 'The route that looks nearly done is not always the cheapest.',
                 4, 3, 1, 1, seed=27, wrong=0.7, solutions=(2, 4), par=(4, 11), types='IL', density=0.8, tags=['two-routes', 'efficiency'])
    l.route([(0, 1), (0, 0), (1, 0), (2, 0), (3, 0), (3, 1)]).alt([(0, 1), (0, 2), (1, 2), (2, 2), (3, 2), (3, 1)]); L.append(l)

    l = LevelDef(18, 'Fork in the Pipes', 'Several routes are possible. Pick the one that needs the fewest turns.',
                 4, 4, 1, 2, seed=28, wrong=0.75, solutions=(2, 8), par=(5, 14), types='IL', density=0.75, tags=['two-routes', 'efficiency'])
    l.route([(0, 1), (0, 0), (1, 0), (2, 0), (3, 0), (3, 1), (3, 2)]).alt([(0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3), (3, 2)]); L.append(l)

    # ---- 19-20: chapter finale ----------------------------------------------------------------
    l = LevelDef(19, 'Reading the Pipes', 'A tee, a cap and a tempting line. Decide which side of the tee to open.',
                 5, 4, 0, 3, seed=29, wrong=0.8, par=(9, 20), types='ILC', density=0.6, tags=['tee', 'cap', 'lure', 'combine'])
    l.route([(0, 0), (1, 0), (1, 1), (2, 1), (3, 1), (3, 2), (3, 3), (4, 3)]).branch((2, 1), [(2, 2), (2, 3)])
    l.lure([(2, 0), (3, 0), (4, 0), (4, 1)], bait=(2, 1)); L.append(l)

    l = LevelDef(20, 'Everything Connects', 'Chapter finale: tees, a cross and caps. Seal every open end.',
                 5, 5, 0, 4, seed=30, wrong=0.8, par=(14, 30), types='ILC', density=0.4, tags=['tee', 'cross', 'cap', 'combine', 'finale'])
    l.route([(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (3, 2), (3, 3), (3, 4), (4, 4)])
    l.branch((1, 0), [(1, 1)]).branch((2, 2), [(1, 2)]).branch((2, 2), [(2, 3)]).branch((3, 3), [(4, 3)]); L.append(l)
    return L
