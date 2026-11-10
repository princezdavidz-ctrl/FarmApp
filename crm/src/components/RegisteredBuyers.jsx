import { useEffect, useState } from "react";
import { api } from "../api";

function registrationDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : date.toLocaleDateString();
}

export function RegisteredBuyers({ refreshKey = 0 }) {
  const [buyers, setBuyers] = useState([]);
  const [meta, setMeta] = useState({
    current_page: 1,
    last_page: 1,
    per_page: 25,
    total: 0,
  });
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const response = await api.get("/crm/buyers", {
          params: {
            ...(search.trim() ? { search: search.trim() } : {}),
            page,
            per_page: 25,
          },
        });
        if (!active) return;
        setBuyers(response.data?.data || []);
        setMeta(response.data?.meta || {
          current_page: 1,
          last_page: 1,
          per_page: 25,
          total: 0,
        });
      } catch (requestError) {
        if (!active) return;
        setError(
          requestError.response?.data?.message ||
            "Unable to load registered buyer accounts.",
        );
      } finally {
        if (active) setLoading(false);
      }
    }, 250);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [search, page, refreshKey, reload]);

  const changeSearch = (value) => {
    setSearch(value);
    setPage(1);
  };

  return (
    <section className="panel-card directory-panel registered-buyers-panel">
      <div className="panel-heading">
        <div>
          <div className="eyebrow">Customer accounts</div>
          <h2>Registered buyers</h2>
        </div>
        <div className="directory-actions">
          <span>{meta.total} accounts</span>
          <button
            className="filter-button"
            type="button"
            onClick={() => setReload((current) => current + 1)}
            disabled={loading}
          >
            Refresh
          </button>
        </div>
      </div>
      <p className="directory-help">
        Buyer accounts created through registration, with contact details and
        marketplace inquiry counts.
      </p>
      <label className="directory-search">
        <span aria-hidden="true">⌕</span>
        <input
          aria-label="Search registered buyers"
          value={search}
          onChange={(event) => changeSearch(event.target.value)}
          placeholder="Search name, email, or phone"
        />
      </label>

      {error ? (
        <div className="directory-error" role="alert">
          <p>{error}</p>
          <button
            className="primary-button"
            type="button"
            onClick={() => setReload((current) => current + 1)}
          >
            Try again
          </button>
        </div>
      ) : loading ? (
        <div className="state-message" role="status">Loading registered buyers…</div>
      ) : buyers.length === 0 ? (
        <div className="state-message">
          {search.trim()
            ? "No registered buyers match this search."
            : "No registered buyer accounts yet."}
        </div>
      ) : (
        <>
          <div className="data-table-wrap">
            <table className="data-table registered-buyers-table">
              <thead>
                <tr>
                  <th>Buyer</th>
                  <th>Email</th>
                  <th>Phone</th>
                  <th>Registered</th>
                  <th>Inquiries</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {buyers.map((buyer) => (
                  <tr key={buyer.id}>
                    <td><strong>{buyer.name || "Unnamed buyer"}</strong></td>
                    <td>{buyer.email || "—"}</td>
                    <td>{buyer.phone || "—"}</td>
                    <td>{registrationDate(buyer.registered_at)}</td>
                    <td>{buyer.inquiries_count ?? 0}</td>
                    <td>
                      <span
                        className={`status-label ${buyer.status === "active" ? "won" : "lost"}`}
                      >
                        {buyer.status || "active"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="registered-buyers-pagination">
            <span>
              Page {meta.current_page} of {meta.last_page}
            </span>
            <div>
              <button
                className="filter-button"
                type="button"
                disabled={loading || page <= 1}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
              >
                Previous
              </button>
              <button
                className="filter-button"
                type="button"
                disabled={loading || page >= meta.last_page}
                onClick={() => setPage((current) => current + 1)}
              >
                Next
              </button>
            </div>
          </div>
        </>
      )}
    </section>
  );
}
