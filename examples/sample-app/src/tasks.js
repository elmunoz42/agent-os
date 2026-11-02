// Task rules shared by the server. Covered by unit ACs in agent-os/user-stories.

function validateTitle(title) {
  if (typeof title !== 'string') return { ok: false, error: 'Title is required' };
  const trimmed = title.trim();
  if (!trimmed) return { ok: false, error: 'Title is required' };
  if (trimmed.length > 120) return { ok: false, error: 'Title must be 120 characters or less' };
  return { ok: true, value: trimmed };
}

function createStore() {
  let nextId = 1;
  const tasks = [];
  return {
    list() { return tasks.slice(); },
    add(title) {
      const v = validateTitle(title);
      if (!v.ok) return v;
      const task = { id: nextId++, title: v.value, done: false };
      tasks.push(task);
      return { ok: true, value: task };
    },
    toggle(id) {
      const task = tasks.find((t) => t.id === id);
      if (!task) return { ok: false, error: 'Not found' };
      task.done = !task.done;
      return { ok: true, value: task };
    },
    reset() { tasks.length = 0; nextId = 1; },
  };
}

module.exports = { validateTitle, createStore };
