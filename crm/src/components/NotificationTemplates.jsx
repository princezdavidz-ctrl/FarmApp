import { useEffect, useState } from "react";
import { api } from "../api";

const emptyTemplate = { title: "", message: "", active: true };

export function NotificationTemplates({ onUse, isGlobalAdmin }) {
  const [templates, setTemplates] = useState([]);
  const [form, setForm] = useState(emptyTemplate);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    if (!isGlobalAdmin) { setLoading(false); return; }
    try {
      const response = await api.get("/crm/admin/notification-templates");
      setTemplates(response.data?.data || []);
      setError("");
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not load notification templates.");
    } finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [isGlobalAdmin]);

  const submit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const response = editingId
        ? await api.patch(`/crm/admin/notification-templates/${editingId}`, form)
        : await api.post("/crm/admin/notification-templates", form);
      const saved = response.data.data;
      setTemplates((current) => editingId ? current.map((item) => item.id === saved.id ? saved : item) : [saved, ...current]);
      setForm(emptyTemplate);
      setEditingId(null);
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not save this template.");
    } finally { setSaving(false); }
  };

  const edit = (template) => {
    setEditingId(template.id);
    setForm({ title: template.title, message: template.message, active: template.active });
  };

  const remove = async (template) => {
    if (!window.confirm(`Delete template “${template.title}”?`)) return;
    try {
      await api.delete(`/crm/admin/notification-templates/${template.id}`);
      setTemplates((current) => current.filter((item) => item.id !== template.id));
    } catch (requestError) {
      setError(requestError.response?.data?.message || "Could not delete this template.");
    }
  };

  return <section className="panel-card communication-workspace-panel">
    <div className="panel-heading"><div><div className="eyebrow">Reusable in-app notifications</div><h2>Communication templates</h2></div><span>{isGlobalAdmin ? `${templates.length} saved` : "Read-only"}</span></div>
    {!isGlobalAdmin && <div className="state-message">Only the central CRM administrator can create or manage shared notification templates.</div>}
    {error && <div className="notice error" role="alert">{error}</div>}
    {isGlobalAdmin && <form className="communication-composer" onSubmit={submit}>
      <label>Template title<input required maxLength="160" value={form.title} onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))} /></label>
      <label>Notification message<textarea required maxLength="1000" rows="4" value={form.message} onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))} /></label>
      <label className="template-active-toggle"><input type="checkbox" checked={Boolean(form.active)} onChange={(event) => setForm((current) => ({ ...current, active: event.target.checked }))} /> Available for use</label>
      <div className="form-actions"><button type="button" className="ghost-button" onClick={() => { setForm(emptyTemplate); setEditingId(null); }}>Clear</button><button className="primary-button" type="submit" disabled={saving}>{saving ? "Saving…" : editingId ? "Save changes" : "Create template"}</button></div>
    </form>}
    {loading ? <div className="state-message">Loading templates…</div> : templates.length === 0 ? <div className="state-message">No saved templates yet.</div> : <div className="communication-message-list">{templates.map((template) => <article className="communication-message-row" key={template.id}><div><strong>{template.title}</strong><small>{template.active ? "Available" : "Inactive"}</small></div><p>{template.message}</p><div className="form-actions"><button className="primary-button" type="button" disabled={!template.active} onClick={() => onUse(template)}>Use template</button>{isGlobalAdmin && <><button className="filter-button" type="button" onClick={() => edit(template)}>Edit</button><button className="filter-button" type="button" onClick={() => remove(template)}>Delete</button></>}</div></article>)}</div>}
  </section>;
}
