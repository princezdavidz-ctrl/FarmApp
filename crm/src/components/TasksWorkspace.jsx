const priorities = ["all", "urgent", "high", "normal", "low"];

function formatDueDate(value) {
  if (!value) return "No due date";
  return new Date(value).toLocaleString();
}

export function TasksWorkspace({ tasks, staff, loading, error, filters, setFilters, onRefresh, onToggle }) {
  const openCount = tasks.filter((task) => task.status === "open").length;
  const overdueCount = tasks.filter((task) => task.status === "open" && task.due_at && new Date(task.due_at) < new Date()).length;
  const completedCount = tasks.filter((task) => task.status === "completed").length;

  return <section className="tasks-workspace">
    <div className="tasks-summary-grid">
      <div><span>Open tasks</span><strong>{openCount}</strong><small>Active follow-ups</small></div>
      <div className="tasks-summary-accent"><span>Overdue</span><strong>{overdueCount}</strong><small>Need attention</small></div>
      <div><span>Completed</span><strong>{completedCount}</strong><small>Closed follow-ups</small></div>
    </div>
    <section className="panel-card tasks-workspace-panel">
      <div className="panel-heading">
        <div><div className="eyebrow">Follow-up operations</div><h2>Tasks and follow-ups</h2></div>
        <button className="filter-button" type="button" onClick={onRefresh}>Refresh tasks</button>
      </div>
      <div className="tasks-filter-bar">
        <label className="tasks-search-field"><span>⌕</span><input aria-label="Search task or customer" value={filters.search} onChange={(event) => setFilters((current) => ({ ...current, search: event.target.value }))} placeholder="Search task or customer" /></label>
        <select value={filters.status} onChange={(event) => setFilters((current) => ({ ...current, status: event.target.value }))}><option value="all">All statuses</option><option value="open">Open</option><option value="completed">Completed</option></select>
        <select value={filters.priority} onChange={(event) => setFilters((current) => ({ ...current, priority: event.target.value }))}>{priorities.map((priority) => <option key={priority} value={priority}>{priority === "all" ? "All priorities" : `${priority[0].toUpperCase()}${priority.slice(1)} priority`}</option>)}</select>
        <select value={filters.assigned_to} onChange={(event) => setFilters((current) => ({ ...current, assigned_to: event.target.value }))}><option value="all">All assignees</option>{staff.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}</select>
        <label className="tasks-overdue-toggle"><input type="checkbox" checked={filters.overdue} onChange={(event) => setFilters((current) => ({ ...current, overdue: event.target.checked }))} /> Overdue only</label>
      </div>
      {loading ? <div className="state-message">Loading follow-up tasks...</div> : error ? <div className="state-message"><strong>Tasks unavailable</strong><p>{error}</p><button className="primary-button" type="button" onClick={onRefresh}>Try again</button></div> : tasks.length === 0 ? <div className="state-message">No tasks match the current filters.</div> : <div className="global-task-list">{tasks.map((task) => <article className={`global-task-row ${task.status}`} key={task.id}><span className={`task-priority ${task.priority}`} /><div className="global-task-main"><strong>{task.title}</strong><span>{task.customer?.name || "Unknown customer"}{task.customer?.company ? ` · ${task.customer.company}` : ""}</span><small>{task.assignee?.name || "Unassigned"} · {formatDueDate(task.due_at)}</small></div><span className={`global-task-status ${task.status}`}>{task.status}</span><button className="filter-button" type="button" onClick={() => onToggle(task, task.status === "completed" ? "open" : "completed")}>{task.status === "completed" ? "Reopen" : "Complete"}</button></article>)}</div>}
    </section>
  </section>;
}
