const financeLinks = [
  { id: "finance-overview", label: "Finance overview", icon: "◈" },
  { id: "finance-ledger", label: "Farm income & expenses", icon: "↔" },
  { id: "finance-subscriptions", label: "Farm subscriptions", icon: "▣" },
  { id: "finance-payments", label: "Payment activity", icon: "₿" },
  { id: "finance-plans", label: "Subscription plans", icon: "◇" },
  { id: "finance-reporting", label: "Revenue reporting", icon: "⌁" },
];

export function FinanceSidebar({ activeView, setActiveView }) {
  return (
    <nav className="side-nav finance-side-nav" aria-label="Finance navigation">
      <div className="side-caption">Finance workspace</div>
      {financeLinks.map((link) => (
        <button
          key={link.id}
          className={`nav-item ${activeView === link.id ? "active" : ""}`}
          type="button"
          onClick={() => setActiveView(link.id)}
        >
          <span>{link.icon}</span> {link.label}
        </button>
      ))}
    </nav>
  );
}
