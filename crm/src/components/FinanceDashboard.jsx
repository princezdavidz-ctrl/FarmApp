export function FinanceDashboard({
  customers,
  counts,
  report,
  calculator,
  setCalculator,
  projectedRevenue,
  plans,
  planForm,
  setPlanForm,
  savePlan,
  togglePlan,
  canManagePlans,
  statuses,
}) {
  const activeRelationships = report?.active_relationships ?? customers.filter(
    (customer) => !["lost"].includes(customer.status),
  ).length;
  const winRate = report?.conversion_rate ?? (customers.length
    ? Math.round(((counts.won || 0) / customers.length) * 100)
    : 0);
  const statusTotal = report?.total_customers ?? customers.length;
  const statusCounts = report?.by_status || counts;

  return (
    <section className="finance-dashboard">
      <div className="finance-kpis">
        <div className="finance-kpi">
          <span>Active relationships</span>
          <strong>{activeRelationships}</strong>
          <small>Current CRM records excluding lost</small>
        </div>
        <div className="finance-kpi">
          <span>Qualified pipeline</span>
          <strong>{report?.qualified ?? counts.qualified ?? 0}</strong>
          <small>Ready for subscription follow-up</small>
        </div>
        <div className="finance-kpi finance-kpi-accent">
          <span>Conversion rate</span>
          <strong>{winRate}%</strong>
          <small>Won relationships this cycle</small>
        </div>
      </div>
      <div className="finance-columns">
        <section className="panel-card finance-breakdown">
          <div className="panel-heading">
            <div>
              <div className="eyebrow">Customer health</div>
              <h2>Pipeline by status</h2>
            </div>
            <span>{statusTotal} records</span>
          </div>
          {statuses.slice(1).map((status) => (
            <div className="breakdown-row" key={status}>
              <span className={`status-dot ${status}`} />
              <span>{status[0].toUpperCase() + status.slice(1)}</span>
              <div className="breakdown-bar"><i style={{ width: `${statusTotal ? ((statusCounts[status] || 0) / statusTotal) * 100 : 0}%` }} /></div>
              <strong>{statusCounts[status] || 0}</strong>
            </div>
          ))}
        </section>
        <section className="panel-card calculator-card">
          <div className="eyebrow">Planning tool</div>
          <h2>Revenue calculator</h2>
          <p>Estimate monthly revenue from the active subscription catalog.</p>
          <label>Paying customers<input type="number" min="0" value={calculator.customers} onChange={(event) => setCalculator((current) => ({ ...current, customers: event.target.value }))} placeholder="0" /></label>
          <label>Monthly amount<input type="number" min="0" step="0.01" value={calculator.amount} onChange={(event) => setCalculator((current) => ({ ...current, amount: event.target.value }))} placeholder="0.00" /></label>
          <div className="calculator-total"><span>Projected monthly revenue</span><strong>{projectedRevenue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</strong></div>
        </section>
      </div>
      <section className="panel-card finance-next-step">
        <div><div className="eyebrow">Payment setup</div><h2>Plans are ready for checkout</h2><p>Choose a payment provider before enabling gateway transactions for these prices.</p></div>
        <button className="ghost-button" onClick={() => window.alert("Add the payment provider and server-side credentials to enable checkout.")}>View integration status</button>
      </section>
      <section className="panel-card subscription-farms-panel">
        <div className="panel-heading">
          <div><div className="eyebrow">Farm subscriptions</div><h2>Herd-based billing</h2></div>
          <span>{report?.subscriptions?.length || 0} farms</span>
        </div>
        {(report?.subscriptions || []).length === 0 ? <p>No farm subscription payments recorded yet.</p> : <div className="plan-list">
          {report.subscriptions.map((farm) => <div className="staff-row" key={farm.id}>
            <strong>{farm.name}</strong>
            <span>{farm.mother_pig_count ?? 0} mother pigs</span>
            <span>{farm.subscription_plan || "No plan"}</span>
            <span>{farm.payment_amount ? `${farm.payment_amount} ${farm.payment_currency}` : "No payment"}</span>
            <span>{farm.payment_status || "pending"}</span>
            <span>{farm.mpesa_receipt || "Awaiting M-Pesa"}</span>
          </div>)}
        </div>}
      </section>
      {canManagePlans && <section className="panel-card subscription-plans-panel">
        <div className="panel-heading">
          <div><div className="eyebrow">Billing catalog</div><h2>Subscription plans</h2></div>
          <span>{plans.length} plans</span>
        </div>
        <form className="staff-row" onSubmit={savePlan}>
          <input required value={planForm.code} onChange={(event) => setPlanForm((current) => ({ ...current, code: event.target.value }))} placeholder="Code" />
          <input required value={planForm.name} onChange={(event) => setPlanForm((current) => ({ ...current, name: event.target.value }))} placeholder="Plan name" />
          <input required type="number" min="0" step="0.01" value={planForm.amount} onChange={(event) => setPlanForm((current) => ({ ...current, amount: event.target.value }))} placeholder="Amount" />
          <input required maxLength="3" value={planForm.currency} onChange={(event) => setPlanForm((current) => ({ ...current, currency: event.target.value.toUpperCase() }))} placeholder="Currency" />
          <input type="number" min="1" value={planForm.pig_limit} onChange={(event) => setPlanForm((current) => ({ ...current, pig_limit: event.target.value }))} placeholder="Pig limit" />
          <button className="primary-button" type="submit">Add plan</button>
        </form>
        <div className="plan-list">
          {plans.map((plan) => <div className="staff-row" key={plan.id}>
            <strong>{plan.name}</strong>
            <span>{plan.amount} {plan.currency}</span>
            <span>{plan.pig_limit ? `Up to ${plan.pig_limit} pigs` : "Unlimited pigs"}</span>
            <span>{plan.active ? "Active" : "Retired"}</span>
            <button className="filter-button" type="button" onClick={() => togglePlan(plan)}>{plan.active ? "Retire" : "Activate"}</button>
          </div>)}
        </div>
      </section>}
    </section>
  );
}
