import { useEffect, useState } from "react";
import { api } from "../api";

export function FarmNameChangeRequests() {
  const [requests, setRequests] = useState([]);
  const [notes, setNotes] = useState({});
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const response = await api.get("/crm/farm-name-change-requests", { params: { status: "pending" } });
      setRequests(response.data?.data || []);
      setError("");
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not load farm name requests.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const review = async (item, status) => {
    setSavingId(item.id);
    setError("");
    try {
      await api.patch(`/crm/farm-name-change-requests/${item.id}`, {
        status,
        review_notes: notes[item.id] || "",
      });
      setRequests((current) => current.filter((request) => request.id !== item.id));
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not review this request.");
    } finally {
      setSavingId(null);
    }
  };

  return <section className="panel-card settings-workspace-panel">
    <div className="panel-heading">
      <div><div className="eyebrow">Farm settings</div><h2>Farm name approvals</h2></div>
      <button className="filter-button" type="button" onClick={load} disabled={loading}>Refresh</button>
    </div>
    <p className="settings-note">Review farm-owner name requests. The farm name changes only after approval.</p>
    {error && <div className="notice error" role="alert">{error}</div>}
    {loading ? <div className="state-message">Loading requests…</div>
      : requests.length === 0 ? <div className="state-message">No farm name changes are awaiting approval.</div>
      : <div className="settings-member-list">{requests.map((item) => <article className="settings-member-row" key={item.id}>
        <div>
          <strong>{item.farm_name}: {item.current_name} → {item.requested_name}</strong>
          <span>Requested by {item.requested_by}{item.requester_email ? ` · ${item.requester_email}` : ""}</span>
          <small>{item.created_at ? new Date(item.created_at).toLocaleString() : ""}</small>
        </div>
        <div className="permission-editor">
          <label>Review notes<textarea rows="2" value={notes[item.id] || ""} onChange={(event) => setNotes((current) => ({ ...current, [item.id]: event.target.value }))} /></label>
          <div className="form-actions">
            <button className="filter-button" type="button" disabled={savingId === item.id} onClick={() => review(item, "rejected")}>Reject</button>
            <button className="primary-button" type="button" disabled={savingId === item.id} onClick={() => review(item, "approved")}>{savingId === item.id ? "Saving…" : "Approve name"}</button>
          </div>
        </div>
      </article>)}</div>}
  </section>;
}
