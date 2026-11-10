import { useState } from "react";

const emptyDraft = { title: "", notes: "", assigned_to: "", due_at: "", priority: "normal", category: "other" };

export function FarmOperationsTasks({ tasks, members, loading, error, canManage, currentUserId, onRefresh, onCreate, onToggle, onDelete }) {
  const [draft, setDraft] = useState(emptyDraft);
  const [saving, setSaving] = useState(false);
  const open = tasks.filter((task) => task.status === "open").length;
  const overdue = tasks.filter((task) => task.status === "open" && task.due_at && new Date(task.due_at) < new Date()).length;
  const completed = tasks.filter((task) => task.status === "completed").length;

  const submit = async (event) => {
    event.preventDefault();
    if (!draft.title.trim()) return;
    setSaving(true);
    const saved = await onCreate(event, draft);
    if (saved) setDraft(emptyDraft);
    setSaving(false);
  };

  return <section className="panel-card farm-operations-tasks">
    <div className="panel-heading">
      <div><div className="eyebrow">Shared farm plan</div><h2>Farm operations tasks</h2></div>
      <span>{open} open · {overdue} overdue · {completed} completed</span>
    </div>
    {canManage && <form className="farm-task-form" onSubmit={submit}>
      <input required maxLength="255" value={draft.title} onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))} placeholder="Task title" aria-label="Task title" />
      <input type="datetime-local" value={draft.due_at} onChange={(event) => setDraft((current) => ({ ...current, due_at: event.target.value }))} aria-label="Due date" />
      <select value={draft.priority} onChange={(event) => setDraft((current) => ({ ...current, priority: event.target.value }))} aria-label="Priority"><option value="low">Low priority</option><option value="normal">Normal priority</option><option value="high">High priority</option><option value="urgent">Urgent</option></select>
      <select value={draft.category} onChange={(event) => setDraft((current) => ({ ...current, category: event.target.value }))} aria-label="Category"><option value="feeding">Feeding</option><option value="health">Health</option><option value="growth">Growth</option><option value="sales">Sales</option><option value="other">Other</option></select>
      <select value={draft.assigned_to} onChange={(event) => setDraft((current) => ({ ...current, assigned_to: event.target.value }))} aria-label="Assigned to"><option value="">Unassigned</option>{members.map((member) => <option key={member.id} value={member.id}>{member.name || member.email}</option>)}</select>
      <textarea maxLength="4000" rows="2" value={draft.notes} onChange={(event) => setDraft((current) => ({ ...current, notes: event.target.value }))} placeholder="Notes" aria-label="Notes" />
      <button className="primary-button" type="submit" disabled={saving}>{saving ? "Saving…" : "Add farm task"}</button>
    </form>}
    <div className="farm-task-list">
      {loading ? <div className="operations-state">Loading farm tasks…</div>
        : error ? <div className="operations-state error"><strong>Farm tasks unavailable</strong><p>{error}</p><button className="filter-button" type="button" onClick={onRefresh}>Try again</button></div>
          : tasks.length === 0 ? <div className="operations-state">No farm tasks yet.</div>
            : tasks.map((task) => {
              const isOverdue = task.status === "open" && task.due_at && new Date(task.due_at) < new Date();
              const canUpdate = canManage || (task.assigned_to != null && String(task.assigned_to) === String(currentUserId));
              return <article className={`farm-task-row ${task.status} ${isOverdue ? "overdue" : ""}`} key={task.id}>
              <span className={`task-priority ${task.priority}`} />
              <div className="farm-task-main"><strong>{task.title}</strong><small>{task.assignee?.name || "Unassigned"}{task.due_at ? ` · Due ${new Date(task.due_at).toLocaleString()}` : " · No due date"}</small>{task.notes && <span>{task.notes}</span>}</div>
              <span className={`global-task-status ${task.status} ${isOverdue ? "overdue" : ""}`}>{isOverdue ? "Overdue" : task.status}</span>
              {canUpdate && <button className="filter-button" type="button" onClick={() => onToggle(task, task.status === "completed" ? "open" : "completed")}>{task.status === "completed" ? "Reopen" : "Complete"}</button>}
              {canManage && <button className="danger-button" type="button" onClick={() => onDelete(task)}>Delete</button>}
            </article>;
            })}
    </div>
  </section>;
}
