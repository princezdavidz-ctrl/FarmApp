import { useState } from "react";

function SubscriptionRows({ subscriptions }) {
  if (subscriptions.length === 0) return <div className="state-message">No farm subscription records are available yet.</div>;
  return <div className="finance-record-list">{subscriptions.map((farm) => <article className="finance-record-row" key={farm.id}><div><strong>{farm.name}</strong><span>{farm.mother_pig_count ?? 0} mother pigs</span></div><span>{farm.subscription_plan || "No plan"}</span><span>{farm.payment_amount ? `${farm.payment_amount} ${farm.payment_currency}` : "No payment"}</span><span className={`payment-status ${farm.payment_status === "paid" ? "paid" : "pending"}`}>{farm.payment_status || "pending"}</span></article>)}</div>;
}

function PlansView({ plans, planForm, setPlanForm, savePlan, togglePlan, canManagePlans }) {
  return <section className="panel-card finance-workspace-panel"><div className="panel-heading"><div><div className="eyebrow">Billing catalog</div><h2>Subscription plans</h2></div><span>{plans.length} plans</span></div>{canManagePlans && <form className="finance-plan-form" onSubmit={savePlan}><input required value={planForm.code} onChange={(event) => setPlanForm((current) => ({ ...current, code: event.target.value }))} placeholder="Code" /><input required value={planForm.name} onChange={(event) => setPlanForm((current) => ({ ...current, name: event.target.value }))} placeholder="Plan name" /><input required type="number" min="0" step="0.01" value={planForm.amount} onChange={(event) => setPlanForm((current) => ({ ...current, amount: event.target.value }))} placeholder="Amount" /><input required maxLength="3" value={planForm.currency} onChange={(event) => setPlanForm((current) => ({ ...current, currency: event.target.value.toUpperCase() }))} placeholder="Currency" /><input type="number" min="1" value={planForm.pig_limit} onChange={(event) => setPlanForm((current) => ({ ...current, pig_limit: event.target.value }))} placeholder="Pig limit" /><button className="primary-button" type="submit">Add plan</button></form>}{plans.length === 0 ? <div className="state-message">No subscription plans have been created.</div> : <div className="finance-record-list">{plans.map((plan) => <article className="finance-record-row" key={plan.id}><div><strong>{plan.name}</strong><span>{plan.code}</span></div><span>{plan.amount} {plan.currency}</span><span>{plan.pig_limit ? `Up to ${plan.pig_limit} pigs` : "Unlimited pigs"}</span><span>{plan.active ? "Active" : "Retired"}</span>{canManagePlans && <button className="filter-button" type="button" onClick={() => togglePlan(plan)}>{plan.active ? "Retire" : "Activate"}</button>}</article>)}</div>}</section>;
}

function ReportingView({ report }) {
  const status = report?.by_status || {};
  return <section className="panel-card finance-workspace-panel"><div className="panel-heading"><div><div className="eyebrow">Revenue reporting</div><h2>Financial performance</h2></div><span>{report?.generated_at ? new Date(report.generated_at).toLocaleDateString() : "No report date"}</span></div><div className="finance-report-grid"><div><span>Active relationships</span><strong>{report?.active_relationships ?? 0}</strong><small>CRM relationships excluding lost records</small></div><div><span>Qualified pipeline</span><strong>{report?.qualified ?? 0}</strong><small>Relationships ready for follow-up</small></div><div><span>Conversion rate</span><strong>{report?.conversion_rate ?? 0}%</strong><small>Won relationships in the report</small></div></div><div className="finance-report-status"><strong>Pipeline status counts</strong>{Object.entries(status).map(([key, value]) => <span key={key}>{key}: {value}</span>)}</div><p className="finance-disclaimer">This report combines CRM pipeline indicators with subscription data. It does not represent a complete transaction ledger.</p></section>;
}

function FinancialGraph({ report }) {
  const [graphState, setGraphState] = useState("default");
  const metrics = [
    { label: "Customers", value: Number(report?.total_customers || 0), color: "#5ee0b7" },
    { label: "Active", value: Number(report?.active_relationships || 0), color: "#73a7ff" },
    { label: "Revenue", value: Number(report?.revenue_collected || 0), color: "#ffc76b" },
  ];
  const maxValue = Math.max(...metrics.map((metric) => metric.value), 1);
  const isMinimized = graphState === "minimized";
  const isMaximized = graphState === "maximized";

  return <section className={`panel-card finance-graph-panel ${isMinimized ? "is-minimized" : ""} ${isMaximized ? "is-maximized" : ""}`} aria-label="Farm financial graph">
    <div className="panel-heading"><div><div className="eyebrow">Financial trend</div><h2>Farm performance</h2></div><div className="finance-graph-actions"><span>Current report</span><button className="finance-icon-button" type="button" title={isMinimized ? "Expand graph" : "Minimize graph"} aria-label={isMinimized ? "Expand graph" : "Minimize graph"} onClick={() => setGraphState(isMinimized ? "default" : "minimized")}>{isMinimized ? "＋" : "−"}</button><button className="finance-icon-button" type="button" title={isMaximized ? "Restore graph" : "Maximize graph"} aria-label={isMaximized ? "Restore graph" : "Maximize graph"} onClick={() => setGraphState(isMaximized ? "default" : "maximized")}>{isMaximized ? "⤢" : "⤢"}</button></div></div>
    {!isMinimized && <div className="finance-graph" role="img" aria-label="Bar graph comparing customers, active relationships, and collected revenue">
      {metrics.map((metric) => <div className="finance-graph-column" key={metric.label}>
        <strong>{metric.value.toLocaleString()}</strong>
        <div className="finance-graph-track"><i style={{ height: `${Math.max((metric.value / maxValue) * 100, 5)}%`, background: metric.color }} /></div>
        <span>{metric.label}</span>
      </div>)}
    </div>}
  </section>;
}

function OverviewView({ report, calculator, setCalculator, projectedRevenue }) {
  return <section className="finance-overview-layout"><section className="panel-card finance-workspace-panel finance-snapshot-panel"><div className="panel-heading"><div><div className="eyebrow">Finance overview</div><h2>Farm financial snapshot</h2></div><span>{report?.generated_at ? new Date(report.generated_at).toLocaleDateString() : "No report date"}</span></div><div className="finance-kpis"><div className="finance-kpi"><span>Customers</span><strong>{report?.total_customers ?? 0}</strong><small>Total relationships</small></div><div className="finance-kpi finance-kpi-accent"><span>Active relationships</span><strong>{report?.active_relationships ?? 0}</strong><small>Excluding lost records</small></div><div className="finance-kpi"><span>Collected revenue</span><strong>{report?.revenue_collected ?? 0}</strong><small>Paid transactions</small></div></div><div className="calculator-card"><div className="eyebrow">Revenue planner</div><h2>Project monthly revenue</h2><p>Estimate revenue using your current customer volume and expected monthly value.</p><div className="finance-plan-form"><input type="number" min="0" value={calculator.customers} onChange={(event) => setCalculator((current) => ({ ...current, customers: event.target.value }))} placeholder="Customers" /><input type="number" min="0" step="0.01" value={calculator.amount} onChange={(event) => setCalculator((current) => ({ ...current, amount: event.target.value }))} placeholder="Monthly value" /></div><div className="calculator-total"><span>Projected monthly revenue</span><strong>{projectedRevenue}</strong></div></div></section><FinancialGraph report={report} /></section>;
}

function PaymentsView({ report }) {
  const payments = report?.payments || [];
  return <section className="panel-card finance-workspace-panel"><div className="panel-heading"><div><div className="eyebrow">Payment activity</div><h2>Transaction ledger</h2></div><span>{payments.length} transactions</span></div>{payments.length === 0 ? <div className="state-message">No payment transactions are available yet.</div> : <div className="finance-record-list">{payments.map((payment) => <article className="finance-record-row" key={payment.id}><div><strong>{payment.farm_name || "Farm"}</strong><span>{payment.plan_code || "Plan"}</span></div><span>{payment.amount} {payment.currency}</span><span>{payment.paid_at ? new Date(payment.paid_at).toLocaleDateString() : "Not paid"}</span><span className={`payment-status ${payment.status === "paid" ? "paid" : "pending"}`}>{payment.status}</span><small>{payment.mpesa_receipt || "No receipt"}</small></article>)}</div>}</section>;
}

export function FinanceWorkspace({ view, customers, counts, report, calculator, setCalculator, projectedRevenue, plans, planForm, setPlanForm, savePlan, togglePlan, canManagePlans, statuses }) {
  if (view === "finance-overview") return <OverviewView report={report} calculator={calculator} setCalculator={setCalculator} projectedRevenue={projectedRevenue} />;
  if (view === "finance-subscriptions") return <section className="panel-card finance-workspace-panel"><div className="panel-heading"><div><div className="eyebrow">Farm subscriptions</div><h2>Subscription coverage</h2></div><span>{report?.subscriptions?.length || 0} farms</span></div><SubscriptionRows subscriptions={report?.subscriptions || []} /></section>;
  if (view === "finance-payments") return <PaymentsView report={report} />;
  if (view === "finance-plans") return <PlansView plans={plans} planForm={planForm} setPlanForm={setPlanForm} savePlan={savePlan} togglePlan={togglePlan} canManagePlans={canManagePlans} />;
  return <ReportingView report={report} />;
}
