curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=local groups = kong.ctx.shared.authenticated_groups or {}; local method = kong.request.get_method(); local allowed = false; if method == 'GET' then for _, g in ipairs(groups) do if g == 'Kong-Get-Users' then allowed = true; break; end; end; elseif method == 'POST' then for _, g in ipairs(groups) do if g == 'Kong-Post-Users' then allowed = true; break; end; end; end; if not allowed then kong.response.exit(403, { message = 'Access denied: insufficient permissions for ' .. method }); end"


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
