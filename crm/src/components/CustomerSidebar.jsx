import { customerNavLinks, customerOrderStatuses } from "../navigation";

export function CustomerSidebar({
  activeView,
  setActiveView,
  customerGroups,
  setCustomerGroups,
  isGlobalAdmin,
}) {
  return (
    <nav className="side-nav customer-side-nav" aria-label="Customer navigation">
      <button
        className="nav-group-toggle"
        type="button"
        onClick={() =>
          setCustomerGroups((current) => ({
            ...current,
            myCustomers: !current.myCustomers,
          }))
        }
        aria-expanded={customerGroups.myCustomers}
      >
        <span>◈</span>
        <strong>My Customers</strong>
        <b>{customerGroups.myCustomers ? "−" : "+"}</b>
      </button>

      {customerGroups.myCustomers && (
        <div className="nav-subgroup">
          {customerNavLinks.map((link) => (
            <button
              key={link.id}
              className={`nav-item ${activeView === link.id ? "active" : ""}`}
              onClick={() => setActiveView(link.id)}
            >
              <span>•</span> {link.label}
            </button>
          ))}
        </div>
      )}

      {isGlobalAdmin && <button
        className={`nav-item standalone-nav-item ${activeView === "farm-owner-prospects" ? "active" : ""}`}
        type="button"
        onClick={() => setActiveView("farm-owner-prospects")}
      >
        <span>•</span> Farm-owner prospects
      </button>}

      <button
        className={`nav-item standalone-nav-item ${activeView === "segments" ? "active" : ""}`}
        onClick={() => setActiveView("segments")}
      >
        <span>◇</span> Segment
      </button>

      <button
        className="nav-group-toggle"
        type="button"
        onClick={() =>
          setCustomerGroups((current) => ({
            ...current,
            orders: !current.orders,
          }))
        }
        aria-expanded={customerGroups.orders}
      >
        <span>▣</span>
        <strong>Orders</strong>
        <b>{customerGroups.orders ? "−" : "+"}</b>
      </button>

      {customerGroups.orders && (
        <div className="nav-subgroup">
          {customerOrderStatuses.map((status) => (
            <button
              key={status}
              className={`nav-item ${activeView === `orders-${status}` ? "active" : ""}`}
              onClick={() => setActiveView(`orders-${status}`)}
            >
              <span>•</span> {status[0].toUpperCase() + status.slice(1)} Orders
            </button>
          ))}
        </div>
      )}
    </nav>
  );
}
