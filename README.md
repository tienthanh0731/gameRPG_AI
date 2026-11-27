# LAM TINH: HOANG CỔ KÝ (BLUE STAR: PRIMORDIAL SURVIVAL)

Tựa game 2D Top-Down Sinh Tồn Xuyên Không & Thủ Thành Đa Người Chơi (Multiplayer Survival & Base Defense RPG).

---

## 📂 CẤU TRÚC TÀI LIỆU DỰ ÁN

Toàn bộ tài liệu thiết kế và đặc tả kỹ thuật chi tiết được lưu trữ trong thư mục `docs/`:

1. **[GDD_Hoang_Co_Ky.md](file:///d:/gameRPG_AI/docs/GDD_Hoang_Co_Ky.md):**
   * **Bối cảnh & Cốt truyện:** Toàn bộ nhân loại Lam Tinh xuyên không vào Hoang Cổ Giới, khởi đầu với 1 nhà gỗ đơn sơ và thiên phú ngẫu nhiên.
   * **Vòng lặp gameplay:** Ngày (Khai thác, khám phá phó bản) $\rightarrow$ Hoàng hôn (Gia cố, tinh luyện) $\rightarrow$ Đêm (Thú triều tấn công, thử thách độ bền căn cứ) $\rightarrow$ Rạng đông (Kết toán điểm sinh tồn, nâng cấp).
   * **Cơ chế Sinh tồn & Thân nhiệt:** HP, Đói, Khát, Thể lực, Hạ thân nhiệt ban đêm, Say nắng buổi trưa.
   * **Hệ thống Căn cứ & 5 Bậc Nguyên Liệu:** Nhà gỗ sơ khai $\rightarrow$ Nhà kiên cố $\rightarrow$ Thành trì đá $\rightarrow$ Pháo đài hắc thiết $\rightarrow$ Động phủ thần thoại đa chiều.
   * **Cơ chế Chế tạo Tổ hợp:** Phối tỷ lệ Gỗ, Đá, Sắt và phụ gia để đạt phẩm cấp cao nhất.
   * **Sàn Giao Dịch Toàn Cầu:** Kinh tế liên thông, chia biome khan hiếm để thúc đẩy khám phá phó bản.
   * **Kiến trúc Kỹ thuật:** Authoritative Server (Go/Rust), Client Godot 4 2D, PostgreSQL, Redis, WebSockets/ENet.

2. **[DATABASE_HE_THONG_VAT_PHAM_KY_NANG.md](file:///d:/gameRPG_AI/docs/DATABASE_HE_THONG_VAT_PHAM_KY_NANG.md):**
   * **Thiên Phú Toàn Diện (F $\rightarrow$ SSS):** 6 hệ (Chiến đấu, Sinh hoạt, Sinh tồn, Nguyên tố, Không gian, Triệu hồi).
   * **Sơ Đồ Phím Bấm & Combat:** WASD di chuyển, Combo 3 nhịp chuột trái, Tụ lực phá giáp, Parry khiên chuột phải, Lướt né I-Frames, Phím chiêu thức Q, E, R.
   * **Cây Kỹ Năng (Skill Tree):** Kỹ năng cận chiến, tầm xa, pháp thuật, và kỹ năng ẩn kích hoạt qua hành động thực tế (đốn củi ngộ chiêu, đào khoáng ngộ giáp).
   * **Danh Mục Tài Nguyên:** 5 nhóm chính (Lâm sản, Thạch & khoáng sản, Bộ phận quái thú, Thảo dược lương thực, Tinh thể năng lượng).
   * **Hệ Thống Phẩm Cấp:** Phàm phẩm (Trắng) $\rightarrow$ Tinh xảo (Lục) $\rightarrow$ Trân quý (Lam) $\rightarrow$ Cực phẩm (Tím) $\rightarrow$ Huyền thoại (Cam) $\rightarrow$ Thần thoại (Đỏ).
   * **Kho Vũ Khí & Trang Bị:** Kiếm 1 tay + Khiên, Trọng kiếm 2 tay, Trường thương, Song đao, Cung thần, Nỏ cơ giới, Pháp trượng nguyên tố.
   * **Bộ Công Cụ & Đồ Tiêu Hao:** Rìu, cuốc, búa sửa chữa, cần câu cá, thịt nướng, băng gạc, đuốc, phù chú.

---

## 🧪 PHASE 1 (MVP singleplayer local) — cách chạy & test

**Autoload:** `EventBus` (tín hiệu) → `SaveSystem` (JSON local, 2 tầng Account/Character) → `ServerSim` (vai trò "server authoritative" giả lập: roll thiên phú, reroll, xếp hạng %, BXH phân trang) → `GameState` (công thức + trạng thái phiên chơi). Phase 2 chỉ cần thay phần thân của `ServerSim`/`SaveSystem` bằng request mạng.

**Phím:** WASD di chuyển · Space lướt · 1/2/3 Rìu/Cuốc/Kiếm · Chuột trái hành động · B xây dựng (4/5/6) · E vào phó bản/mở cổng · F ăn thịt · T dùng Đan Reroll · L bảng xếp hạng.

**Test tự động (headless):**
```
godot.exe --headless --path . res://tests/test_phase1.tscn    # logic: M(d)/W(d)/N(d), tỉ lệ roll, xếp hạng, permadeath atomic, journal
godot.exe --headless --path . res://tests/smoke_scenes.tscn   # luồng: Main → đêm → tổng kết → phó bản → chết
```
Test tự sao lưu/khôi phục save thật trong `user://`.

**Quy ước đã chọn khi đặc tả chưa rõ:**
- Ngày 1-5 "chưa có thú triều thật" → chỉ có *đợt trinh sát* = max(2, W(d)/3); từ ngày 6 dùng đủ W(d).
- Top 1%/10%/50% trong bản singleplayer → xếp hạng với 199 người chơi giả lập (cố định theo account + ngày).
- "d" trong M(d) = ngày sống sót của nhân vật. Đan Reroll: tối đa 1 lần / nhân vật.
- Thiên phú được roll 1 lần và lưu ngay vào Account (`pending_talent`) → thoát game/bấm lại không đổi được.
