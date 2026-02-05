# Cloud IAM Configuration Reference

## Elasticsearch Realm Configuration

Add to `elasticsearch.yml`:

```yaml
xpack.security.authc.realms.cloud_iam.iam1:
  order: 0
  auth.mode: aliyun
  auth.signed_header: X-ES-IAM-Signed
  auth.allowed_time_skew: 5m
  auth.allow_assumed_role: true
  replay.nonce_ttl: 5m
  replay.nonce_max_entries: 50000
  iam.endpoint: https://sts.aliyuncs.com
  cache.ttl: 5m
  cache.negative_ttl: 20s
```

**Key settings:**
- `order`: Lower values = higher priority
- `auth.mode`: Must be `aliyun` for Aliyun RAM
- `auth.signed_header`: Header name for signed requests
- `auth.allow_assumed_role`: Allow STS assumed role sessions
- `auth.allowed_time_skew`: Clock skew tolerance

## Kibana Provider Configuration

Add to `kibana.yml`:

```yaml
xpack.security.authc.providers:
  cloud_iam.iam1:
    enabled: true
    showInSelector: true
    order: 0
    realm: "iam1"
    description: "Log in with Aliyun IAM"
```

**Important:**
- `realm` must match ES realm name (`iam1`)
- `order` should match ES realm priority
- `showInSelector` displays provider on login page

## Role Mapping Examples

### Map all Aliyun users to superuser:

```bash
curl -u elastic:PASSWORD -X PUT "http://localhost:9200/_security/role_mapping/aliyun_superuser" \
  -H "Content-Type: application/json" -d '{
    "enabled": true,
    "roles": ["superuser"],
    "rules": {
      "any": [
        {"field": {"metadata.cloud_principal_type": "user"}},
        {"field": {"metadata.cloud_principal_type": "assumed_role"}}
      ]
    }
  }'
```

### Map to custom role with specific permissions:

```bash
curl -u elastic:PASSWORD -X PUT "http://localhost:9200/_security/role/cloud_iam_full" \
  -H "Content-Type: application/json" -d '{
    "cluster": ["monitor"],
    "indices": [{"names": ["*"], "privileges": ["all"]}],
    "applications": [{
      "application": "kibana-.kibana",
      "privileges": ["all"],
      "resources": ["*"]
    }]
  }'

curl -u elastic:PASSWORD -X PUT "http://localhost:9200/_security/role_mapping/aliyun_full" \
  -H "Content-Type: application/json" -d '{
    "enabled": true,
    "roles": ["cloud_iam_full"],
    "rules": {
      "field": {"metadata.cloud_principal_type": "user"}
    }
  }'
```

### Map by ARN pattern:

```bash
curl -u elastic:PASSWORD -X PUT "http://localhost:9200/_security/role_mapping/arn_pattern" \
  -H "Content-Type: application/json" -d '{
    "enabled": true,
    "roles": ["kibana_admin"],
    "rules": {
      "any": [
        {"field": {"metadata.cloud_arn": "*:role/Admin*"}},
        {"field": {"metadata.cloud_user_id": "specific-user-id"}}
      ]
    }
  }'
```

## Authentication Metadata

When Cloud IAM authenticates successfully, the following metadata is available:

- `metadata.cloud_arn`: Full ARN of the authenticated identity
- `metadata.cloud_account`: Aliyun account ID
- `metadata.cloud_principal_type`: `user`, `role`, or `assumed_role`
- `metadata.cloud_user_id`: User ID or role ID

Use these in role mapping rules for fine-grained access control.

## Troubleshooting Scenarios

### Authentication fails with "invalid credentials"

**Check:**
1. RAM credentials are valid
2. Access key has not expired
3. User has necessary permissions (RAM:AssumeRole if using roles)

**Test:**
```bash
python3 /path/to/aliyun_sts_sign.py --access-key-id $RAM_AK --access-key-secret $RAM_SK
```

### "Realm not found" error

**Check:**
1. Realm name in Kibana config matches ES config exactly
2. Cloud IAM plugin is installed in ES
3. ES has been restarted after plugin installation

**Verify:**
```bash
curl -u elastic:PASSWORD "http://localhost:9200/_cat/aliases/.security*?v"
```

### Role mapping not applying

**Check:**
1. Role mapping is enabled
2. Rules match user metadata
3. Role exists and is valid

**Debug:**
```bash
curl -u elastic:PASSWORD -H "X-ES-IAM-Signed: $SIGNED" \
  "http://localhost:9200/_security/_authenticate" | jq
```

### CORS errors in browser

**Solution:**
Add to `elasticsearch.yml`:
```yaml
http.cors.enabled: true
http.cors.allow-origin: "*"
http.cors.allow-headers: "Authorization,X-ES-IAM-Signed"
```

### Time skew errors

**Solution:**
Increase `auth.allowed_time_skew` in realm config, or synchronize system time with NTP.

## Testing Commands

### Test ES authentication directly:
```bash
SIGNED=$(python3 aliyun_sts_sign.py --access-key-id $AK --access-key-secret $SK)
curl -H "X-ES-IAM-Signed: $SIGNED" "http://localhost:9200/_cluster/health"
```

### Test Kibana login state:
```bash
curl "http://localhost:5601/internal/security/login_state" | jq
```

### Verify role mappings:
```bash
curl -u elastic:PASSWORD "http://localhost:9200/_security/role_mapping/*" | jq
```
