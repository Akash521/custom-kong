# Recreate with ALL required parameters for bearer mode
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=oidc" \
  --data "config.client_id=kong-client" \
  --data "config.client_secret=your-secret" \
  --data "config.discovery=http://10.192.26.1:8080/realms/newsc/.well-known/openid-configuration" \
  --data "config.bearer_only=yes" \
  --data "config.ssl_verify=no" \
  --data "config.realm=newsc" \
  --data "config.introspection_endpoint=http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/token/introspect" \
  --data "config.introspection_endpoint_auth_method=client_secret_basic" \
  --data "config.groups_claim=groups"

  # Check if bearer_only is actually set
curl -s http://localhost:8001/services/your-service/plugins | jq '.data[] | select(.name=="oidc") | .config.bearer_only'

# Test introspection from your Kong machine/container
curl -v -X POST http://10.192.26.1:8080/realms/newsc/protocol/openid-connect/token/introspect \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=kong-client" \
  -d "client_secret=your-secret" \
  -d "token=YOUR_TOKEN_HERE"

  curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=pre-function" \
  --data "config.access=kong.log.err('=== DEBUG ==='); kong.log.err('Authorization header: ', kong.request.get_header('authorization')); kong.log.err('==============');"


  # Delete OIDC plugin
OIDC_ID=$(curl -s http://localhost:8001/services/your-service/plugins | jq -r '.data[] | select(.name=="oidc") | .id')
curl -X DELETE http://localhost:8001/services/your-service/plugins/$OIDC_ID

# Configure OIDC with bearer_jwt_auth_enable
curl -X POST http://localhost:8001/services/your-service/plugins \
  --data "name=oidc" \
  --data "config.client_id=kong-client" \
  --data "config.client_secret=your-secret" \
  --data "config.discovery=http://10.192.26.1:8080/realms/newsc/.well-known/openid-configuration" \
  --data "config.bearer_only=yes" \
  --data "config.bearer_jwt_auth_enable=yes" \
  --data "config.ssl_verify=no" \
  --data "config.groups_claim=groups"
