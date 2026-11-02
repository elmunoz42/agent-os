import { test, expect } from '../fixtures';

test.describe('US-004 Reject task titles over 120 characters', () => {
  test('US-004 AC1: a 121 character title is rejected and kept in the input @US-004 @prod', async ({ page }) => {
    const longTitle = 'x'.repeat(121);
    await page.getByRole('textbox', { name: 'New task' }).fill(longTitle);
    await page.getByRole('button', { name: 'Add' }).click();

    await expect(page.getByRole('alert')).toHaveText('Title must be 120 characters or less');
    await expect(page.getByRole('list', { name: 'Tasks' }).getByRole('listitem')).toHaveCount(0);
    await expect(page.getByRole('textbox', { name: 'New task' })).toHaveValue(longTitle);
  });
});
