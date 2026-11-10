import { useEffect, useState } from "react";
import { api } from "../api";

const emptyProspect = { owner_name: "", email: "", phone: "", farm_name: "", status: "new", notes: "" };
const statuses = ["new", "contacted", "qualified", "converted", "closed"];

export function FarmOwnerProspects() {
  const [prospects, setProspects] = useState([]);
  const [form, setForm] = useState(emptyProspect);
  const [editingId, setEditingId] = useState(null);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const response = await api.get("/crm/admin/prospects", { params: search ? { search } : {} });
      setProspects(response.data?.data || []);
      setError("");
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not load farm-owner prospects.");
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => { load(); }, [search]);

  const submit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const response = editingId
        ? await api.patch(`/crm/admin/prospects/${editingId}`, form)
        : await api.post("/crm/admin/prospects", form);
      const saved = response.data.data;
      setProspects((current) => editingId ? current.map((item) => item.id === saved.id ? saved : item) : [saved, ...current]);
      setForm(emptyProspect);
      setEditingId(null);
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not save the prospect.");
    } finally {
      setSaving(false);
    }
  };

  const edit = (prospect) => {
    setEditingId(prospect.id);
    setForm({ owner_name: prospect.owner_name, email: prospect.email || "", phone: prospect.phone || "", farm_name: prospect.farm_name, status: prospect.status, notes: prospect.notes || "" });
  };

  const remove = async (prospect) => {
    if (!window.confirm(`Delete ${prospect.owner_name} / ${prospect.farm_name}?`)) return;
    try {
      await api.delete(`/crm/admin/prospects/${prospect.id}`);
      setProspects((current) => current.filter((item) => item.id !== prospect.id));
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not delete the prospect.");
    }
  };

  return <section className="panel-card crm-tools">
    <div className="panel-heading"><div><div className="eyebrow">Central CRM · Sales pipeline</div><h2>Farm-owner prospects</h2></div><span>{prospects.length} shown</span></div>
    {error && <div className="notice error" role="alert">{error}</div>}
    <form className="customer-form" onSubmit={submit}>
      <h3>{editingId ? "Edit prospect" : "Add a prospective farm owner"}</h3>
      <div className="form-two">
        <label>Owner name<input required maxLength="255" value={form.owner_name} onChange={(event) => setForm((current) => ({ ...current, owner_name: event.target.value }))} /></label>
        <label>Farm name<input required maxLength="255" value={form.farm_name} onChange={(event) => setForm((current) => ({ ...current, farm_name: event.target.value }))} /></label>
      </div>
      <div className="form-two">
        <label>Email<input type="email" value={form.email} onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))} /></label>
        <label>Phone<input value={form.phone} onChange={(event) => setForm((current) => ({ ...current, phone: event.target.value }))} /></label>
      </div>
      <div className="form-two">
        <label>Status<select value={form.status} onChange={(event) => setForm((current) => ({ ...current, status: event.target.value }))}>{statuses.map((status) => <option key={status} value={status}>{status[0].toUpperCase() + status.slice(1)}</option>)}</select></label>
        <label>Notes<textarea rows="2" value={form.notes} onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))} /></label>
      </div>
      <div className="form-actions"><button className="ghost-button" type="button" onClick={() => { setEditingId(null); setForm(emptyProspect); }}>Clear</button><button className="primary-button" type="submit" disabled={saving}>{saving ? "Saving…" : editingId ? "Save prospect" : "Add prospect"}</button></div>
    </form>
    <div className="panel-heading"><h3>Prospect list</h3><input aria-label="Search prospects" placeholder="Search name, farm, email, phone" value={search} onChange={(event) => setSearch(event.target.value)} /></div>
    {loading ? <div className="state-message">Loading prospects…</div> : prospects.length === 0 ? <div className="state-message">No farm-owner prospects yet.</div> : <div className="communication-message-list">{prospects.map((prospect) => <article className="communication-message-row" key={prospect.id}><div><strong>{prospect.owner_name} · {prospect.farm_name}</strong><small>{[prospect.email, prospect.phone, `Status: ${prospect.status}`].filter(Boolean).join(" · ")}</small></div><p>{prospect.notes || "No notes"}</p><div className="form-actions"><button className="filter-button" type="button" onClick={() => edit(prospect)}>Edit</button><button className="filter-button" type="button" onClick={() => remove(prospect)}>Delete</button></div></article>)}</div>}
  </section>;
}
