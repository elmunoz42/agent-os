import { test, expect } from '../fixtures';

test.describe('US-001 Add a task', () => {
  test('US-001 AC1: a new task appears in the list and the input clears @US-001', async ({ page }) => {
    await page.getByRole('textbox', { name: 'New task' }).fill('Buy milk');
    await page.getByRole('button', { name: 'Add' }).click();

    await expect(page.getByRole('list', { name: 'Tasks' }).getByText('Buy milk')).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'New task' })).toHaveValue('');
    await expect(page.getByText('1 task left')).toBeVisible();
  });

  test('US-001 AC3: submitting an empty task shows an error and adds nothing @US-001', async ({ page }) => {
    await page.getByRole('button', { name: 'Add' }).click();

    await expect(page.getByRole('alert')).toHaveText('Title is required');
    await expect(page.getByRole('list', { name: 'Tasks' }).getByRole('listitem')).toHaveCount(0);
  });
});
