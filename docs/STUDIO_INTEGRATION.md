# Hướng Dẫn Tích Hợp Game Studios & Agent Sprite Forge
**Dự Án: Lam Tinh – Hoang Cổ Ký (Blue Star: Primordial Survival)**

Hệ thống phát triển của dự án hiện đã tích hợp sức mạnh từ 2 kho công cụ mã nguồn mở hàng đầu:
1. **[Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)**: Bộ khung studio phát triển game chuyên nghiệp với 49 vai trò AI chuyên biệt, 75 workflow skills và tiêu chuẩn kiến trúc game engine chuẩn AAA.
2. **[agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge)**: Bộ công cụ xử lý đồ họa pixel art 2D, kiểm định chất lượng sprite sheet (QC), lượng tử hóa bảng màu và xuất bản trực tiếp cho Godot 4.

Vị trí lưu trữ cục bộ: `d:\gameRPG_AI\.external_tools/` (đã cấu hình trong `.gitignore` để không làm nặng kho mã nguồn Git chính).

---

## I. Ứng Dụng Từ Claude-Code-Game-Studios

### 1. Phân Vai Trò Chuyên Biệt (Specialized Studio Roles)
Khi phát triển các tính năng tiếp theo, agent sẽ đóng vai và tuân thủ các quy tắc của từng vị trí:
- **Godot Specialist & GDScript Specialist (`.claude/agents/godot-specialist.md`):**
  - Tuân thủ nguyên tắc *Composition over Inheritance*: Tách nhỏ hành vi thành các node độc lập (`SurvivalStats`, `Inventory`), không lạm dụng kế thừa đa tầng.
  - Áp dụng cấu trúc tín hiệu chuẩn *"Signal up, call down"*: Node cha gọi hàm node con trực tiếp; node con chỉ bắn tín hiệu lên trên, không gọi chéo.
  - Ép kiểu tĩnh (Static Typing GDScript 2.0) 100% để tối ưu hiệu năng và bắt lỗi tại thời điểm biên dịch.
  - Sử dụng `preload()` nội bộ tránh lỗi phân giải class cache toàn cục.
- **Gameplay & Systems Designer (`.claude/agents/gameplay-programmer.md`):**
  - Thiết kế State Machine rõ ràng: `IDLE`, `WALK`, `DODGE`, `ACTION_AXE`, `ACTION_MINE`, `ACTION_ATTACK`.
  - Cơ chế chiến đấu và tương tác chuột mượt mà (hướng nhìn theo con trỏ chuột, tính toán khoảng cách thông minh).
- **AI Programmer & Night Raid Engineer (`.claude/agents/ai-programmer.md`):**
  - Xây dựng 4 archetype thú triều ban đêm: *Pack Swarmers* (Sói rừng cắn tỉa), *Wall Breakers* (Heo rừng húc đổ tường rào), *Disruptors* (Nhím gai phóng gai tầm xa), *Cycle Bosses* (Thủ lĩnh thú triều có điểm yếu weakspot).
- **QA Tester & Automation Lead (`.claude/agents/qa-tester.md`):**
  - Mọi cơ chế cốt lõi đều được kiểm thử hồi quy bằng lệnh không đầu (headless runner) của Godot trước khi commit (`godot.exe --headless -s test_*.gd`).

### 2. Bộ Quy Tắc Đã Đưa Vào Dự Án
Được lưu trữ trực tiếp tại:
- [godot-standards.md](file:///d:/gameRPG_AI/.agents/rules/godot-standards.md): Tiêu chuẩn code GDScript 4, quản lý bộ nhớ và physics layers.
- [gameplay-architecture.md](file:///d:/gameRPG_AI/.agents/rules/gameplay-architecture.md): Quy chuẩn thiết kế FSM, kinh tế tài nguyên và thú triều ban đêm.

---

## II. Ứng Dụng Từ Agent Sprite Forge

### 1. Bộ Công Cụ Xử Lý Sprite 2D
- **Kiểm định chất lượng Sprite Sheet (`sheet_qc.py`):**
  - Quét kiểm tra viền thừa (spill), lệch pixel giữa các frame, mất nét nhân vật hoặc màu lạ rò rỉ.
- **Lượng tử hóa Pixel & Bảng màu (`pixel_look.py`):**
  - Chuyển đổi tranh vẽ ý tưởng / AI concept sang chuẩn 1x pixel art bám lưới tọa độ chính xác, không nhòe pixel.
- **Tự động ghép & cắt frame (`assemble_frames.py`):**
  - Ghép các frame hoạt ảnh độc lập thành dải sprite ngang chuẩn xác cho Godot 4 `Sprite2D` (`hframes`).

### 2. Công Cụ Hỗ Trợ Nhanh: `tools/sprite_forge_helper.py`
Bạn hoặc Agent có thể gọi trực tiếp công cụ này qua terminal:

```bash
# 1. Xem thông tin kích thước và phân tích frame của ảnh:
python tools/sprite_forge_helper.py info "assets/characters/survivor_male/PlayerAxe-Sheet.png"

# 2. Cắt một dải sprite thành từng file ảnh frame riêng biệt:
python tools/sprite_forge_helper.py slice "assets/buildings/campfire_and_furnace/CampFire-Sheet.png" 3 --out-dir "temp_campfire_frames"

# 3. Ghép các frame lẻ trong thư mục thành 1 dải sprite ngang cho Godot:
python tools/sprite_forge_helper.py assemble "temp_campfire_frames" "assets/buildings/campfire_and_furnace/New_Campfire.png"
```

---

## III. Lộ Trình Triển Khai Kế Tiếp Với 2 Bộ Công Cụ

1. **Giai đoạn Thú Triều Đêm 1 (Áp dụng AI Programmer):**
   - Tạo bầy sói hoang `WolfEnemy.tscn` với FSM: Tuần tra -> Đánh hơi Lửa Trại -> Lao vào vây hãm căn cứ.
2. **Giai đoạn Xây Dựng Căn Cứ (Áp dụng Gameplay & Economy Designer):**
   - Dùng Gỗ và Đá vừa thu thập được để bấm phím **B** mở menu xây dựng: Hàng rào cọc nhọn, Tường gỗ, Cổng gỗ.
3. **Giai đoạn Hoạt Ảnh Quái Vật & Boss (Áp dụng Sprite Forge):**
   - Dùng `sprite_forge_helper.py` và `sheet_qc.py` để xử lý trơn tru các sheet của Boar Titan và Timber Wolf, đồng bộ tỷ lệ và bảng màu với nhân vật chính.
