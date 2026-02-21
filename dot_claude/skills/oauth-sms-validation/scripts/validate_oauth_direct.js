#!/usr/bin/env node
/**
 * Direct OAuth flow validator - bypasses browser automation and captcha issues
 *
 * This approach:
 * 1. Gets the authorization URL from Kibana OAuth endpoint
 * 2. User manually completes login in browser (handles captcha/SMS)
 * 3. User copies the callback URL back to this script
 * 4. Script calls the callback endpoint and validates authentication
 *
 * This is more reliable than browser automation when dealing with:
 * - Captcha/slider verification
 * - SMS verification codes
 * - Dynamic security challenges
 */

const readline = require('readline');
const http = require('http');

// Configuration from environment variables
const KIBANA_HOST = process.env.KIBANA_HOST || '47.236.247.55';
const KIBANA_PORT = process.env.KIBANA_PORT || '5601';
const KIBANA_BASE = process.env.KIBANA_BASE || '/kibana';
const KIBANA_URL = `http://${KIBANA_HOST}:${KIBANA_PORT}${KIBANA_BASE}`;

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

/**
 * Performs an HTTP GET request and returns parsed result
 */
function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, {
      headers: { 'Accept': 'application/json' },
      timeout: 10000
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const body = data ? JSON.parse(data) : null;
          resolve({
            status: res.statusCode,
            body,
            headers: res.headers,
            location: res.headers.location
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            body: data,
            headers: res.headers,
            location: res.headers.location
          });
        }
      });
    }).on('error', reject);
  });
}

/**
 * Main validation flow
 */
async function main() {
  console.log('\n' + '='.repeat(80));
  console.log('OAUTH DIRECT VALIDATION - Bypass Captcha/Browser Automation');
  console.log('='.repeat(80));
  console.log('');
  console.log('Target:', KIBANA_URL);
  console.log('');

  try {
    // Step 1: Get OAuth authorization URL from Kibana
    console.log('Step 1: Getting OAuth authorization URL from Kibana...');
    console.log('');

    const authorizeUrl = `${KIBANA_URL}/api/security/aliyun/oauth/authorize`;
    const authResult = await httpGet(authorizeUrl);

    if (authResult.status !== 200) {
      console.error('❌ Failed to get authorization URL');
      console.error('   Status:', authResult.status);
      console.error('   Body:', JSON.stringify(authResult.body, null, 2));
      console.error('');
      console.error('   Troubleshooting:');
      console.error('   - Is Kibana running?');
      console.error('   - Is the Aliyun OAuth provider configured?');
      console.error('   - Check kibana.yml for xpack.security.authc.providers.aliyun');
      process.exit(1);
    }

    const { authorizationUrl, state } = authResult.body;

    if (!authorizationUrl || !state) {
      console.error('❌ Invalid response from authorize endpoint');
      console.error('   Expected: { authorizationUrl, state }');
      console.error('   Got:', authResult.body);
      process.exit(1);
    }

    console.log('✓ Successfully retrieved OAuth URL');
    console.log('  State:', state);
    console.log('');

    // Step 2: User manually logs in via browser
    console.log('='.repeat(80));
    console.log('Step 2: MANUAL LOGIN (handles captcha/SMS automatically)');
    console.log('='.repeat(80));
    console.log('');
    console.log('Instructions:');
    console.log('');
    console.log('1. Open this URL in your browser:');
    console.log('');
    console.log('   ' + authorizationUrl);
    console.log('');
    console.log('2. Complete the Aliyun OAuth login:');
    console.log('   - Enter your phone/email');
    console.log('   - Complete any captcha/slider verification');
    console.log('   - Enter SMS code if prompted');
    console.log('   - Authorize the application');
    console.log('');
    console.log('3. After successful login, you will be redirected to a URL like:');
    console.log('');
    console.log(`   ${KIBANA_URL}/api/security/aliyun/oauth/callback?code=...&state=...`);
    console.log('');
    console.log('4. Copy the ENTIRE redirect URL from your browser address bar');
    console.log('');

    // Wait for user to complete login and paste callback URL
    rl.question('Paste the callback URL here: ', async (callbackUrl) => {
      console.log('');
      console.log('='.repeat(80));
      console.log('Step 3: Validating OAuth callback...');
      console.log('='.repeat(80));
      console.log('');

      try {
        // Parse and validate callback URL
        const url = new URL(callbackUrl.trim());
        const code = url.searchParams.get('code');
        const returnedState = url.searchParams.get('state');

        console.log('Extracted parameters:');
        console.log('  Code:', code ? code.substring(0, 30) + '...' : '❌ MISSING');
        console.log('  State:', returnedState || '❌ MISSING');
        console.log('  Expected state:', state);
        console.log('');

        if (!code) {
          console.error('❌ No authorization code found in URL');
          console.error('   The URL should contain ?code=...');
          console.error('   Did you paste the correct callback URL?');
          process.exit(1);
        }

        if (returnedState !== state) {
          console.warn('⚠️  WARNING: State parameter mismatch!');
          console.warn('   Expected:', state);
          console.warn('   Received:', returnedState);
          console.warn('   This may indicate a security issue or session timeout.');
          console.log('');
        }

        // Step 3: Call the OAuth callback endpoint
        console.log('Calling OAuth callback endpoint...');
        const callbackResult = await httpGet(callbackUrl);

        console.log('');
        console.log('Callback response:');
        console.log('  Status:', callbackResult.status);
        console.log('  Redirect location:', callbackResult.location || 'none');
        console.log('');

        // Analyze the response
        if (callbackResult.status === 302 || callbackResult.status === 301) {
          const location = callbackResult.location;

          if (!location) {
            console.error('❌ Redirect status but no Location header');
            console.error('   Response:', JSON.stringify(callbackResult.body, null, 2));
            process.exit(1);
          }

          if (location.includes('/login')) {
            console.error('❌ AUTHENTICATION FAILED');
            console.error('   Redirected back to login page:', location);
            console.error('');
            console.error('   Possible causes:');
            console.error('   1. Elasticsearch CloudIamRealm failed to validate OAuth token');
            console.error('   2. No role mappings configured for OAuth user');
            console.error('   3. Authorization header not sent correctly');
            console.error('');
            console.error('   Troubleshooting steps:');
            console.error('   - Check Kibana logs: tail -f /tmp/kibana-start.log');
            console.error('   - Check ES logs for CloudIamRealm errors');
            console.error('   - Verify Authorization: Bearer header is being sent');
            console.error('   - Check role mappings in Elasticsearch');
            process.exit(1);
          }

          console.log('✅ SUCCESS! OAuth authentication completed successfully!');
          console.log('');
          console.log('Redirect target:', location);
          console.log('');

          // Verify we can access Kibana with the new session
          console.log('Step 4: Verifying Kibana access...');
          console.log('');
          console.log('Please open your browser and navigate to:');
          console.log('');
          console.log('   ' + KIBANA_URL);
          console.log('');
          console.log('You should be logged in automatically. If not, check:');
          console.log('- Browser cookies are enabled');
          console.log('- No browser extensions blocking cookies');
          console.log('- Session timeout settings in kibana.yml');

        } else if (callbackResult.status === 200) {
          console.log('⚠️  Callback returned 200 OK instead of redirect');
          console.log('   This is unexpected - OAuth should redirect after success');
          console.log('   Response:', JSON.stringify(callbackResult.body, null, 2));

        } else if (callbackResult.status === 401 || callbackResult.status === 403) {
          console.error('❌ AUTHENTICATION FAILED');
          console.error('   Status:', callbackResult.status);
          console.error('   Response:', JSON.stringify(callbackResult.body, null, 2));
          console.error('');
          console.error('   This usually means:');
          console.error('   - OAuth token validation failed in Elasticsearch');
          console.error('   - Check Elasticsearch CloudIamRealm logs');
          process.exit(1);

        } else {
          console.error('❌ Unexpected response from callback');
          console.error('   Status:', callbackResult.status);
          console.error('   Body:', JSON.stringify(callbackResult.body, null, 2));
          process.exit(1);
        }

      } catch (err) {
        console.error('');
        console.error('❌ Error during validation:');
        console.error('   ', err.message);
        console.error('');
        if (err.code === 'ECONNREFUSED') {
          console.error('   Kibana is not reachable. Is it running?');
        } else if (err.code === 'ETIMEDOUT') {
          console.error('   Request timed out. Is Kibana responding?');
        }
        process.exit(1);
      } finally {
        rl.close();
      }
    });

  } catch (err) {
    console.error('');
    console.error('❌ Fatal error:');
    console.error('   ', err.message);
    console.error('');
    if (err.code === 'ECONNREFUSED') {
      console.error('   Cannot connect to Kibana at', KIBANA_URL);
      console.error('   - Check KIBANA_HOST, KIBANA_PORT, KIBANA_BASE env vars');
      console.error('   - Ensure Kibana is running: curl ' + KIBANA_URL + '/api/status');
    }
    process.exit(1);
  }
}

// Handle Ctrl+C gracefully
process.on('SIGINT', () => {
  console.log('\n\n❌ Validation cancelled by user');
  rl.close();
  process.exit(130);
});

// Run the validation
main().catch(err => {
  console.error('Unhandled error:', err);
  process.exit(1);
});
