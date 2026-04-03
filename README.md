{
  "exp": 1775128293,
  "iat": 1775127993,
  "jti": "onrtro:6a2f6210-52b5-b9e8-4349-182a15f1f5e5",
  "iss": "http://10.192.26.1:8080/realms/newsc",
  "aud": "account",
  "sub": "70685980-1a85-4a79-9f09-e4ca4aab0c34",
  "typ": "Bearer",
  "azp": "kong-client",
  "sid": "_5DNpMcLnOi2jVWFWL61bNxn",
  "acr": "1",
  "allowed-origins": [
    "https://kong-mcore.newsc.mil.ae"
  ],
  "realm_access": {
    "roles": [
      "offline_access",
      "uma_authorization",
      "default-roles-newsc"
    ]
  },
  "resource_access": {
    "account": {
      "roles": [
        "manage-account",
        "manage-account-links",
        "view-profile"
      ]
    }
  },
  "scope": "openid profile email",
  "email_verified": false,
  "name": "kong1",
  "groups": [
    "Kong-Get-Users"
  ],
  "preferred_username": "kong1",
  "given_name": "kong1"
}


curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local auth_header = kong.request.get_header('authorization'); if not auth_header then return kong.response.exit(401, 'Missing authorization header'); end; local token = auth_header:match('^Bearer%s+(.+)$'); if not token then return kong.response.exit(401, 'Invalid authorization header'); end; local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'):gsub(' ', ''); local remainder = #b % 4; if remainder > 0 then b = b .. string.rep('=', 4 - remainder); end; return ngx.decode_base64(b); end; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts < 2 then return kong.response.exit(401, 'Invalid JWT token'); end; local payload_json = b64_decode(parts[2]); if not payload_json then return kong.response.exit(401, 'Invalid JWT payload'); end; local payload = require('cjson').decode(payload_json); local groups = payload.groups or {}; local method = kong.request.get_method(); if method == 'GET' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'GET access denied. Required group: Kong-Get-Users. Your groups: ' .. table.concat(groups, ', ')); end; elseif method == 'POST' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'POST access denied. Required group: Kong-Post-Users. Your groups: ' .. table.concat(groups, ', ')); end; end"




  # Add pre-function with simplified JWT decoding
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local function get_groups() local auth = kong.request.get_header('authorization'); if not auth then return {}; end; local token = auth:match('^Bearer (.+)$'); if not token then return {}; end; local parts = {}; for part in token:gmatch('[^.]+') do parts[#parts+1] = part; end; if #parts < 2 then return {}; end; local payload = parts[2]:gsub('%-', '+'):gsub('_', '/'); while #payload % 4 ~= 0 do payload = payload .. '='; end; local json = ngx.decode_base64(payload); if not json then return {}; end; local data = require('cjson').decode(json); return data.groups or {}; end; local groups = get_groups(); local method = kong.request.get_method(); if method == 'GET' and not groups['Kong-Get-Users'] then return kong.response.exit(403, 'Kong-Get-Users group required for GET'); end; if method == 'POST' and not groups['Kong-Post-Users'] then return kong.response.exit(403, 'Kong-Post-Users group required for POST'); end"
