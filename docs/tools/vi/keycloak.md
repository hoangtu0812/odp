# Keycloak và Microsoft Entra SSO

[English](../keycloak.md)

## Dùng để làm gì?

Keycloak quản lý danh tính, role và OIDC; nó dùng Microsoft Entra ID làm identity broker cho nền tảng.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile governance up -d keycloak keycloak-entra-config
```

Mở http://localhost:8180. Realm `open-source-data-platform` và các role platform đã được import.

## Azure SSO: cấu hình và ví dụ

Điền ba biến Azure trong `.env`; job `keycloak-entra-config` sẽ tạo identity provider mà không in secret. Trong Entra App Registration phải có redirect URI:

```text
http://localhost:8180/realms/open-source-data-platform/broker/azure-entra/endpoint
```

Tạo OIDC client cho từng ứng dụng, đăng ký redirect URI của ứng dụng và map Entra group/role sang realm role Keycloak. Portal Local Lab chỉ là launcher, chưa phải auth gateway.
