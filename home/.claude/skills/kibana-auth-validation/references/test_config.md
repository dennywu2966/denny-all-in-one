# Test Credentials and Configuration

## Stack URLs

| Service | URL | Notes |
|---------|-----|-------|
| Elasticsearch | https://127.0.0.1:9200 | HTTPS with self-signed cert |
| Kibana | http://47.236.247.55:5601 | Public URL for OAuth redirect |

## Authentication Credentials

### Basic Auth
| Field | Value |
|-------|-------|
| Username | elastic |
| Password | Summer11 |

### Aliyun OAuth (RAM SSO)
| Field | Value |
|-------|-------|
| Email/Username | dongdongplanet@1437310945246567.onaliyun.com |
| Password | Summer11 |
| SMS Phone (for OTP) | 18972952966 |
| OAuth Client ID | 4004069369666938196 |

## Stack Health Check Commands

```bash
# Check Elasticsearch health
curl -sk -u elastic:Summer11 https://127.0.0.1:9200/_cluster/health?pretty

# Check Elasticsearch plugins
curl -sk -u elastic:Summer11 https://127.0.0.1:9200/_cat/plugins?v

# Check Kibana status
curl -s http://localhost:5601/api/status
```

## Expected Configuration

### Elasticsearch (elasticsearch.yml)
```yaml
xpack.security.enabled: true
xpack.security.http.ssl.enabled: true
xpack.security.authc.realms.cloud_iam.cloud_iam_realm.order: 0
```

### Kibana (kibana.yml)
```yaml
elasticsearch.hosts: ["https://127.0.0.1:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "Summer11"
elasticsearch.ssl.verificationMode: none
server.publicBaseUrl: "http://47.236.247.55:5601"

xpack.security.authc.providers:
  aliyun.aliyun:
    order: 0
    oauth:
      clientId: "4004069369666938196"
  basic.basic:
    order: 100
```

## Test Suites

### Suite 1: Basic Auth Regression
1. Valid credentials (elastic/Summer11)
2. Invalid password (elastic/WrongPassword123)
3. Invalid username (nonexistent_user/any)

### Suite 2: OAuth Flow
1. Complete valid flow
2. Wrong password
3. Cancelled flow
4. Invalid account

### Suite 3: UI/UX
1. Login page layout
2. Console error check
3. Session persistence
4. Logout functionality

## Success Criteria

- [ ] Basic auth valid login succeeds
- [ ] Basic auth invalid credentials show error
- [ ] OAuth button visible on login page
- [ ] OAuth flow redirects to Aliyun
- [ ] OAuth valid flow completes successfully
- [ ] No JavaScript errors in console
- [ ] Session persists across navigation
- [ ] Logout works correctly

## Troubleshooting

### Stack Not Running
```bash
cd /home/denny/projects/kibana-9.2.4
./project-starter.sh
```

### OAuth Redirect Mismatch
Check `server.publicBaseUrl` in kibana.yml equals `http://47.236.247.55:5601`

### ES SSL Certificate Error
The ES uses self-signed certificates. Browsers may show warnings - this is expected for development.
