


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

# Delete all plugins from the service
curl -s http://localhost:8001/services/your-service/plugins | jq -r '.data[].id' | while read id; do
    curl -X DELETE http://localhost:8001/services/your-service/plugins/$id
done

# Step 1: Add pre-function FIRST (so it runs before OIDC)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local auth_header = kong.request.get_header('authorization'); if not auth_header then return kong.response.exit(401, 'Missing auth header'); end; local token = auth_header:match('^Bearer%s+(.+)$'); if not token then return kong.response.exit(401, 'Invalid token'); end; local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'); while #b % 4 ~= 0 do b = b .. '='; end; return ngx.decode_base64(b); end; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts < 2 then return kong.response.exit(401, 'Invalid JWT'); end; local payload = require('cjson').decode(b64_decode(parts[2])); local groups = payload.groups or {}; local method = kong.request.get_method(); if method == 'GET' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'GET requires Kong-Get-Users'); end; elseif method == 'POST' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'POST requires Kong-Post-Users'); end; end"

# Step 2: Add OIDC SECOND (runs after pre-function)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=oidc" \
  --data "config.client_id=kong-client" \
  --data "config.client_secret=your-secret" \
  --data "config.discovery=http://10.192.26.1:8080/realms/newsc/.well-known/openid-configuration" \
  --data "config.bearer_only=yes" \
  --data "config.ssl_verify=no"
