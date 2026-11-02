import { test, expect, addTask } from '../fixtures';

test.describe('US-003 Show only active tasks', () => {
  // Known bug: story US-003 is failing (see agent-os/user-stories/US-003-filter-active-tasks.md).
  // test.fail() keeps the suite green and flips to an error once the bug is fixed,
  // so remove it as part of the fix.
  test.fail();

  test('US-003 AC1: the Active filter hides completed tasks @US-003 @demo', async ({ page }) => {
    await addTask(page, 'Write docs');
    await addTask(page, 'Ship release');
    await page.getByRole('checkbox', { name: 'Complete Write docs' }).check();
    await expect(page.getByText('1 task left')).toBeVisible();

    await page.getByRole('button', { name: 'Active' }).click();

    await expect(page.getByRole('list', { name: 'Tasks' }).getByText('Ship release')).toBeVisible();
    await expect(page.getByRole('list', { name: 'Tasks' }).getByText('Write docs')).toHaveCount(0);
  });
});
