export function TaskPanel({ tasks, taskForm, setTaskForm, staff, onSubmit, onToggle }) {
  return (
    <section className="task-panel panel-card">
      <div className="panel-heading"><div><div className="eyebrow">Follow-up queue</div><h2>Tasks</h2></div><span>{tasks.filter((task) => task.status === "open").length} open</span></div>
      <form className="task-composer" onSubmit={onSubmit}>
        <input required value={taskForm.title} onChange={(event) => setTaskForm((current) => ({ ...current, title: event.target.value }))} placeholder="Call customer about next order" />
        <input type="datetime-local" value={taskForm.due_at} onChange={(event) => setTaskForm((current) => ({ ...current, due_at: event.target.value }))} />
        <select value={taskForm.priority} onChange={(event) => setTaskForm((current) => ({ ...current, priority: event.target.value }))}><option value="low">Low priority</option><option value="normal">Normal priority</option><option value="high">High priority</option><option value="urgent">Urgent</option></select>
        <select value={taskForm.assigned_to} onChange={(event) => setTaskForm((current) => ({ ...current, assigned_to: event.target.value }))}><option value="">Unassigned</option>{staff.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}</select>
        <button className="primary-button" type="submit">Add task</button>
      </form>
      <div className="task-list">
        {tasks.length === 0 ? <div className="state-message">No follow-up tasks yet.</div> : tasks.map((task) => <div className={`task-row ${task.status}`} key={task.id}><span className={`task-priority ${task.priority}`} /><div><strong>{task.title}</strong><small>{task.assignee?.name || "Unassigned"}{task.due_at ? ` · Due ${new Date(task.due_at).toLocaleString()}` : ""}</small></div><button className="filter-button" type="button" onClick={() => onToggle(task, task.status === "completed" ? "open" : "completed")}>{task.status === "completed" ? "Reopen" : "Complete"}</button></div>) }
      </div>
    </section>
  );
}
