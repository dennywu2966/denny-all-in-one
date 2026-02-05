/**
 * SMSPVA SMS Service
 *
 * Integration with SMSPVA.com for automated SMS receiving.
 * API Documentation: https://smspva.com/
 *
 * Services codes (ot = other):
 * - ot: Other services
 * - mm: Mail.ru
 * - vk: VKontakte
 * - wa: WhatsApp
 * - tg: Telegram
 * - etc.
 */

export default class SMSPVA {
  constructor(config) {
    this.config = config;
    this.phone = config.phone;
    this.apiKey = config.apiKey;
    this.country = config.country || '0';  // 0 = Russia, CN = China
    this.service = config.service || 'ot';  // ot = other
    this.baseUrl = 'https://smspva.com/priemnik.php';
    this.sessionId = null;
    this.phoneNumber = null;
  }

  async initialize() {
    if (!this.apiKey) {
      throw new Error('SMSPVA API key is required. Set --smspva-api-key');
    }

    console.log('');
    console.log('='.repeat(60));
    console.log('SMSPVA Automated SMS Service');
    console.log('='.repeat(60));
    console.log('');
    console.log(`Country: ${this.country}`);
    console.log(`Service: ${this.service}`);
    console.log('');
  }

  async configureForProvider(provider) {
    // Map provider to SMSPVA service code
    const serviceMap = {
      aliyun: 'ot',
      wechat: 'ot',
      qq: 'ot',
      dingtalk: 'ot',
      baidu: 'ot'
    };

    this.service = serviceMap[provider] || 'ot';
    console.log(`Provider service code: ${this.service}`);
  }

  async requestNumber() {
    const params = new URLSearchParams({
      metod: 'get_number',
      country: this.country,
      service: this.service,
      apikey: this.apiKey
    });

    const response = await fetch(`${this.baseUrl}?${params}`);
    const text = await response.text();

    // Response format: "NUMBER:1234567890:ID"
    if (text.startsWith('NUMBER:')) {
      const parts = text.split(':');
      this.phoneNumber = parts[1];
      this.sessionId = parts[2];
      console.log(`Got number: ${this.phoneNumber}`);
      return this.phoneNumber;
    }

    if (text.includes('NO_NUMBERS')) {
      throw new Error('No numbers available for this country/service');
    }

    if (text.includes('NO_BALANCE')) {
      throw new Error('Insufficient SMSPVA balance');
    }

    throw new Error(`SMSPVA error: ${text}`);
  }

  async getCode() {
    // First, request a number if we haven't
    if (!this.phoneNumber) {
      this.phoneNumber = await this.requestNumber();
      console.log(`Waiting for SMS on: ${this.phoneNumber}`);
      console.log('Use this number instead of your original phone number!');
      console.log('');
    }

    // Poll for SMS code
    const maxAttempts = 30;  // 30 attempts = 60 seconds
    for (let i = 0; i < maxAttempts; i++) {
      const params = new URLSearchParams({
        metod: 'get_sms',
        country: this.country,
        service: this.service,
        id: this.sessionId,
        apikey: this.apiKey
      });

      const response = await fetch(`${this.baseUrl}?${params}`);
      const text = await response.text();

      // Response format: "SMS:1234:ID" or "STATUS:NO_SMS"
      if (text.startsWith('SMS:')) {
        const code = text.split(':')[1];
        console.log(`Received SMS code: ${code}`);
        return code;
      }

      if (text.includes('STATUS_NO_SMS')) {
        // No SMS yet, wait and retry
        await new Promise(resolve => setTimeout(resolve, 2000));
        continue;
      }

      if (text.includes('STATUS_CANCEL')) {
        throw new Error('SMS request was cancelled');
      }

      if (text.includes('BAD_KEY')) {
        throw new Error('Invalid SMSPVA API key');
      }

      // Unknown response
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    throw new Error('SMS code timeout - no code received');
  }

  async cleanup() {
    // Cancel the number if we didn't receive SMS
    // This refunds the cost
    if (this.sessionId && this.phoneNumber) {
      try {
        const params = new URLSearchParams({
          metod: 'denial',
          country: this.country,
          service: this.service,
          id: this.sessionId,
          apikey: this.apiKey
        });

        await fetch(`${this.baseUrl}?${params}`);
        console.log('Cancelled SMSPVA number');
      } catch (e) {
        console.error('Failed to cancel SMSPVA number:', e.message);
      }
    }
  }
}
