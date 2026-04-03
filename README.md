# 1. Configure OIDC plugin (bearer-only mode)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=oidc" \
  --data "config.client_id=kong-client" \
  --data "config.client_secret=your-secret" \
  --data "config.discovery=http://10.192.26.1:8080/realms/newsc/.well-known/openid-configuration" \
  --data "config.bearer_only=yes" \
  --data "config.introspection_endpoint=http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/token/introspect" \
  --data "config.ssl_verify=no"

# 2. Add pre-function plugin (runs AFTER OIDC to use authenticated user)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=-- After OIDC auth, get user info; local credential = kong.ctx.shared.authenticated_credential; local userinfo = kong.ctx.shared.userinfo or {}; local groups = userinfo.groups or (credential and credential.groups) or {}; -- If groups not found, try decoding JWT; if not groups or #groups == 0 then local auth_header = kong.request.get_header('authorization'); if auth_header then local token = auth_header:match('^Bearer%s+(.+)$'); if token then local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'); while #b % 4 ~= 0 do b = b .. '='; end; return ngx.decode_base64(b); end; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts >= 2 then local payload_json = b64_decode(parts[2]); if payload_json then local payload = require('cjson').decode(payload_json); groups = payload.groups or {}; end; end; end; end; end; -- Authorization logic; local method = kong.request.get_method(); if method == 'GET' then for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then return; end; end; return kong.response.exit(403, { message = 'GET requires Kong-Get-Users group' }); elseif method == 'POST' then for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then return; end; end; return kong.response.exit(403, { message = 'POST requires Kong-Post-Users group' }); end"



# Generate token for kong1 user
curl -X POST http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=kong-client" \
  -d "client_secret=your-secret-here" \
  -d "username=kong1" \
  -d "password=kong1-password" \
  -d "grant_type=password"

# Generate token for kong2 user
curl -X POST http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=kong-client" \
  -d "client_secret=your-secret-here" \
  -d "username=kong2" \
  -d "password=kong2-password" \
  -d "grant_type=password"


  2026-04-03 13:03:27,753 WARN  [org.keycloak.events] (executor-thread-433) type="INTROSPECT_TOKEN_ERROR", realmId="4fd3172e-3a12-43e3-982b-0a0018f1e7f3", realmName="newsc", clientId="kong-client", userId="null", ipAddress="10.192.26.13", error="invalid_token", reason="Access token JWT check failed", client_auth_method="client-secret"

