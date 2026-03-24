# Get admin token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | jq -r '.access_token')

echo "Admin token obtained"

# Get client ID for 'kong' client
CLIENT_ID=$(curl -s -X GET "http://localhost:8080/admin/realms/kong-test/clients?clientId=kong" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[0].id')

echo "Client ID: $CLIENT_ID"

# Get client secret
CLIENT_SECRET=$(curl -s -X POST "http://localhost:8080/admin/realms/kong-test/clients/$CLIENT_ID/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.value')

echo "Client Secret: $CLIENT_SECRET"
