 curl -i -X GET https://kong-mcore.newsc.mil.ae/api/health      -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJ0MmRpQnNhSDdQUXlMUzlRcE9fWkZwcUVGd3BEcS0tNDdPa05tSjJ2eXA4In0.eyJleHAiOjE3NzUyNDE1NDMsImlhdCI6MTc3NTI0MTI0MywianRpIjoib25ydHJvOmNlMmJkNjc4LTNhOTUtNDFmOC1kZTFmLWQ4MDRhNzk3MDU1MyIsImlzcyI6Imh0dHA6Ly8xMC4xOTIuMjYuMTo4MDgwL3JlYWxtcy9uZXdzYyIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiI3MDY4NTk4MC0xYTg1LTRhNzktOWYwOS1lNGNhNGFhYjBjMzQiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJrb25nLWNsaWVudCIsInNpZCI6InM0Ym1xODRhTkxPT0FzSFBfY1VhLTZITyIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cHM6Ly9rb25nLW1jb3JlLm5ld3NjLm1pbC5hZSJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiIsImRlZmF1bHQtcm9sZXMtbmV3c2MiXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6InByb2ZpbGUgZW1haWwiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsIm5hbWUiOiJrb25nMSIsImdyb3VwcyI6WyJLb25nLUdldC1Vc2VycyJdLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJrb25nMSIsImdpdmVuX25hbWUiOiJrb25nMSJ9.Eu2h50cqyfb7Lk06rQnx__NaLcrSe0redJljIeSAoBqBAT8ctM8i5P-x1vrSJm4u_uVu6QD8KH7VzdzfVRHvjjR8renPw-owsAEukXq8xRi0rTV1VTCJcKm-GCJmU0qwvQuLrsYk2lItgUkYJCSQUiFIWhnN6zYDWvW0WP1B27fI1OVCkPIGim5jE0rtLhH8KDWkRDwoydLVhgFmQqNij4Ex16T7DMcMehdeEjwOfUB9h3L6we8mm0CLF3bJfhsg0X9mdzwmgEDWCnfiaKWKRFwn0TO87BXIlsdvhXOknEdqQYK1ek20Syu0Ij8vf0hCps6b5CbcDL5R91ZGWOUkew"
HTTP/1.1 302 Moved Temporarily
Server: nginx/1.26.3
Date: Fri, 03 Apr 2026 18:35:26 GMT
Content-Type: text/html
Content-Length: 110
Connection: keep-alive
Set-Cookie: session=QjACoIBtWnYG_u-hYQxLUA|1775244926|Q27pt6S_XaXcHxKHSJCu_tOego50zljg9JNMtmQf7bqAQKF2R3LlPEwABgrI4RK3eTyit6TavgScNpUsR7ZkUrsch5uAefaJfIwgCCMtgjmy-CNYTDpIuTWS-9IEBxtikzonoq8uEV35nVIW_zAFKweZq_ld1yjRdEIpQ_7ddA2yHF-EXxxxUXd-vYa7UlxrrDAX3vgI2lXWTZGuB_S4gA|OeMiMmQFan0-_kUm9Q6ah_ZebKY; Path=/; SameSite=Lax; HttpOnly
Cache-Control: no-cache, no-store, max-age=0
Location: http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/auth?redirect_uri=https%3A%2F%2Fkong-mcore.newsc.mil.ae%2Fapi%2Fhealth%2F&response_type=code&client_id=kong-client&scope=openid&nonce=2189e120dc16ad6e8d4f3a531556f787&state=b9336527704f15be83995c59e4754241
X-Kong-Response-Latency: 5
X-Kong-Request-Id: 06850473f6127f223ec1a406e9da6919

<html>
<head><title>302 Found</title></head>
<body>
<center><h1>302 Found</h1></center>
</body>
</html>

{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "t2diBsaH7PQyLS9QpO_ZFpqEFwpDq--47OkNmJ2vyp8"
}

{
  "exp": 1775241543,
  "iat": 1775241243,
  "jti": "onrtro:ce2bd678-3a95-41f8-de1f-d804a7970553",
  "iss": "http://10.192.26.1:8080/realms/newsc",
  "aud": "account",
  "sub": "70685980-1a85-4a79-9f09-e4ca4aab0c34",
  "typ": "Bearer",
  "azp": "kong-client",
  "sid": "s4bmq84aNLOOAsHP_cUa-6HO",
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
  "scope": "profile email",
  "email_verified": false,
  "name": "kong1",
  "groups": [
    "Kong-Get-Users"
  ],
  "preferred_username": "kong1",
  "given_name": "kong1"
}
