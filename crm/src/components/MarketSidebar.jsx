export function MarketSidebar({ activeView, setActiveView }) {
  return (
    <nav className="side-nav market-side-nav" aria-label="Market navigation">
      <button
        className={`nav-item standalone-nav-item ${activeView === "market-posted-pigs" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("market-posted-pigs")}
      >
        <span>•</span> Posted Pigs
      </button>
      <button
        className={`nav-item standalone-nav-item ${activeView === "market-sold-pigs" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("market-sold-pigs")}
      >
        <span>•</span> Sold Pigs
      </button>
    </nav>
  );
}
