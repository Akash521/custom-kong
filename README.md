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




  # Delete any existing pre-function plugin
PRE_ID=$(curl -s http://localhost:8001/services/your-service/plugins | jq -r '.data[] | select(.name=="pre-function") | .id')
[ ! -z "$PRE_ID" ] && curl -X DELETE http://localhost:8001/services/your-service/plugins/$PRE_ID

# Add pre-function plugin with JWT decoding and group checking
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=-- Get authorization header; local auth_header = kong.request.get_header('authorization'); if not auth_header then return kong.response.exit(401, { message = 'Missing Authorization header' }); end; -- Extract token; local token = auth_header:match('^Bearer%s+(.+)$'); if not token then return kong.response.exit(401, { message = 'Invalid Authorization header format' }); end; -- Base64 decode function; local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'); while #b % 4 ~= 0 do b = b .. '='; end; return ngx.decode_base64(b); end; -- Split JWT; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts < 2 then return kong.response.exit(401, { message = 'Invalid JWT token' }); end; -- Decode payload; local payload_json = b64_decode(parts[2]); if not payload_json then return kong.response.exit(401, { message = 'Invalid JWT payload' }); end; local payload = require('cjson').decode(payload_json); -- Extract groups; local groups = payload.groups or {}; local method = kong.request.get_method(); -- Check GET permissions; if method == 'GET' then local allowed = false; for _, group in ipairs(groups) do if group == 'Kong-Get-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, { message = 'GET access denied. Required group: Kong-Get-Users. Your groups: ' .. table.concat(groups, ', ') }); end; -- Check POST permissions; elseif method == 'POST' then local allowed = false; for _, group in ipairs(groups) do if group == 'Kong-Post-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, { message = 'POST access denied. Required group: Kong-Post-Users. Your groups: ' .. table.concat(groups, ', ') }); end; -- Method not allowed; else return kong.response.exit(405, { message = 'Method ' .. method .. ' not allowed' }); end"


✅ The Correct Setup (Both OIDC + Pre-function)
Both plugins work together:

text
Request → Pre-function (Authorization) → OIDC (Authentication) → Upstream
Why Keep OIDC?
Plugin	Role	What it does
OIDC	Authentication	Validates token signature, checks expiration, verifies with Keycloak
Pre-function	Authorization	Checks groups and HTTP method permissions
How They Work Together
Pre-function runs first - Checks if user has correct group for the HTTP method

If authorized → Passes to OIDC for authentication

OIDC validates - Verifies token is valid, not expired, signature correct

If authenticated → Passes to your upstream service

🔧 The Complete Working Configuration (Both Plugins)
bash
# Step 1: OIDC plugin (Authentication)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=oidc" \
  --data "config.client_id=kong-client" \
  --data "config.client_secret=your-secret" \
  --data "config.discovery=http://10.192.26.1:8080/realms/newsc/.well-known/openid-configuration" \
  --data "config.bearer_only=yes" \
  --data "config.ssl_verify=no"

# Step 2: Pre-function plugin (Authorization)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local auth_header = kong.request.get_header('authorization'); if not auth_header then return kong.response.exit(401, 'Missing auth header'); end; local token = auth_header:match('^Bearer%s+(.+)$'); if not token then return kong.response.exit(401, 'Invalid token'); end; local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'); while #b % 4 ~= 0 do b = b .. '='; end; return ngx.decode_base64(b); end; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts < 2 then return kong.response.exit(401, 'Invalid JWT'); end; local payload = require('cjson').decode(b64_decode(parts[2])); local groups = payload.groups or {}; local method = kong.request.get_method(); if method == 'GET' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'GET requires Kong-Get-Users'); end; elseif method == 'POST' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'POST requires Kong-Post-Users'); end; end"
📊 Why Both Are Needed
Scenario	OIDC Only	Pre-function Only	Both
Expired token	❌ Would still check groups	❌ Would allow expired token	✅ OIDC rejects expired token
Invalid signature	❌ Would still check groups	❌ Would allow fake token	✅ OIDC rejects invalid token
Wrong group for GET	✅ Could reject (if configured)	✅ Rejects	✅ Rejects
Wrong group for POST	❌ Can't differentiate	✅ Rejects	✅ Rejects
🎯 The Pre-function Plugin Doesn't Replace OIDC
Your pre-function plugin:

✅ Checks groups from JWT payload

❌ Does NOT validate token signature

❌ Does NOT check token expiration

❌ Does NOT verify with Keycloak

The OIDC plugin:

✅ Validates token signature

✅ Checks expiration

✅ Verifies with Keycloak

❌ Cannot do method-based authorization

🔄 Correct Plugin Order
The plugins should be in this order:

bash
# Check current order
curl -s http://localhost:8001/services/your-service/plugins | jq '.data[] | {name: .name, created_at: .created_at}'
If pre-function is after OIDC, that's fine. But to save CPU, you can put pre-function before OIDC (fails fast if wrong group):

text
Better order (fail fast):
Request → Pre-function (check groups) → OIDC (validate) → Upstream

Alternative order:
Request → OIDC (validate) → Pre-function (check groups) → Upstream
✅ Summary
You are doing the right thing! Keep both:

OIDC plugin = Authentication (validates token)

Pre-function plugin = Authorization (checks method + groups)

This gives you:

✅ Security (OIDC validates tokens properly)

✅ Method-based authorization (Pre-function checks GET vs POST)

✅ No consumer management (users from AD)

✅ Single route (no API changes)

Don't remove OIDC - it's doing the important security validation that your pre-function doesn't do. They work perfectly together!

