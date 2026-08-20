# Keycloak và Microsoft Entra SSO

[English](../keycloak.md)

## Dùng để làm gì?

Keycloak quản lý danh tính, role và OIDC; nó dùng Microsoft Entra ID làm identity broker cho nền tảng. OAuth2 Proxy dùng Keycloak làm OIDC confidential provider phía trước Portal.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d keycloak keycloak-entra-config keycloak-portal-client-config oauth2-proxy
```

Mở http://localhost:8180. Realm `open-source-data-platform` và các role platform đã được import.

## Azure SSO: cấu hình và ví dụ

Điền ba biến Azure trong `.env`; job `keycloak-entra-config` sẽ tạo identity provider mà không in secret. Job `keycloak-portal-client-config` cấu hình confidential client `platform-portal`, callback local, secret và token audience mapper. Trong Entra App Registration phải có redirect URI:

```text
http://localhost:8180/realms/open-source-data-platform/broker/azure-entra/endpoint
```

Khi vào `/portal/`, yêu cầu authorization có `kc_idp_hint=azure-entra`, nên người dùng đi thẳng sang Microsoft Entra thay vì phải chọn identity provider.

Với từng ứng dụng khác, hãy tạo confidential OIDC client riêng, đăng ký đúng redirect URI, map Entra group/role và cấu hình authorization ngay trong ứng dụng. SSO Portal không tự tạo session ở sản phẩm khác.

Local Lab chủ đích dùng HTTP và `localhost`; trước khi chia sẻ/running production cần đổi sang HTTPS và DNS public.
