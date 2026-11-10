import { useState } from "react";
import "./operations-finance.css";

const emptyEntry = {
  type: "income",
  category: "",
  description: "",
  amount: "",
  currency: "KES",
  occurred_at: new Date().toISOString().slice(0, 10),
};

function formatAmount(amount, currency) {
  return `${Number(amount || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${currency}`;
}

export function FarmFinanceLedger({ ledger, loading, onRefresh, onCreate }) {
  const [entry, setEntry] = useState(emptyEntry);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const submit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await onCreate({ ...entry, amount: Number(entry.amount), currency: entry.currency.trim().toUpperCase() });
      setEntry({ ...emptyEntry, occurred_at: new Date().toISOString().slice(0, 10) });
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not save this transaction.");
    } finally {
      setSaving(false);
    }
  };

  return <section className="farm-finance-ledger">
    <section className="panel-card finance-workspace-panel">
      <div className="panel-heading"><div><div className="eyebrow">Farm finances</div><h2>Income and expenses</h2></div><button className="filter-button" type="button" onClick={onRefresh} disabled={loading}>Refresh</button></div>
      <p className="settings-note">Farm transactions are separate from subscription payments and CRM revenue reports.</p>
      <form className="farm-finance-entry-form" onSubmit={submit}>
        <label>Type<select value={entry.type} onChange={(event) => setEntry((current) => ({ ...current, type: event.target.value }))}><option value="income">Income</option><option value="expense">Expense</option></select></label>
        <label>Category<input required maxLength="80" value={entry.category} onChange={(event) => setEntry((current) => ({ ...current, category: event.target.value }))} /></label>
        <label>Description<input required maxLength="255" value={entry.description} onChange={(event) => setEntry((current) => ({ ...current, description: event.target.value }))} /></label>
        <label>Amount<input required type="number" min="0.01" step="0.01" value={entry.amount} onChange={(event) => setEntry((current) => ({ ...current, amount: event.target.value }))} /></label>
        <label>Currency<input required minLength="3" maxLength="3" pattern="[A-Za-z]{3}" value={entry.currency} onChange={(event) => setEntry((current) => ({ ...current, currency: event.target.value }))} /></label>
        <label>Date<input required type="date" value={entry.occurred_at} onChange={(event) => setEntry((current) => ({ ...current, occurred_at: event.target.value }))} /></label>
        <button className="primary-button" type="submit" disabled={saving}>{saving ? "Saving…" : "Add transaction"}</button>
      </form>
      {error && <div className="state-message error" role="alert">{error}</div>}
    </section>

    <section className="panel-card finance-workspace-panel">
      <div className="panel-heading"><div><div className="eyebrow">This month</div><h2>Farm ledger totals</h2></div><span>{ledger?.summary?.period_start || "—"} to {ledger?.summary?.period_end || "—"}</span></div>
      {loading && !ledger ? <div className="state-message">Loading farm transactions…</div> : (ledger?.summary?.totals || []).length === 0 ? <div className="state-message">No farm transactions recorded this month.</div> : <div className="finance-kpis">{ledger.summary.totals.map((total) => <div className="finance-kpi" key={total.currency}><span>{total.currency} income</span><strong>{formatAmount(total.income, total.currency)}</strong><small>Expenses {formatAmount(total.expenses, total.currency)} · Net {formatAmount(total.profit, total.currency)}</small></div>)}</div>}
    </section>

    <section className="panel-card finance-workspace-panel">
      <div className="panel-heading"><div><div className="eyebrow">Farm records</div><h2>Transaction history</h2></div><span>{ledger?.data?.length || 0} recent</span></div>
      {loading && !ledger ? <div className="state-message">Loading transaction history…</div> : !ledger?.data?.length ? <div className="state-message">No farm transactions available yet.</div> : <div className="finance-record-list">{ledger.data.map((transaction) => <article className="finance-record-row" key={transaction.id}><div><strong>{transaction.category}</strong><span>{transaction.description}</span></div><span className={`payment-status ${transaction.type === "income" ? "paid" : "pending"}`}>{transaction.type}</span><strong>{formatAmount(transaction.amount, transaction.currency)}</strong><time>{transaction.occurred_at}</time></article>)}</div>}
    </section>
  </section>;
}
