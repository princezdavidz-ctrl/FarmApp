export function FarmOperationsSidebar({
  activeView,
  setActiveView,
  ordersExpanded,
  setOrdersExpanded,
}) {
  return (
    <nav className="side-nav farm-operations-side-nav" aria-label="Farm operations navigation">
      <button
        className={`nav-item standalone-nav-item ${activeView === "operations-farms" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("operations-farms")}
      >
        <span>▦</span> Farm
      </button>
      <button
        className="nav-group-toggle"
        type="button"
        onClick={() => setOrdersExpanded((expanded) => !expanded)}
        aria-expanded={ordersExpanded}
      >
        <span>▣</span>
        <strong>Orders</strong>
        <b>{ordersExpanded ? "−" : "+"}</b>
      </button>
      {ordersExpanded && (
        <div className="nav-subgroup">
          <button
            className={`nav-item ${activeView === "operations-feed-orders" ? "active" : ""}`}
            type="button"
            onClick={() => setActiveView("operations-feed-orders")}
          >
            <span>•</span> Feeds
          </button>
          <button
            className={`nav-item ${activeView === "operations-medicine-orders" ? "active" : ""}`}
            type="button"
            onClick={() => setActiveView("operations-medicine-orders")}
          >
            <span>•</span> Medicines
          </button>
        </div>
      )}
      <button
        className={`nav-item standalone-nav-item ${activeView === "operations-emergencies" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("operations-emergencies")}
      >
        <span>⚠</span> Emergencies
      </button>
      <button
        className={`nav-item standalone-nav-item ${activeView === "operations-herd" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("operations-herd")}
      >
        <span>•</span> Farm herd
      </button>
    </nav>
  );
}
