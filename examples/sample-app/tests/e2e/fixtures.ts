import { test as base, expect } from '@playwright/test';

// Every story test starts from an empty task list.
export const test = base.extend({
  page: async ({ page, request }, use) => {
    await request.post('/api/reset');
    await page.goto('/');
    await use(page);
  },
});

export { expect };

export async function addTask(page, title: string) {
  await page.getByRole('textbox', { name: 'New task' }).fill(title);
  await page.getByRole('button', { name: 'Add' }).click();
  await expect(page.getByRole('list', { name: 'Tasks' }).getByText(title)).toBeVisible();
}
