"""Junkyard Fusion economy sim, 2026-10-09, with the live numbers.

One efficient active player. A car comes out every 5 s and SHARE of them
are theirs to take (other players grab the rest); every GRAB seconds they
take the best one still on the belt (cars last LIFETIME s). They buy Shop
addons for coins and either fuse a spare car or upgrade a placed build (a
build can take a better addon), always picking the move that adds the most
income per coin, as long as it pays itself back within PAYBACK_LIMIT.
8 pads. Mutations roll on every fusion (pity 150). Rebirth as soon as it is
affordable; it takes only coins (KEEP) since 2026-10-09.

  python econ_sim.py [GRAB seconds] [SHARE]       (defaults 45, 1/3)
  PAYBACK=180 KEEP=0 python econ_sim.py            (the rules before 2026-10-09)

recipe.json is every car x addon build value (FusionRecipes.Fuse in
Studio). It predates the Civic, which the sim leaves out. Not Phantoms,
races, daily rewards, quests or offline earnings either: real players are
slower than this, and those extras faster. docs/ECONOMY.md has the results.
"""
import random, json, statistics, sys

PAYBACK = int(__import__('os').environ.get('PAYBACK', 360))  # PLACEMENT_PAYBACK_SECONDS
KEEP = __import__('os').environ.get('KEEP', '1') == '1'  # Rebirth keeps cars
PADS = 8
SPAWN_EVERY = 5
GRAB = int(sys.argv[1]) if len(sys.argv) > 1 else 45
SHARE = float(sys.argv[2]) if len(sys.argv) > 2 else 1/3   # the share of the belt this player gets
LIFETIME = 180
PAYBACK_LIMIT = 1800   # a purchase must earn its price back within this (seconds)
FUSE_TIME = 15         # walking to the pad, loading it

CARS = [("Rusted Sedan", 24, 5), ("Dirt Bike", 24, 10), ("Golf Cart", 14, 15), ("Muscle Car", 14, 25),
        ("Cop Cruiser", 7, 35), ("Box Truck", 3.5, 55), ("Monster Truck", 1.5, 90)]
ADDONS = [("Nitrous Tank", 100), ("Straight Pipes", 160), ("Scrap Turbo", 220), ("Inline 4", 1500),
          ("Rotary Engine", 1800), ("Twin Turbo", 2200), ("V6 Engine", 8000), ("Supercharger", 9600),
          ("Diesel Stack", 11200), ("V8 Engine", 40000), ("V12 Engine", 48000), ("Hover Fans", 56000),
          ("Jet Engine", 200000), ("Rocket Booster", 240000), ("Fusion Core", 280000)]
RECIPE = json.load(open(__file__.replace('econ_sim.py', 'recipe.json')))
VAL = {car: {kv.split('=')[0]: int(kv.split('=')[1]) for kv in row} for car, row in RECIPE.items()}
CAR_VALUE = {c: v for c, _, v in CARS}
REBIRTH = [(400000, 1.25), (4000000, 1.6), (15000000, 2.0), (40000000, 2.5), (120000000, 3.25), (350000000, 4.0)]
MUT = [(1/2000, 20), (1/300, 8), (1/75, 4), (1/20, 2)]
RARITY_AT = [("rare", 600), ("epic", 2500), ("mythic", 12500), ("legendary", 65000), ("godly", 178200)]

def roll_mut(pity):
    for chance, mult in MUT:
        if random.random() < chance: return mult, 0
    if pity >= 150: return 2, 0
    return 1, pity + 1

def spawn():
    r = random.random() * 88
    for name, w, _ in CARS:
        r -= w
        if r <= 0: return name
    return CARS[0][0]

def run(hours=12, coin_mult=1.0, seed=None):
    random.seed(seed)
    t, coins, rebirth = 0, 0.0, 0
    pads, spare = [], []        # pads: [car, addonIndex or -1, mutation]
    pity, firsts, rebirth_at = 0, {}, []
    belt, since_grab = [], 0   # (car, time it came out) this player could take
    def value(p): return (VAL[p[0]][ADDONS[p[1]][0]] if p[1] >= 0 else CAR_VALUE[p[0]]) * p[2]
    def mult(): return coin_mult * (REBIRTH[rebirth - 1][1] if rebirth else 1)
    while t < hours * 3600:
        income = sum(value(p) for p in pads) / PAYBACK * mult()
        # The belt.
        if t % SPAWN_EVERY == 0 and random.random() < SHARE:
            belt.append((spawn(), t))
        belt = [b for b in belt if t - b[1] < LIFETIME]
        since_grab += 1
        if since_grab >= GRAB and belt:
            pick = max(belt, key=lambda b: CAR_VALUE[b[0]]); belt.remove(pick)
            spare.append(pick[0]); since_grab = 0
            spare.sort(key=lambda c: -CAR_VALUE[c]); del spare[12:]
            # A raw car on an empty pad beats nothing.
            if len(pads) < PADS and spare: pads.append([spare.pop(0), -1, 1])
        # Rebirth when affordable.
        if rebirth < len(REBIRTH) and coins >= REBIRTH[rebirth][0]:
            rebirth_at.append(round(t / 60)); rebirth += 1
            coins = 0.0
            if not KEEP: pads, spare = [], []
        # Best purchase.
        best = None
        weakest = min(pads, key=value) if len(pads) >= PADS else None
        for ai, (aname, price) in enumerate(ADDONS):
            if price > coins: break
            opts = []
            for i, p in enumerate(pads):            # upgrade a placed build
                if ai > p[1]:
                    opts.append((VAL[p[0]][aname] * p[2] - value(p), ('up', i, ai, price)))
            for c in spare[:3]:                       # fuse a spare car
                gain = VAL[c][aname] - (value(weakest) if weakest else 0)
                opts.append((gain, ('new', c, ai, price)))
            for gain, act in opts:
                if gain <= 0: continue
                if price > gain / PAYBACK * mult() * PAYBACK_LIMIT: continue
                score = gain / price
                if best is None or score > best[0]: best = (score, act)
        if best:
            kind, x, ai, price = best[1]
            coins -= price
            m, pity = roll_mut(pity)
            if kind == 'up':
                pads[x][1] = ai; pads[x][2] = max(pads[x][2], m)
            else:
                spare.remove(x)
                new = [x, ai, m]
                if len(pads) >= PADS: pads.remove(weakest)
                pads.append(new)
            for rname, floor in RARITY_AT:
                if rname not in firsts and max(value(p) / p[2] for p in pads) >= floor:
                    firsts[rname] = round(t / 60)
            t += FUSE_TIME; coins += income * FUSE_TIME
            continue
        t += 1; coins += income
    return firsts, rebirth_at, income

if __name__ == '__main__':
    for label, cm in [("no passes", 1.0), ("2x Coins pass + group (+10%)", 2.2)]:
        runs = [run(hours=24, coin_mult=cm, seed=s) for s in range(20)]
        print(f"== {label}, grabbing a car every {GRAB}s, 24 h of play")
        for rname, _ in RARITY_AT:
            ts = [r[0].get(rname) for r in runs if r[0].get(rname) is not None]
            print(f"  first {rname:9s}: median {statistics.median(ts) if ts else '-'} min ({len(ts)}/20 runs)")
        for i in range(6):
            ts = [r[1][i] for r in runs if len(r[1]) > i]
            print(f"  Rebirth {i+1}: median {statistics.median(ts) if ts else '-'} min of play ({len(ts)}/20 runs)")
