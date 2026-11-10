import { useEffect, useMemo, useState } from "react";
import { api } from "../api";
import "./operations-finance.css";

const animalStatuses = [["active", "Active"], ["sold", "Sold"], ["deceased", "Deceased"]];
const modules = [
  {
    id: "herd", label: "Herd", endpoint: "animals", permissions: ["manageHerd"],
    columns: [["id", "ID"], ["tag", "Tag"], ["type", "Type"], ["sex", "Sex"], ["status", "Status"]],
    fields: [
      { key: "tag", label: "Tag", required: true },
      { key: "status", label: "Status", type: "select", options: animalStatuses },
      { key: "birth_date", label: "Birth date", type: "date" },
      { key: "notes", label: "Notes", type: "textarea" },
    ],
  },
  {
    id: "health", label: "Health", endpoint: "health-records", permissions: ["manageHealth"],
    columns: [["animal_id", "Animal ID"], ["pig_id", "Pig tag"], ["type", "Record"], ["status", "Status"], ["diagnosis", "Diagnosis"], ["visit_date", "Date"]],
    fields: [
      { key: "animal_id", label: "Animal ID", type: "number", required: true },
      { key: "type", label: "Record type", type: "select", options: [["vaccination", "Vaccination"], ["treatment", "Treatment"], ["deworming", "Deworming"], ["mortality", "Mortality"]], required: true },
      { key: "status", label: "Health status", type: "select", options: [["healthy", "Healthy"], ["recovering", "Recovering"], ["critical", "Critical"], ["deceased", "Deceased"]], required: true },
      { key: "diagnosis", label: "Diagnosis" },
      { key: "medication", label: "Medication" },
      { key: "visit_date", label: "Visit date", type: "date" },
      { key: "notes", label: "Notes", type: "textarea" },
    ],
  },
  {
    id: "breeding", label: "Breeding", endpoint: "pregnancies", permissions: ["manageBreeding"],
    columns: [["sow_id", "Sow ID"], ["sow.tag", "Sow"], ["status", "Status"], ["mating_date", "Mating date"], ["expected_farrowing_date", "Expected farrowing"]],
    fields: [
      { key: "sow_id", label: "Sow animal ID", type: "number", required: true },
      { key: "boar_id", label: "Boar animal ID", type: "number" },
      { key: "mating_date", label: "Mating date", type: "date", required: true },
      { key: "confirmation_date", label: "Confirmation date", type: "date" },
      { key: "expected_farrowing_date", label: "Expected farrowing", type: "date" },
      { key: "status", label: "Status", type: "select", options: [["suspected", "Suspected"], ["confirmed", "Confirmed"], ["high_risk", "High risk"], ["farrowed", "Farrowed"], ["aborted", "Aborted"]] },
      { key: "expected_litter_size", label: "Expected litter size", type: "number" },
      { key: "notes", label: "Notes", type: "textarea" },
    ],
  },
  {
    id: "feed", label: "Feed", endpoint: "feed", permissions: ["manageFeed"],
    columns: [["record_type", "Record"], ["name", "Feed"], ["quantity", "Quantity"], ["unit", "Unit"], ["unit_cost", "Unit cost"]],
    fields: [],
  },
  {
    id: "inventory", label: "Inventory", endpoint: "inventory/items", permissions: ["manageInventory"],
    columns: [["name", "Item"], ["category", "Category"], ["quantity", "Quantity"], ["unit", "Unit"], ["minimumLevel", "Minimum"]],
    fields: [
      { key: "name", label: "Item name", required: true },
      { key: "category", label: "Category", type: "select", options: ["Feed", "Medicine", "Vaccines", "Equipment", "Cleaning", "RFID", "Other"].map((item) => [item, item]), required: true },
      { key: "sku", label: "SKU", required: true },
      { key: "quantity", label: "Opening quantity", type: "number", required: true },
      { key: "unit", label: "Unit", required: true },
      { key: "minimum_level", label: "Minimum level", type: "number", required: true },
      { key: "cost_price", label: "Unit cost", type: "number", required: true },
      { key: "supplier", label: "Supplier" },
      { key: "expiry_date", label: "Expiry date", type: "date" },
      { key: "storage_location", label: "Storage location" },
      { key: "notes", label: "Notes", type: "textarea" },
    ],
  },
  {
    id: "growth", label: "Growth", endpoint: "growth-records", permissions: ["manageGrowth", "manageHerd", "manageHealth"],
    columns: [["animal_id", "Animal ID"], ["current_weight", "Weight"], ["measurement_date", "Measured"]],
    fields: [
      { key: "animal_id", label: "Animal ID", type: "number", required: true },
      { key: "current_weight", label: "Current weight", type: "number", required: true },
      { key: "measurement_date", label: "Measurement date and time", type: "datetime-local", required: true },
      { key: "notes", label: "Notes", type: "textarea" },
    ],
  },
  { id: "reports", label: "Reports", endpoint: "reports/metrics", columns: [], fields: [] },
];

const feedStockFields = [
  { key: "name", label: "Feed name", required: true },
  { key: "quantity", label: "Quantity received", type: "number", required: true },
  { key: "unit", label: "Unit", required: true },
  { key: "unit_cost", label: "Unit cost", type: "number" },
  { key: "location", label: "Storage location" },
];
const feedUsageFields = [
  { key: "feed_stock_id", label: "Feed stock ID", type: "number" },
  { key: "quantity", label: "Quantity used", type: "number", required: true },
  { key: "unit", label: "Unit", required: true },
  { key: "used_at", label: "Date used", type: "date", required: true },
  { key: "notes", label: "Notes", type: "textarea" },
];
const inventoryMovementFields = [
  { key: "type", label: "Movement", type: "select", options: [["stock_in", "Stock in"], ["stock_out", "Stock out"], ["adjustment", "Set quantity"], ["expired", "Expired"]], required: true },
  { key: "quantity", label: "Quantity", type: "number", required: true },
  { key: "reference", label: "Reference" },
  { key: "notes", label: "Notes", type: "textarea" },
];

function rowsFor(moduleId, payload) {
  if (moduleId === "feed") {
    return [
      ...(payload?.stock || []).map((item) => ({ ...item, record_type: "Stock" })),
      ...(payload?.usage || []).map((item) => ({ ...item, name: item.feed_name, record_type: "Usage" })),
    ];
  }
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.data?.data)) return payload.data.data;
  return [];
}

function fieldValue(field, value) {
  if (value === null || value === undefined) return "";
  if (field.type === "date" && value) return String(value).slice(0, 10);
  if (field.type === "datetime-local" && value) return new Date(value).toISOString().slice(0, 16);
  return String(value);
}

function valueAtPath(row, path) {
  return path.split(".").reduce((value, key) => value?.[key], row);
}

function displayValue(value) {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

export function FarmOperationsWorkspace({ farmId, canView, managePermissions = [], refreshKey = 0 }) {
  const [moduleId, setModuleId] = useState("herd");
  const [payload, setPayload] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [editor, setEditor] = useState(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");
  const activeModule = useMemo(() => modules.find((item) => item.id === moduleId) || modules[0], [moduleId]);
  const isFeedUsage = editor?.record_type === "usage";
  const isInventoryMovement = editor?.action === "movement";
  const fields = moduleId === "feed"
    ? (isFeedUsage ? feedUsageFields : feedStockFields)
    : isInventoryMovement
      ? inventoryMovementFields
      : moduleId === "inventory" && editor?.id
        ? activeModule.fields.filter((field) => field.key !== "quantity")
        : activeModule.fields;
  const canManageModule = activeModule.permissions?.some((permission) => managePermissions.includes(permission)) || false;

  useEffect(() => {
    if (!farmId || !canView) return undefined;
    let active = true;
    setLoading(true);
    setError("");
    setPayload(null);
    api.get(`/farms/${encodeURIComponent(farmId)}/${activeModule.endpoint}`, { params: { _refresh: Date.now() } })
      .then((response) => {
        if (active) setPayload(response.data?.data ?? response.data ?? {});
      })
      .catch((requestError) => {
        if (active) setError(requestError.response?.data?.message || `Could not load ${activeModule.label.toLowerCase()} data.`);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [farmId, canView, activeModule, refreshKey, reloadKey]);

  const startCreate = () => {
    setFormError("");
    setEditor({
      id: null,
      action: "create",
      record_type: "stock",
      values: moduleId === "growth"
        ? { measurement_date: new Date().toISOString().slice(0, 16) }
        : moduleId === "feed"
          ? { used_at: new Date().toISOString().slice(0, 10) }
          : {},
    });
  };

  const startEdit = (row) => {
    setFormError("");
    const values = Object.fromEntries(activeModule.fields.map((field) => {
      const alias = moduleId === "inventory"
        ? { minimum_level: "minimumLevel", cost_price: "costPrice", expiry_date: "expiryDate", storage_location: "storageLocation" }[field.key]
        : null;
      return [field.key, fieldValue(field, row[field.key] ?? (alias ? row[alias] : undefined))];
    }));
    setEditor({ id: row.id, action: "edit", values });
  };

  const startInventoryMovement = (row) => {
    setFormError("");
    setEditor({ id: row.id, action: "movement", values: {} });
  };

  const saveRecord = async (event) => {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    const values = { ...editor.values };
    let endpoint = `/farms/${farmId}/${activeModule.endpoint}`;
    let data = values;
    if (moduleId === "herd" && !editor.id) data = { ...data, type: "sow", sex: "female" };
    if (moduleId === "feed") {
      endpoint += isFeedUsage ? "/usage" : "/stock";
      if (isFeedUsage && data.feed_stock_id) data.feed_stock_id = Number(data.feed_stock_id);
    } else if (isInventoryMovement) {
      endpoint += `/${editor.id}/movements`;
    } else if (editor.id) {
      endpoint += `/${editor.id}`;
    }
    if (moduleId === "inventory") {
      data = {
        ...data,
        ...(data.minimum_level !== undefined ? { minimum_level: Number(data.minimum_level) } : {}),
        ...(data.cost_price !== undefined ? { cost_price: Number(data.cost_price) } : {}),
        ...(data.quantity !== undefined ? { quantity: Number(data.quantity) } : {}),
      };
    }
    if (moduleId === "growth" && data.measurement_date) data.measurement_date = new Date(data.measurement_date).toISOString().replace(".000Z", "Z");
    if (moduleId === "health" && data.animal_id) data.animal_id = Number(data.animal_id);
    if (moduleId === "breeding") {
      ["sow_id", "boar_id", "expected_litter_size"].forEach((key) => {
        if (data[key]) data[key] = Number(data[key]);
      });
    }
    try {
      if (isInventoryMovement) await api.post(endpoint, data);
      else if (editor.id) await api.patch(endpoint, data);
      else await api.post(endpoint, data);
      setEditor(null);
      setReloadKey((key) => key + 1);
    } catch (requestError) {
      setFormError(requestError.response?.data?.message || "Could not save this farm record.");
    } finally {
      setSaving(false);
    }
  };

  if (!canView) return <section className="panel-card operations-state">Your CRM role does not have access to farm operations.</section>;
  if (!farmId) return <section className="panel-card operations-state">Select a farm to view its operational records.</section>;

  const rows = rowsFor(moduleId, payload);
  const reportMetrics = moduleId === "reports" && payload && typeof payload === "object" ? (payload.metrics || payload.data || payload) : null;
  const metrics = reportMetrics && !Array.isArray(reportMetrics) && typeof reportMetrics === "object" ? Object.entries(reportMetrics) : [];

  return <section className="operations-workspace">
    <div className="operations-module-tabs" role="tablist" aria-label="Farm operations">
      {modules.map((item) => <button key={item.id} type="button" role="tab" aria-selected={moduleId === item.id} className={moduleId === item.id ? "selected" : ""} onClick={() => { setModuleId(item.id); setEditor(null); }}>{item.label}</button>)}
    </div>
    <div className="operations-toolbar">{canManageModule && moduleId !== "reports" && <button className="primary-button" type="button" onClick={startCreate}>＋ Add {activeModule.label.toLowerCase()} record</button>}<button className="filter-button" type="button" onClick={() => setReloadKey((key) => key + 1)} disabled={loading}>Refresh</button></div>
    {editor && <form className="panel-card operations-editor" onSubmit={saveRecord}>
      <div className="panel-heading"><div><div className="eyebrow">{isInventoryMovement ? "Stock movement" : editor.id ? "Update record" : "New record"}</div><h2>{isInventoryMovement ? "Record an inventory movement" : editor.id ? `Edit ${activeModule.label.toLowerCase()}` : `Add ${activeModule.label.toLowerCase()} record`}</h2></div><button className="filter-button" type="button" onClick={() => setEditor(null)}>Cancel</button></div>
      {moduleId === "feed" && <label>Record type<select value={editor.record_type} onChange={(event) => setEditor((current) => ({ ...current, record_type: event.target.value, values: {} }))}><option value="stock">Feed stock received</option><option value="usage">Feed usage</option></select></label>}
      <div className="operations-editor-fields">{fields.map((field) => <label key={field.key}>{field.label}{field.type === "select" ? <select required={field.required} value={editor.values[field.key] ?? ""} onChange={(event) => setEditor((current) => ({ ...current, values: { ...current.values, [field.key]: event.target.value } }))}><option value="">Select…</option>{field.options.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select> : field.type === "textarea" ? <textarea required={field.required} rows="3" value={editor.values[field.key] ?? ""} onChange={(event) => setEditor((current) => ({ ...current, values: { ...current.values, [field.key]: event.target.value } }))} /> : <input required={field.required} type={field.type || "text"} min={field.type === "number" ? "0" : undefined} step={field.type === "number" ? "any" : undefined} value={editor.values[field.key] ?? ""} onChange={(event) => setEditor((current) => ({ ...current, values: { ...current.values, [field.key]: event.target.value } }))} />}</label>)}</div>
      {formError && <div className="state-message error" role="alert">{formError}</div>}
      <button className="primary-button" type="submit" disabled={saving}>{saving ? "Saving…" : "Save record"}</button>
    </form>}
    {loading ? <div className="panel-card operations-state">Loading {activeModule.label.toLowerCase()}…</div> : error ? <div className="panel-card operations-state error" role="alert">{error}</div> : moduleId === "reports" ? (
      <div className="operations-metrics">{metrics.length ? metrics.map(([label, value]) => <article className="panel-card operations-metric" key={label}><span>{label.replaceAll("_", " ")}</span><strong>{displayValue(value)}</strong></article>) : <div className="panel-card operations-state">No report metrics are available for this farm.</div>}</div>
    ) : <div className="panel-card operations-table-card">{rows.length ? <div className="operations-table-scroll"><table className="operations-table"><thead><tr>{activeModule.columns.map(([key, label]) => <th key={key}>{label}</th>)}{canManageModule && activeModule.fields.length > 0 && <th>Actions</th>}</tr></thead><tbody>{rows.map((row, index) => <tr key={row.id || `${moduleId}-${index}`}>{activeModule.columns.map(([key]) => <td key={key}>{displayValue(valueAtPath(row, key))}</td>)}{canManageModule && activeModule.fields.length > 0 && <td className="operations-row-actions"><button className="filter-button" type="button" onClick={() => startEdit(row)}>Edit</button>{moduleId === "inventory" && <button className="filter-button" type="button" onClick={() => startInventoryMovement(row)}>Adjust stock</button>}</td>}</tr>)}</tbody></table></div> : <div className="operations-state">No {activeModule.label.toLowerCase()} records for this farm yet.</div>}</div>}
  </section>;
}
