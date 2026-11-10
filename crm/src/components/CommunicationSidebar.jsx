const communicationLinks = [
  { id: "communication-inbox", label: "Inbox", icon: "▣" },
  { id: "communication-broadcast", label: "Broadcast", icon: "✦" },
  { id: "communication-activity", label: "Customer activity", icon: "◷" },
  { id: "communication-templates", label: "Templates", icon: "◇" },
];

export function CommunicationSidebar({ activeView, setActiveView }) {
  return (
    <nav className="side-nav communication-side-nav" aria-label="Communication navigation">
      <div className="side-caption">Communication workspace</div>
      {communicationLinks.map((link) => (
        <button key={link.id} className={`nav-item ${activeView === link.id ? "active" : ""}`} type="button" onClick={() => setActiveView(link.id)}>
          <span>{link.icon}</span> {link.label}
        </button>
      ))}
    </nav>
  );
}
