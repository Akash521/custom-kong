#!/bin/bash

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | jq -r '.access_token')

# Create realm
curl -X POST http://localhost:8080/admin/realms \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "kong-test",
    "enabled": true
  }'

# Create client
curl -X POST http://localhost:8080/admin/realms/kong-test/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "kong",
    "enabled": true,
    "publicClient": false,
    "redirectUris": ["http://localhost:8000/*"],
    "directAccessGrantsEnabled": true
  }'

# Get client secret
CLIENT_ID=$(curl -s -X GET "http://localhost:8080/admin/realms/kong-test/clients?clientId=kong" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')

CLIENT_SECRET=$(curl -s -X POST "http://localhost:8080/admin/realms/kong-test/clients/$CLIENT_ID/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.value')

# Create user
curl -X POST http://localhost:8080/admin/realms/kong-test/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "enabled": true,
    "credentials": [{
      "type": "password",
      "value": "test123",
      "temporary": false
    }]
  }'

echo ""
echo "=========================================="
echo "Keycloak Setup Complete!"
echo "=========================================="
echo "URL: http://localhost:8080"
echo "Admin: admin / admin"
echo "Realm: kong-test"
echo "Client ID: kong"
echo "Client Secret: $CLIENT_SECRET"
echo "Test User: testuser / test123"
echo "=========================================="
echo ""
echo "OIDC Discovery URL:"
echo "http://localhost:8080/realms/kong-test/.well-known/openid-configuration"
