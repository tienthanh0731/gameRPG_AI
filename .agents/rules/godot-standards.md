# Godot 4 & GDScript Architecture Standards (from Game Studios)

## 1. Composition over Inheritance
- Attach modular behaviors via child nodes (e.g. `SurvivalStats`, `Inventory`), never deep multi-level class inheritance.
- Keep scene trees shallow and self-contained. Root nodes define the entity boundary.

## 2. GDScript 2.0 Static Typing
- Enforce static typing on all variable declarations, function parameters, and return types:
  ```gdscript
  var move_speed: float = 160.0
  func take_damage(amount: float) -> void:
  ```
- Use `preload()` for internal scripts to avoid cyclic dependency / global class cache race conditions.
- Duck-typing for interaction checks: `if body.has_method("take_hit"): body.take_hit(current_tool)`.

## 3. Signal Architecture ("Signal Up, Call Down")
- Parent nodes call methods on child nodes directly (`stats.use_stamina(10.0)`).
- Child nodes emit signals upward when state changes (`signal stamina_changed(current, max)`).
- Never reach across distant sibling nodes with hardcoded `get_node("../../OtherNode")`. Wire via the scene root or signals.

## 4. Physics & Delta Time
- All movement and continuous calculations MUST be multiplied by `delta` in `_physics_process()`.
- Use explicit collision layers:
  - Layer 1: World Props (Trees, Rocks, Buildings)
  - Layer 2: Player
  - Layer 3: Enemies / Beasts
  - Layer 4: Interactive Triggers (Campfire, Zones)
  - Layer 8: Dropped Items / Pickups

## 5. Automated Verification
- Every new core system must have a headless test runnable via Godot CLI (`godot.exe --headless -s test_*.gd`) to prevent regressions.
