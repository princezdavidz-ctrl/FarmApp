export function StaffSidebar({ activeView, setActiveView, groups, setGroups, categories = [], isAdmin }) {
  return (
    <nav className="side-nav staff-side-nav" aria-label="Staff navigation">
      <button
        className="nav-group-toggle"
        type="button"
        onClick={() => setGroups((current) => ({ ...current, directory: !current.directory }))}
        aria-expanded={groups.directory}
      >
        <span>♙</span>
        <strong>My staff</strong>
        <b>{groups.directory ? "−" : "+"}</b>
      </button>
      {groups.directory && (
        <div className="nav-subgroup">
          <button className={`nav-item ${activeView === "staff-list" ? "active" : ""}`} type="button" onClick={() => setActiveView("staff-list")}><span>•</span> Staff list</button>
          {categories.map((category) => <button key={category.id} className={`nav-item ${activeView === `staff-category-${category.id}` ? "active" : ""}`} type="button" onClick={() => setActiveView(`staff-category-${category.id}`)}><span style={{ color: category.color }}>{category.icon || "•"}</span> {category.name}</button>)}
        </div>
      )}
      {isAdmin && <button className={`nav-item standalone-nav-item ${activeView === "staff-categories" ? "active" : ""}`} type="button" onClick={() => setActiveView("staff-categories")}><span>＋</span> Manage categories</button>}
      <button className="nav-group-toggle" type="button" onClick={() => setGroups((current) => ({ ...current, policies: !current.policies }))} aria-expanded={groups.policies}><span>▤</span><strong>Staff policies</strong><b>{groups.policies ? "−" : "+"}</b></button>
      {groups.policies && <div className="nav-subgroup">{isAdmin && <button className={`nav-item ${activeView === "policy-new" ? "active" : ""}`} type="button" onClick={() => setActiveView("policy-new")}><span>＋</span> New policy</button>}<button className={`nav-item ${activeView === "policy-existing" ? "active" : ""}`} type="button" onClick={() => setActiveView("policy-existing")}><span>•</span> Existing policies</button></div>}
      {isAdmin && <button
        className={`nav-item standalone-nav-item ${activeView === "staff-logs" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("staff-logs")}
      >
        <span>◷</span> Staff logs
      </button>}
    </nav>
  );
}
