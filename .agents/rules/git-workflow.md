# Git Auto-Commit & Workflow Rules

## Mandatory Rule:
Mỗi khi hoàn thành một tính năng, một module hoặc fix một lỗi trong dự án `LamTinh_HoangCoKy`:
1. **Kiểm thử trước khi commit:** Chạy kiểm tra cú pháp hoặc test headless (`--headless`) để đảm bảo không có lỗi runtime/compile error.
2. **Git Add & Commit:**
   - Thực hiện `git add .`
   - Tạo commit message bằng tiếng Anh hoặc tiếng Việt mô tả rõ ràng, súc tích thay đổi (vd: `feat: add crafting system`, `fix: character disappearance`).
3. **Git Push:**
   - Đẩy trực tiếp lên nhánh chính: `git push origin main`.
4. **Báo cáo:**
   - Thông báo ngắn gọn mã commit hash cho người dùng.
