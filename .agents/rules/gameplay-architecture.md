# Gameplay & Economy Architecture Rules (from Game Studios)

## 1. Data-Driven Configuration
- Avoid hardcoding combat damage, drop amounts, and resource consumption.
- Keep formulas and balancing numbers accessible in dedicated config resources or JSON definitions.

## 2. Finite State Machines (FSM)
- Player and Enemy actions must use explicit states (e.g. `IDLE`, `WALK`, `DODGE`, `ATTACK`, `STUNNED`).
- Guard state transitions: do not allow new actions to interrupt uninterruptible animations unless explicitly designed (like a dodge cancel).

## 3. Night Raid Horde & Boss Siege AI
- Night beasts follow distinct siege archetypes:
  1. **Pack Swarmers (Timber Wolves):** Circle player, flank campfire.
  2. **Wall Breakers (Mad Boars):** Charge and deal 3x damage to wooden structures.
  3. **Disruptors (Porcupines/Bats):** Ranged quills/screeches targeting player behind walls.
  4. **Cycle Bosses (Boar Titan, Serpent):** Multi-phase combat with exposed weakspots.
- Pathfinding: steer toward Campfire center if player is hidden or behind fortified walls.

## 4. Synergy Economy & Drop Curves
- Resource drops follow the Chinese survival webnovel rarity progression (Phổ Thông -> Tinh Phẩm -> Cực Phẩm -> Huyền Thoại).
- Synergy crafting ratio: High-tier structures require balanced ratios of Wood, Stone, and Iron (e.g., Reinforced Watchtower = 30 Wood + 20 Stone + 5 Iron).
