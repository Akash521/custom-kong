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


# 2. Add pre-function FIRST (to check groups before OIDC processes token)
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local auth_header = kong.request.get_header('authorization'); if not auth_header then return kong.response.exit(401, 'Missing authorization header'); end; local token = auth_header:match('^Bearer%s+(.+)$'); if not token then return kong.response.exit(401, 'Invalid authorization header'); end; local function b64_decode(data) local b = data:gsub('%-', '+'):gsub('_', '/'):gsub(' ', ''); local remainder = #b % 4; if remainder > 0 then b = b .. string.rep('=', 4 - remainder); end; return ngx.decode_base64(b); end; local parts = {}; for part in string.gmatch(token, '[^.]+') do table.insert(parts, part); end; if #parts < 2 then return kong.response.exit(401, 'Invalid JWT token'); end; local payload_json = b64_decode(parts[2]); if not payload_json then return kong.response.exit(401, 'Invalid JWT payload'); end; local payload = require('cjson').decode(payload_json); local groups = payload.groups or {}; local method = kong.request.get_method(); if method == 'GET' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'GET access denied. Required group: Kong-Get-Users. Your groups: ' .. table.concat(groups, ', ')); end; elseif method == 'POST' then local allowed = false; for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then allowed = true; break; end; end; if not allowed then return kong.response.exit(403, 'POST access denied. Required group: Kong-Post-Users. Your groups: ' .. table.concat(groups, ', ')); end; end"




  # Add pre-function with simplified JWT decoding
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local function get_groups() local auth = kong.request.get_header('authorization'); if not auth then return {}; end; local token = auth:match('^Bearer (.+)$'); if not token then return {}; end; local parts = {}; for part in token:gmatch('[^.]+') do parts[#parts+1] = part; end; if #parts < 2 then return {}; end; local payload = parts[2]:gsub('%-', '+'):gsub('_', '/'); while #payload % 4 ~= 0 do payload = payload .. '='; end; local json = ngx.decode_base64(payload); if not json then return {}; end; local data = require('cjson').decode(json); return data.groups or {}; end; local groups = get_groups(); local method = kong.request.get_method(); if method == 'GET' and not groups['Kong-Get-Users'] then return kong.response.exit(403, 'Kong-Get-Users group required for GET'); end; if method == 'POST' and not groups['Kong-Post-Users'] then return kong.response.exit(403, 'Kong-Post-Users group required for POST'); end"




  # Add temporary debug plugin
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local headers = kong.request.get_headers(); kong.log.err('=== ALL HEADERS ==='); for k, v in pairs(headers) do kong.log.err(k, ': ', v); end; kong.log.err('=================='); local auth = kong.request.get_header('authorization'); kong.log.err('Authorization header: ', auth or 'NOT FOUND');"



#output

2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] === ALL HEADERS ===, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] user-agent: curl/8.12.1, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] host: kong-mcore.newsc.mil.ae, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] accept: */*, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] x-real-ip: 10.192.26.13, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] x-forwarded-for: 10.192.26.13, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJ0MmRpQnNhSDdQUXlMUzlRcE9fWkZwcUVGd3BEcS0tNDdPa05tSjJ2eXA4In0.eyJleHAiOjE3NzUxMjgyOTMsImlhdCI6MTc3NTEyNzk5MywianRpIjoib25ydHJvOjZhMmY2MjEwLTUyYjUtYjllOC00MzQ5LTE4MmExNWYxZjVlNSIsImlzcyI6Imh0dHA6Ly8xMC4xOTIuMjYuMTo4MDgwL3JlYWxtcy9uZXdzYyIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiI3MDY4NTk4MC0xYTg1LTRhNzktOWYwOS1lNGNhNGFhYjBjMzQiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJrb25nLWNsaWVudCIsInNpZCI6Il81RE5wTWNMbk9pMmpWV0ZXTDYxYk54biIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cHM6Ly9rb25nLW1jb3JlLm5ld3NjLm1pbC5hZSJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiIsImRlZmF1bHQtcm9sZXMtbmV3c2MiXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJuYW1lIjoia29uZzEiLCJncm91cHMiOlsiS29uZy1HZXQtVXNlcnMiXSwicHJlZmVycmVkX3VzZXJuYW1lIjoia29uZzEiLCJnaXZlbl9uYW1lIjoia29uZzEifQ.XThMoCNogGBCv4fPmnP5TWmtsbyWF9udNNBfI8vVEsk43E0fn_-EyNKRIgA6SBTWgdwpyg3sYM34v34CytmSTPrKvesSb3HnHAtIbu4aOxmpFQIWK7JO9NBsTa3acRn68rhjHt7NZbBPOKBP1hKDDqvYAeYQZepO09xKsE9IXKfoYrCymzcRYnILmAVn1yk_H9H9uZDO87pJlNLlH4XYHOZxdeN5xpoIgdmj1K0EItanyIZaSQYxOQAe-icEyMbJiNTHPbuZjjlPHu_edBdTPZhsWlJFRkL6i33Nsb-dhYSMFzNyzJvAYpJemjA-dCcClUafqpM5z4DSKMPkjdu1Ng, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] connection: close, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] x-forwarded-proto: https, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] ==================, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"
2026/04/03 12:26:17 [error] 1322#0: *134630 [kong] [string "local headers = kong.request.get_headers(); k..."]:1 [pre-function] Authorization header: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJ0MmRpQnNhSDdQUXlMUzlRcE9fWkZwcUVGd3BEcS0tNDdPa05tSjJ2eXA4In0.eyJleHAiOjE3NzUxMjgyOTMsImlhdCI6MTc3NTEyNzk5MywianRpIjoib25ydHJvOjZhMmY2MjEwLTUyYjUtYjllOC00MzQ5LTE4MmExNWYxZjVlNSIsImlzcyI6Imh0dHA6Ly8xMC4xOTIuMjYuMTo4MDgwL3JlYWxtcy9uZXdzYyIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiI3MDY4NTk4MC0xYTg1LTRhNzktOWYwOS1lNGNhNGFhYjBjMzQiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJrb25nLWNsaWVudCIsInNpZCI6Il81RE5wTWNMbk9pMmpWV0ZXTDYxYk54biIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cHM6Ly9rb25nLW1jb3JlLm5ld3NjLm1pbC5hZSJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiIsImRlZmF1bHQtcm9sZXMtbmV3c2MiXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJuYW1lIjoia29uZzEiLCJncm91cHMiOlsiS29uZy1HZXQtVXNlcnMiXSwicHJlZmVycmVkX3VzZXJuYW1lIjoia29uZzEiLCJnaXZlbl9uYW1lIjoia29uZzEifQ.XThMoCNogGBCv4fPmnP5TWmtsbyWF9udNNBfI8vVEsk43E0fn_-EyNKRIgA6SBTWgdwpyg3sYM34v34CytmSTPrKvesSb3HnHAtIbu4aOxmpFQIWK7JO9NBsTa3acRn68rhjHt7NZbBPOKBP1hKDDqvYAeYQZepO09xKsE9IXKfoYrCymzcRYnILmAVn1yk_H9H9uZDO87pJlNLlH4XYHOZxdeN5xpoIgdmj1K0EItanyIZaSQYxOQAe-icEyMbJiNTHPbuZjjlPHu_edBdTPZhsWlJFRkL6i33Nsb-dhYSMFzNyzJvAYpJemjA-dCcClUafqpM5z4DSKMPkjdu1Ng, client: 172.20.0.1, server: kong, request: "GET /api/health HTTP/1.0", host: "kong-mcore.newsc.mil.ae", request_id: "0cf8872326c6a82f26aa3e13224f943c"                     172.20.0.1 - - [03/Apr/2026:12:26:17 +0000] "GET /api/health HTTP/1.0" 302 110 "-" "curl/8.12.1" kong_request_id: "0cf8872326c6a82f26aa3e13224f943c"  

