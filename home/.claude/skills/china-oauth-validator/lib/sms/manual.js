/**
 * Manual SMS Service
 *
 * Prompts the user to enter SMS code manually.
 * This is the default and most reliable method.
 */

import readline from 'readline';

export default class ManualSmsService {
  constructor(config) {
    this.config = config;
    this.phone = config.phone;
    this.name = 'manual';
  }

  async initialize() {
    console.log('');
    console.log('='.repeat(60));
    console.log('Manual SMS Entry Mode');
    console.log('='.repeat(60));
    console.log('');
    console.log(`Phone: ${this.phone}`);
    console.log('');
  }

  async configureForProvider(provider) {
    console.log(`Provider: ${provider}`);
    console.log('');
  }

  async getCode() {
    return new Promise((resolve) => {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });

      rl.question('Enter SMS code: ', (code) => {
        rl.close();
        resolve(code.trim());
      });
    });
  }

  async cleanup() {
    // Nothing to cleanup for manual mode
  }
}
