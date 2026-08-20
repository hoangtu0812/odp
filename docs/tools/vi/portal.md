# Loop Data Lab Portal

[English](../portal.md)

## Dùng để làm gì?

Trang gốc công khai là landing page **Loop Data Lab (LDL)**: giao diện theo phong cách technical lab, animation mô phỏng thiết bị/phòng lab và nút **Continue with Azure Entra**. Sau xác thực, Portal dùng cùng phong cách giao diện, có logo ứng dụng, link truy cập và health status.

`/` là công khai; `/portal/` chỉ mở sau khi đăng nhập Azure Entra thông qua Keycloak và OAuth2 Proxy. Khi callback thành công, trình duyệt có một session cookie local dạng HTTP-only. Nút Sign out trên Portal xoá session này.

## Khởi động

```powershell
.\scripts\start-local-lab.ps1 -SkipAirbyte -SkipOpenMetadata
```

Script kiểm tra ba biến Azure Entra và các OIDC secret của Portal trước khi khởi động. Chỉ dùng `-SkipPortal` khi chủ động chạy các dịch vụ Local Lab còn lại mà không dùng cổng vào Azure.

Mở http://localhost:3000, chọn **Continue with Azure Entra**. Đăng nhập xong, trình duyệt quay lại `http://localhost:3000/portal/`.

Landing UI nằm ở `frontend/portal/index.html` và `landing.css`; Portal sau đăng nhập nằm ở `frontend/portal/portal/`. OIDC gateway và các health route ở `docker/portal/default.conf`.

## Ranh giới SSO Local Lab

Azure session hiện bảo vệ chính Portal. Các ứng dụng được link vẫn dùng trang đăng nhập local của chính chúng cho đến khi cấu hình native OIDC với Keycloak. Vì vậy giao diện không tạo cảm giác sai rằng toàn bộ ứng dụng đã SSO.

## Thêm ứng dụng mới

1. Thêm card có logo, `alt`, link và mô tả ngắn vào `index.html`.
2. Nếu service có readiness endpoint ổn định, thêm `data-health` và proxy route.
3. Build lại Portal, dừng service đích để bảo đảm card báo **Chưa sẵn sàng**.

4. Với ứng dụng web mới, cấu hình native OIDC qua Keycloak trước khi coi là đã SSO.
5. Health status chỉ tiện cho vận hành, không phải lớp authorization.
