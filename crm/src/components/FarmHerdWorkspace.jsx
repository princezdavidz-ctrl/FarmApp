import { useEffect, useState } from "react";
import { api } from "../api";
import "./operations-finance.css";

function ageLabel(birthDate) {
  if (!birthDate) return "—";
  const birth = new Date(`${birthDate}T00:00:00`);
  const today = new Date();
  let months = (today.getFullYear() - birth.getFullYear()) * 12 + today.getMonth() - birth.getMonth();
  if (today.getDate() < birth.getDate()) months -= 1;
  if (months < 0) return "—";
  const years = Math.floor(months / 12);
  const remainingMonths = months % 12;
  if (years && remainingMonths) return `${years}y ${remainingMonths}m`;
  if (years) return `${years} ${years === 1 ? "year" : "years"}`;
  return `${months} ${months === 1 ? "month" : "months"}`;
}

function dateLabel(value) {
  if (!value) return "Not recorded";
  const date = new Date(`${value}T00:00:00`);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString();
}

function HerdCard({ animal }) {
  const displayName = animal.name || animal.tag || "Unnamed pig";
  return (
    <article className="farm-herd-card">
      <div className="farm-herd-photo">
        {animal.image_url ? (
          <img src={animal.image_url} alt={displayName} loading="lazy" />
        ) : (
          <span aria-label="No herd image">No image</span>
        )}
      </div>
      <div className="farm-herd-card-content">
        <div className="farm-herd-card-heading">
          <div>
            <h3>{displayName}</h3>
            <p>{animal.tag || "No tag"} · {animal.type || "Pig"}</p>
          </div>
          <span className={`farm-herd-status status-${animal.status || "unknown"}`}>{animal.status || "Unknown"}</span>
        </div>
        <dl className="farm-herd-details">
          <div><dt>Gender</dt><dd>{animal.sex ? animal.sex[0].toUpperCase() + animal.sex.slice(1) : "—"}</dd></div>
          <div><dt>Age</dt><dd>{ageLabel(animal.birth_date)}</dd></div>
          <div><dt>Weight</dt><dd>{animal.weight_kg == null ? "—" : `${animal.weight_kg} kg`}</dd></div>
          {animal.sex === "female" && <div><dt>Pregnancy</dt><dd>{animal.is_pregnant ? "Pregnant" : "Not pregnant"}</dd></div>}
        </dl>
        <section className="farm-herd-health" aria-label="Health status">
          <h4>Health status</h4>
          <div><span>Dewormed</span><strong>{dateLabel(animal.last_dewormed_at)}</strong></div>
          <div><span>Vaccinated</span><strong>{dateLabel(animal.last_vaccinated_at)}</strong></div>
        </section>
      </div>
    </article>
  );
}

export function FarmHerdWorkspace({ canView = true }) {
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [farms, setFarms] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(timeout);
  }, [search]);

  useEffect(() => {
    if (debouncedSearch.length < 2) {
      setFarms([]);
      setError("");
      setLoading(false);
      return undefined;
    }

    let active = true;
    setLoading(true);
    setError("");
    api.get("/crm/operations/herd", { params: { search: debouncedSearch } })
      .then((response) => {
        if (active) setFarms(response.data?.data || []);
      })
      .catch((requestError) => {
        if (active) {
          setFarms([]);
          setError(requestError.response?.data?.message || "Could not search farm herd records.");
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [debouncedSearch]);

  if (!canView) return <section className="panel-card operations-state">Your CRM role does not have access to farm herd records.</section>;

  return (
    <section className="farm-operations-page farm-herd-workspace">
      <header className="panel-card operations-page-heading">
        <div>
          <div className="eyebrow">Farm operations</div>
          <h2>Farm herd</h2>
          <p>Search for a farm to view its herd profiles, images, and health details.</p>
        </div>
      </header>
      <label className="farm-herd-search">
        <span>Search by farm name</span>
        <input
          type="search"
          aria-label="Search farms by name"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Enter an existing farm name"
        />
      </label>
      {loading && <div className="panel-card operations-state" role="status">Searching farms…</div>}
      {error && <div className="panel-card operations-state error" role="alert">{error}</div>}
      {!loading && !error && debouncedSearch.length >= 2 && farms.length === 0 && (
        <div className="panel-card operations-state">No accessible farms match “{debouncedSearch}”.</div>
      )}
      {farms.map((farm) => (
        <section className="farm-herd-results" key={farm.id}>
          <header className="farm-herd-results-heading">
            <div><h2>{farm.name}</h2>{farm.location && <p>{farm.location}</p>}</div>
            <span>{farm.animals.length} {farm.animals.length === 1 ? "pig" : "pigs"}</span>
          </header>
          {farm.animals.length ? (
            <div className="farm-herd-grid">{farm.animals.map((animal) => <HerdCard key={animal.id} animal={animal} />)}</div>
          ) : (
            <div className="panel-card operations-state">No herd records have been added for this farm.</div>
          )}
        </section>
      ))}
      {debouncedSearch.length < 2 && <div className="panel-card operations-state">Enter at least two characters to search accessible farms.</div>}
    </section>
  );
}
