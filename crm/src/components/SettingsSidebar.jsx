const settingsLinks = [
  { id: "settings-profile", label: "My profile", icon: "♙" },
  { id: "settings-security", label: "Password and security", icon: "◇" },
  { id: "settings-farm", label: "Farm workspace", icon: "◈" },
  { id: "settings-members", label: "Members and permissions", icon: "▣" },
  { id: "settings-notifications", label: "Notifications", icon: "✦" },
];

export function SettingsSidebar({ activeView, setActiveView, isAdmin }) {
  const links = isAdmin
    ? [...settingsLinks, { id: "settings-name-approvals", label: "Farm name approvals", icon: "✓" }]
    : settingsLinks;
  return (
    <nav className="side-nav settings-side-nav" aria-label="Settings navigation">
      <div className="side-caption">Workspace settings</div>
      {links.map((link) => (
        <button key={link.id} className={`nav-item ${activeView === link.id ? "active" : ""}`} type="button" onClick={() => setActiveView(link.id)}>
          <span>{link.icon}</span> {link.label}
        </button>
      ))}
    </nav>
  );
}
