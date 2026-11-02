import { test, expect, addTask } from '../fixtures';

test.describe('US-002 Complete a task', () => {
  test('US-002 AC1: checking a task marks it done and updates the count @US-002', async ({ page }) => {
    await addTask(page, 'Write docs');
    await addTask(page, 'Ship release');

    await page.getByRole('checkbox', { name: 'Complete Write docs' }).check();

    await expect(page.getByRole('checkbox', { name: 'Complete Write docs' })).toBeChecked();
    await expect(page.getByText('1 task left')).toBeVisible();
  });
});
