import { useEffect, useState } from "react";
import { api } from "../api";
import "./operations-finance.css";

const PAGE_SIZE = 50;
const operationTables = {
  "operations-feed-orders": {
    endpoint: "/crm/operations/feed-orders",
    title: "Feed orders",
    description: "Feed stock receipts recorded by farms in the farm app.",
    columns: [
      ["farm_name", "Farm"],
      ["feed", "Feed"],
      ["quantity", "Quantity"],
      ["unit", "Unit"],
      ["unit_cost", "Unit cost"],
      ["location", "Storage location"],
      ["recorded_by", "Recorded by"],
      ["created_at", "Recorded"],
    ],
  },
  "operations-medicine-orders": {
    endpoint: "/crm/operations/medicine-orders",
    title: "Medicine orders",
    description: "Medicine inventory stock-in records, including recorded purchase references.",
    columns: [
      ["farm_name", "Farm"],
      ["medicine", "Medicine"],
      ["quantity", "Quantity"],
      ["unit", "Unit"],
      ["unit_cost", "Unit cost"],
      ["reference", "Order reference"],
      ["recorded_by", "Recorded by"],
      ["created_at", "Recorded"],
    ],
  },
  "operations-emergencies": {
    endpoint: "/crm/operations/emergencies",
    title: "Emergencies",
    description: "Urgent health records reported in the farm app: critical, recovering, or mortality cases.",
    columns: [
      ["farm_name", "Farm"],
      ["pig_tag", "Pig tag"],
      ["type", "Record type"],
      ["status", "Status"],
      ["diagnosis", "Diagnosis"],
      ["symptoms", "Symptoms"],
      ["medication", "Medication"],
      ["reported_by", "Reported by"],
      ["reported_at", "Reported"],
    ],
  },
};

function cellValue(value) {
  if (value === null || value === undefined || value === "") return "—";
  if (Array.isArray(value)) return value.length ? value.join(", ") : "—";
  if (typeof value === "object") return JSON.stringify(value);
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
  }
  return String(value);
}

function FarmDirectory({ farms, loading, error, onRefresh }) {
  return (
    <section className="farm-operations-page">
      <header className="panel-card operations-page-heading">
        <div>
          <div className="eyebrow">Farm directory</div>
          <h2>Registered farms</h2>
          <p>Farms available to your CRM account.</p>
        </div>
        <button className="filter-button" type="button" onClick={onRefresh} disabled={loading}>
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </header>
      {loading ? (
        <div className="panel-card operations-state" role="status">Loading farms…</div>
      ) : error ? (
        <div className="panel-card operations-state error" role="alert">{error}</div>
      ) : farms.length === 0 ? (
        <div className="panel-card operations-state">No farms are available to this CRM account.</div>
      ) : (
        <div className="panel-card operations-table-card">
          <div className="operations-table-scroll">
            <table className="operations-table">
              <thead>
                <tr><th>Farm</th><th>Location</th><th>Farm owner</th><th>Managers</th><th>Workers</th></tr>
              </thead>
              <tbody>
                {farms.map((farm) => {
                  const members = farm.members || [];
                  return (
                    <tr key={farm.id}>
                      <td>{farm.name || "—"}</td>
                      <td>{farm.location || "—"}</td>
                      <td>{members.filter((member) => member.role === "farmOwner").map((member) => member.name).join(", ") || "—"}</td>
                      <td>{members.filter((member) => member.role === "farmManager").length}</td>
                      <td>{members.filter((member) => member.role === "farmWorker").length}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}

function OperationsTable({ view, refreshKey, onRefresh }) {
  const config = operationTables[view];
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, total: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    api.get(config.endpoint, { params: { page, per_page: PAGE_SIZE } })
      .then((response) => {
        if (!active) return;
        setRows(response.data?.data || []);
        setMeta(response.data?.meta || { current_page: 1, last_page: 1, total: 0 });
      })
      .catch((requestError) => {
        if (active) {
          setError(requestError.response?.data?.message || `Could not load ${config.title.toLowerCase()}.`);
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [config.endpoint, page, refreshKey]);

  return (
    <section className="farm-operations-page">
      <header className="panel-card operations-page-heading">
        <div>
          <div className="eyebrow">Farm records</div>
          <h2>{config.title}</h2>
          <p>{config.description}</p>
        </div>
        <button className="filter-button" type="button" onClick={onRefresh} disabled={loading}>
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </header>
      {loading ? (
        <div className="panel-card operations-state" role="status">Loading {config.title.toLowerCase()}…</div>
      ) : error ? (
        <div className="panel-card operations-state error" role="alert">{error}</div>
      ) : rows.length === 0 ? (
        <div className="panel-card operations-state">No {config.title.toLowerCase()} records found.</div>
      ) : (
        <div className="panel-card operations-table-card">
          <div className="operations-table-scroll">
            <table className="operations-table">
              <thead><tr>{config.columns.map(([, label]) => <th key={label}>{label}</th>)}</tr></thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id}>
                    {config.columns.map(([field]) => <td key={field}>{cellValue(row[field])}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="operations-pagination">
            <span>{meta.total} records · Page {meta.current_page} of {meta.last_page}</span>
            <div>
              <button className="filter-button" type="button" disabled={loading || page <= 1} onClick={() => setPage((current) => Math.max(1, current - 1))}>Previous</button>
              <button className="filter-button" type="button" disabled={loading || page >= meta.last_page} onClick={() => setPage((current) => current + 1)}>Next</button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

export function CrmFarmOperations({
  view,
  farms,
  isGlobalAdmin,
  refreshKey,
  onRefresh,
}) {
  const [registeredFarms, setRegisteredFarms] = useState([]);
  const [farmsLoading, setFarmsLoading] = useState(true);
  const [farmsError, setFarmsError] = useState("");
  const [farmsReload, setFarmsReload] = useState(0);

  useEffect(() => {
    if (view !== "operations-farms") return undefined;
    let active = true;
    setFarmsLoading(true);
    setFarmsError("");

    const request = isGlobalAdmin
      ? api.get("/crm/admin/farms")
      : api.get("/crm/directories/overview");

    request
      .then((response) => {
        if (!active) return;
        const data = response.data?.data || [];
        setRegisteredFarms(isGlobalAdmin
          ? data
          : (data.relationships || []).map((farm) => ({
              id: farm.farm_id,
              name: farm.farm_name,
              location: farm.location,
              members: [
                ...(farm.owner ? [farm.owner] : []),
                ...(farm.managers || []),
                ...(farm.workers || []),
              ],
            })));
      })
      .catch((requestError) => {
        if (active) setFarmsError(requestError.response?.data?.message || "Could not load the farm directory.");
      })
      .finally(() => {
        if (active) setFarmsLoading(false);
      });

    return () => { active = false; };
  }, [view, isGlobalAdmin, farmsReload, refreshKey]);

  if (view === "operations-farms") {
    return (
      <FarmDirectory
        farms={registeredFarms.length || farmsError ? registeredFarms : farms}
        loading={farmsLoading}
        error={farmsError}
        onRefresh={() => {
          setFarmsReload((current) => current + 1);
          onRefresh();
        }}
      />
    );
  }
  return <OperationsTable view={view} refreshKey={refreshKey} onRefresh={onRefresh} />;
}
