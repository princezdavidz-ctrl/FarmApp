import "../splash.css";

export function SplashScreen() {
  return (
    <div className="splash-screen" role="status" aria-label="Loading CRM">
      <div className="splash-card">
        <span className="splash-mark" aria-hidden="true">CRM</span>
        <div className="splash-copy">
          <span className="eyebrow">CRM</span>
          <h1>Farm management</h1>
        </div>
        <span className="splash-progress" aria-hidden="true" />
      </div>
    </div>
  );
}
