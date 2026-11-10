export function PipelineBoard({ customers, onSelect, onMove, statuses }) {
  return (
    <section className="pipeline-board">
      {statuses.slice(1).map((status) => (
        <div className="pipeline-column panel-card" key={status}>
          <div className="panel-heading">
            <div><span className={`status-dot ${status}`} /><h2>{status[0].toUpperCase() + status.slice(1)}</h2></div>
            <span>{customers.filter((customer) => customer.status === status).length}</span>
          </div>
          <div className="pipeline-cards">
            {customers.filter((customer) => customer.status === status).map((customer) => (
              <article className="pipeline-card" key={customer.id} onClick={() => onSelect(customer.id)}>
                <button type="button" onClick={() => onSelect(customer.id)}><strong>{customer.name}</strong><span>{customer.company || customer.email || "No company details"}</span></button>
                <div><small>{customer.assignee?.name || "Unassigned"}</small><select value={customer.status} onChange={(event) => onMove(customer, event.target.value)} onClick={(event) => event.stopPropagation()}><option value={customer.status}>{customer.status}</option>{statuses.slice(1).filter((nextStatus) => nextStatus !== customer.status).map((nextStatus) => <option key={nextStatus} value={nextStatus}>{nextStatus}</option>)}</select></div>
              </article>
            ))}
          </div>
        </div>
      ))}
    </section>
  );
}
