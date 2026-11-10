import { adminSections } from "../navigation";

export function AdminNavbar({ activeSection, selectSection }) {
  return (
    <nav className="admin-navbar" aria-label="Admin navigation">
      <div className="admin-nav-label">Admin</div>
      <div className="admin-nav-links">
        {adminSections.map((section) => (
          <button
            key={section.id}
            className={activeSection === section.id ? "active" : ""}
            onClick={() => selectSection(section.id)}
          >
            <span>{section.icon}</span>
            {section.label}
          </button>
        ))}
      </div>
    </nav>
  );
}
