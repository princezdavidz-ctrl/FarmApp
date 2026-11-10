import { useState } from "react";
import "../auth-improvements.css";

export function Login({ auth, setAuth, onSubmit, onVerifyOtp, onResendOtp, onForgotPassword, notice }) {
  const [showPassword, setShowPassword] = useState(false);
  const [forgotMode, setForgotMode] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const [sendingReset, setSendingReset] = useState(false);
  const [resendingOtp, setResendingOtp] = useState(false);
  const submit = async (event) => {
    if (!forgotMode) return onSubmit(event);
    event.preventDefault();
    if (sendingReset || resetSent) return;
    setSendingReset(true);
    try {
      await onForgotPassword(auth.email);
      setResetSent(true);
    } catch {
      // The shared notice explains the delivery error; keep the form editable.
    } finally {
      setSendingReset(false);
    }
  };
  const resendOtp = async () => {
    if (resendingOtp) return;
    setResendingOtp(true);
    try {
      await onResendOtp();
    } finally {
      setResendingOtp(false);
    }
  };
  return (
    <div className="login-screen">
      <div className="login-art">
          <div className="art-label">CRM</div>
        <div className="art-copy">
          <h1>
            Better conversations.
            <br />
            <em>Stronger herds.</em>
          </h1>
          <p>Keep buyers, partners, and opportunities moving with the farm.</p>
        </div>
        <div className="art-footer">
          Customer relationships, thoughtfully managed.
        </div>
      </div>
      <form className="login-card" onSubmit={submit}>
        <div className="brand-block">
          <span className="crm-mark" aria-hidden="true">CRM</span>
          <div>
            <strong>CRM</strong>
            <span>Customer desk</span>
          </div>
        </div>
        {notice && (
          <div className={`notice ${notice.tone}`}>{notice.message}</div>
        )}
        {forgotMode ? (
          <>
            <div>
              <div className="eyebrow">Account recovery</div>
              <h2>Reset your password</h2>
              <p className="muted-copy">Enter your account email and we’ll send a secure reset link.</p>
            </div>
            <label>
              Account email
              <input
                type="email"
                required
                disabled={resetSent}
                value={auth.email}
                onChange={(event) => setAuth((current) => ({ ...current, email: event.target.value }))}
                placeholder="you@example.com"
              />
            </label>
            {resetSent ? (
              <div className="notice success" role="status">Email has been sent. If this address is registered, a reset link is on its way.</div>
            ) : (
              <button className="primary-button" type="submit" disabled={sendingReset}>
                {sendingReset ? "Sending…" : "Send reset link"}
              </button>
            )}
            <button className="ghost-button" type="button" onClick={() => { setForgotMode(false); setResetSent(false); }}>
              Back to sign in
            </button>
          </>
        ) : auth.challengeId ? (
          <>
            <div>
              <div className="eyebrow">Identity verification</div>
              <h2>Enter your sign-in code</h2>
              <p className="muted-copy">A six-digit code was sent to {auth.destination || "your registered email"}.</p>
            </div>
            <label>
              Verification code
              <input
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="[0-9]{6}"
                maxLength="6"
                required
                value={auth.otp || ""}
                onChange={(event) => setAuth((current) => ({ ...current, otp: event.target.value.replace(/\D/g, "").slice(0, 6) }))}
                placeholder="123456"
              />
            </label>
            <button className="primary-button" type="button" disabled={!/^\d{6}$/.test(auth.otp || "")} onClick={() => onVerifyOtp(auth.otp || "")}>
              Verify and sign in <span>→</span>
            </button>
            <button className="ghost-button" type="button" disabled={resendingOtp} onClick={resendOtp}>
              {resendingOtp ? "Sending…" : "Resend code"}
            </button>
            <button className="ghost-button" type="button" onClick={() => setAuth((current) => ({ ...current, challengeId: "", destination: "", otp: "" }))}>
              Back to sign in
            </button>
          </>
        ) : (
          <>
            <div>
              <div className="eyebrow">Welcome back</div>
              <h2>Sign in to your workspace</h2>
              <p className="muted-copy">Use your CRM account to continue.</p>
            </div>
            <label>
              Email address or phone
              <input
                type="text"
                required
                value={auth.email}
                onChange={(event) => setAuth((current) => ({ ...current, email: event.target.value }))}
                placeholder="you@example.com"
              />
            </label>
            <label>
              Password
              <span className="password-field">
                <input
                  type={showPassword ? "text" : "password"}
                  required
                  value={auth.password}
                  onChange={(event) => setAuth((current) => ({ ...current, password: event.target.value }))}
                  placeholder="Your password"
                />
                <button
                  className="password-toggle"
                  type="button"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  title={showPassword ? "Hide password" : "Show password"}
                  onClick={() => setShowPassword((current) => !current)}
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    {showPassword ? (
                      <><path d="M3 3l18 18" /><path d="M10.6 10.7a2 2 0 0 0 2.7 2.7" /><path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c5 0 8.5 4.5 9.5 7a16 16 0 0 1-3.1 4.4M6.2 6.2C4.3 7.5 3 9.5 2.5 12c1 2.5 4.5 7 9.5 7 1.1 0 2.1-.2 3-.6" /></>
                    ) : (
                      <><path d="M2.5 12S6 5 12 5s9.5 7 9.5 7-3.5 7-9.5 7-9.5-7-9.5-7Z" /><circle cx="12" cy="12" r="2.5" /></>
                    )}
                  </svg>
                </button>
              </span>
            </label>
            <label className="remember-me-option">
              <input
                type="checkbox"
                checked={Boolean(auth.rememberMe)}
                onChange={(event) => setAuth((current) => ({ ...current, rememberMe: event.target.checked }))}
              />
              Keep me signed in on this device
            </label>
            <button className="primary-button" type="submit">
              Continue <span>→</span>
            </button>
            <button className="forgot-password-link" type="button" onClick={() => setForgotMode(true)}>
              Forgot password?
            </button>
          </>
        )}
        <small className="login-help">
          Protected by your CRM account.
        </small>
      </form>
    </div>
  );
}
