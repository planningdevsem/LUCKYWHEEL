# BETMA LUCKY WHEEL

Website vòng quay may mắn cho sự kiện sinh viên (1 file `index.html`, không cần build).

## Chạy thử
Mở `index.html` bằng trình duyệt. Khi chưa điền Supabase, web chạy chế độ DEMO (dữ liệu lưu trên trình duyệt).

## Chạy thật với Supabase
1. Tạo project Supabase, chạy toàn bộ `schema.sql` trong SQL Editor.
2. Tạo tài khoản admin trong Authentication và tắt đăng ký tự do (disable sign-ups).
3. Mở `index.html`, điền `SUPABASE_URL` và `SUPABASE_KEY` (anon key) ở đầu thẻ `<script>`.

## Trang Admin
Bấm nút ⚙ ở góc phải header, hoặc thêm `#admin` vào địa chỉ.

## Đăng lên GitHub Pages
Settings > Pages > Deploy from a branch > `main` / root.
