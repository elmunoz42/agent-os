import { defineConfig, devices } from '@playwright/test';

const PORT = Number(process.env.PORT) || 4173;

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: false, // tests share one in-memory server and reset it per test
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      // PW_CHANNEL=chrome uses an installed Google Chrome instead of the bundled Chromium
      use: { ...devices['Desktop Chrome'], channel: process.env.PW_CHANNEL || undefined },
    },
  ],
  webServer: {
    command: 'node server.js',
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !process.env.CI,
  },
});
