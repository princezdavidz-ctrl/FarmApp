import { useEffect, useState } from "react";
import { api } from "../api";
import "./operations-finance.css";

const PAGE_SIZE = 50;

function displayValue(value) {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
  }
  return String(value);
}

export function MarketListings({ view, refreshKey, onRefresh }) {
  const isSold = view === "market-sold-pigs";
  const status = isSold ? "sold" : "available";
  const title = isSold ? "Sold Pigs" : "Posted Pigs";
  const [page, setPage] = useState(1);
  const [listings, setListings] = useState([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, total: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    api.get("/crm/market/listings", {
      params: { status, page, per_page: PAGE_SIZE },
    })
      .then((response) => {
        if (!active) return;
        setListings(response.data?.data || []);
        setMeta(response.data?.meta || { current_page: 1, last_page: 1, total: 0 });
      })
      .catch((requestError) => {
        if (active) setError(requestError.response?.data?.message || `Could not load ${title.toLowerCase()}.`);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [status, page, refreshKey, title]);

  return (
    <section className="farm-operations-page market-listings-page">
      <header className="panel-card operations-page-heading">
        <div>
          <div className="eyebrow">Pig marketplace</div>
          <h2>{title}</h2>
          <p>{isSold ? "Listings marked sold by farms." : "Pigs currently posted and available in the marketplace."}</p>
        </div>
        <button className="filter-button" type="button" onClick={onRefresh} disabled={loading}>
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </header>
      {loading ? (
        <div className="panel-card operations-state" role="status">Loading {title.toLowerCase()}…</div>
      ) : error ? (
        <div className="panel-card operations-state error" role="alert">{error}</div>
      ) : listings.length === 0 ? (
        <div className="panel-card operations-state">No {title.toLowerCase()} listings found.</div>
      ) : (
        <div className="panel-card operations-table-card">
          <div className="operations-table-scroll">
            <table className="operations-table market-listings-table">
              <thead>
                <tr>
                  <th>Farm</th>
                  <th>Listing</th>
                  <th>Breed</th>
                  <th>Quantity</th>
                  <th>Age</th>
                  <th>Weight</th>
                  <th>Price per pig</th>
                  <th>Location</th>
                  <th>Buyer requests</th>
                  <th>Posted</th>
                </tr>
              </thead>
              <tbody>
                {listings.map((listing) => (
                  <tr key={listing.id}>
                    <td>{listing.farm_name || "—"}</td>
                    <td>{listing.title || "—"}</td>
                    <td>{listing.breed || "—"}</td>
                    <td>{listing.quantity ?? "—"}</td>
                    <td>{listing.age_weeks == null ? "—" : `${listing.age_weeks} weeks`}</td>
                    <td>{listing.weight_kg == null ? "—" : `${listing.weight_kg} kg`}</td>
                    <td>{listing.currency || ""} {listing.price_per_pig ?? "—"}</td>
                    <td>{listing.location || listing.farm_location || "—"}</td>
                    <td>{listing.inquiries_count ?? 0}</td>
                    <td>{displayValue(listing.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="operations-pagination">
            <span>{meta.total} listings · Page {meta.current_page} of {meta.last_page}</span>
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
