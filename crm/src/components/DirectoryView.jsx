import { useEffect, useState } from "react";

function roleLabel(role) {
  return { farmOwner: "Farm Owner", farmManager: "Farm Manager", farmWorker: "Farm Worker" }[role] || role || "-";
}

function DirectoryTable({ rows, farmOwners = false }) {
  if (!rows.length) return <div className="state-message">No members match this directory.</div>;
  return <div className="data-table-wrap directory-grid-table"><table className="data-table"><thead><tr><th>Name</th><th>Farm name</th><th>Phone number</th><th>Email</th>{farmOwners && <><th>Account</th><th>Total pigs</th><th>Mother pigs</th><th>Piglets</th><th>Piglet ages</th></>}</tr></thead><tbody>{rows.map((row) => <tr key={`${row.farm_id}-${row.id}`}><td><strong>{row.name}</strong></td><td>{row.farm_name || "-"}</td><td>{row.phone || "-"}</td><td>{row.email || "-"}</td>{farmOwners ? <><td><span className={`status-label ${row.status === "active" ? "won" : "lost"}`}>{row.status || "pending"}</span><small className="directory-subvalue">Payment: {row.payment_status || "pending"}</small></td><td>{row.number_of_pigs ?? 0}</td><td>{row.mother_pigs ?? 0}</td><td>{row.piglets ?? 0}</td><td>{row.piglet_age_groups?.length ? row.piglet_age_groups.map((group) => `${group.count} at ${group.age_months} mo`).join(", ") : "-"}</td></> : <><td>{roleLabel(row.role)}</td><td><span className={`status-label ${row.status === "active" ? "won" : "lost"}`}>{row.status || "active"}</span></td></>}</tr>)}</tbody></table></div>;
}

function RelationshipTable({ rows, search, setSearch, onRefresh }) {
  if (!rows.length) return <div className="state-message">No accessible farms found.</div>;
  const filteredRows = rows.filter((row) => [row.farm_name, row.owner?.name, row.owner?.phone, row.owner?.email, ...(row.managers || []).map((member) => member.name), ...(row.workers || []).map((member) => member.name), row.status].join(" ").toLowerCase().includes(search.toLowerCase()));
  return <section className="panel-card directory-panel"><div className="panel-heading"><div><div className="eyebrow">Farm relationships</div><h2>Farm ownership and team</h2></div><div className="directory-actions"><span>{filteredRows.length} farms</span><button className="filter-button" type="button" onClick={onRefresh}>Refresh</button></div></div><label className="directory-search"><span>⌕</span><input aria-label="Search relationships" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search farm, owner, manager, or worker" /></label>{filteredRows.length === 0 ? <div className="state-message">No relationships match this search.</div> : <div className="data-table-wrap directory-grid-table"><table className="data-table relationship-grid-table"><thead><tr><th>Farm owner</th><th>Farm name</th><th>Phone number</th><th>Email</th><th>Farm manager</th><th>Farm worker(s)</th><th>Status</th></tr></thead><tbody>{filteredRows.map((row) => <tr key={row.farm_id}><td>{row.owner?.name || "Not assigned"}</td><td>{row.farm_name || "-"}</td><td>{row.owner?.phone || "-"}</td><td>{row.owner?.email || "-"}</td><td>{row.managers?.map((member) => member.name).join(", ") || "None"}</td><td>{row.workers?.map((member) => member.name).join(", ") || "None"}</td><td><span className={`status-label ${row.status === "active" ? "won" : "lost"}`}>{row.status || "attention"}</span></td></tr>)}</tbody></table></div>}</section>;
}

export function DirectoryView({ view, directory, loading, error, onRefresh }) {
  const [search, setSearch] = useState("");
  useEffect(() => setSearch(""), [view]);
  const labels = { "farm-owners": "Farm Owners", "farm-managers": "Farm Managers", "farm-workers": "Farm Workers", relationships: "Relationships" };
  if (loading && !directory) return <section className="panel-card directory-panel"><div className="eyebrow">Customer directory</div><h2>Loading {labels[view]}</h2><p className="directory-help">Fetching all accessible farms and members.</p></section>;
  if (error && !directory) return <section className="panel-card directory-panel"><div className="eyebrow">Customer directory</div><h2>Directory unavailable</h2><p className="directory-help">{error}</p><button className="primary-button" type="button" onClick={onRefresh}>Try again</button></section>;
  if (!directory) return <section className="panel-card directory-panel"><h2>{labels[view]}</h2><div className="state-message">No directory data available.</div></section>;
  if (view === "relationships") return <RelationshipTable rows={directory.relationships || []} search={search} setSearch={setSearch} onRefresh={onRefresh} />;
  const rows = directory[view.replace("-", "_")] || [];
  const filteredRows = rows.filter((row) => [row.name, row.farm_name, row.phone, row.email, roleLabel(row.role), row.status, row.payment_status, row.number_of_pigs, row.mother_pigs, row.piglets, ...(row.piglet_age_groups || []).map((group) => `${group.count} ${group.age_months}`)].join(" ").toLowerCase().includes(search.toLowerCase()));
  return <section className="panel-card directory-panel"><div className="panel-heading"><div><div className="eyebrow">Customer directory</div><h2>{labels[view]}</h2></div><div className="directory-actions"><span>{filteredRows.length} members</span><button className="filter-button" type="button" onClick={onRefresh}>Refresh</button></div></div><label className="directory-search"><span>⌕</span><input aria-label={`Search ${labels[view]}`} value={search} onChange={(event) => setSearch(event.target.value)} placeholder={`Search ${labels[view].toLowerCase()}`} /></label><DirectoryTable rows={filteredRows} farmOwners={view === "farm-owners"} /></section>;
}
