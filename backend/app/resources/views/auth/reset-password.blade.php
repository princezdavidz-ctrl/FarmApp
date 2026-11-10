<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#176b4d">
    <title>{{ $success ? 'Password updated' : 'Reset password' }} · Farm App</title>
    <style>
        :root{color-scheme:light;--green:#176b4d;--green-dark:#124c39;--ink:#183426;--muted:#65766a;--line:#dce7dc;--surface:#f5f8f4;--danger:#a33e3e;--success:#267348;font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--ink);background:var(--surface)}
        *{box-sizing:border-box}
        body{display:grid;min-height:100vh;min-height:100dvh;place-items:center;margin:0;padding:max(18px,env(safe-area-inset-top)) 16px max(18px,env(safe-area-inset-bottom));background:radial-gradient(ellipse at top,#e7f1e7 0,transparent 52%),var(--surface)}
        .card{width:min(100%,460px);padding:clamp(22px,6vw,38px);border:1px solid var(--line);border-radius:24px;background:#fff;box-shadow:0 20px 60px #18342612}
        .brand{display:flex;align-items:center;gap:12px;margin-bottom:28px}
        .brand img{width:48px;height:48px;object-fit:contain;border-radius:12px}
        .brand-name{font-size:14px;font-weight:800;letter-spacing:.01em}
        .brand-caption{margin-top:3px;color:var(--muted);font-size:12px}
        .eyebrow{color:var(--green);font-size:11px;font-weight:800;letter-spacing:.14em;text-transform:uppercase}
        h1{margin:9px 0 8px;font-size:clamp(25px,7vw,32px);line-height:1.15;letter-spacing:-.035em}
        p{color:var(--muted);line-height:1.6}
        .intro{margin:0 0 22px;font-size:14px}
        .field{margin-top:17px}
        label{display:block;margin-bottom:7px;font-size:13px;font-weight:750}
        input{width:100%;min-height:48px;padding:12px 14px;border:1px solid #cbd8cd;border-radius:12px;background:#fff;color:var(--ink);font:inherit;font-size:16px;outline:none}
        input:focus{border-color:var(--green);box-shadow:0 0 0 3px #176b4d1a}
        input[aria-invalid="true"]{border-color:var(--danger)}
        .password-wrap{position:relative}
        .password-wrap input{padding-right:78px}
        .toggle{position:absolute;top:50%;right:7px;min-height:38px;padding:0 9px;transform:translateY(-50%);border:0;border-radius:8px;background:transparent;color:var(--green);font:inherit;font-size:12px;font-weight:750;cursor:pointer}
        .hint{margin:7px 0 0;color:var(--muted);font-size:12px}
        .error{margin:14px 0;padding:12px 14px;border:1px solid #f0d4d4;border-radius:12px;background:#fff6f6;color:var(--danger);font-size:13px;line-height:1.5}
        .success{margin:20px 0;padding:15px;border:1px solid #cce6d1;border-radius:14px;background:#e8f4e9;color:var(--success);line-height:1.55}
        .submit{width:100%;min-height:50px;margin-top:23px;padding:13px 16px;border:0;border-radius:12px;background:var(--green);color:#fff;font:inherit;font-weight:800;cursor:pointer;transition:background .15s,transform .15s}
        .submit:hover{background:var(--green-dark)}
        .submit:active{transform:translateY(1px)}
        .footer{margin:20px 0 0;text-align:center;font-size:13px}
        a{color:var(--green);font-weight:750;text-decoration:none}
        a:hover{text-decoration:underline}
        .help{margin:24px 0 0;text-align:center;color:var(--muted);font-size:11px}
        @media(max-width:380px){.card{border-radius:18px}.brand{margin-bottom:23px}}
        @media(prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;transition:none!important}}
    </style>
</head>
<body>
<main class="card">
    <header class="brand">
        <div><div class="brand-name">Farm App</div><div class="brand-caption">Farm management, made simpler</div></div>
    </header>

    <div class="eyebrow">Account security</div>
    <h1>{{ $success ? 'Password updated' : 'Set a new password' }}</h1>
    @if ($success)
        <p class="success" role="status">{{ $status }}</p>
        <p>Your new password is ready to use in the Farm App app.</p>
        <p class="footer"><a href="/">Return to Farm App</a></p>
    @else
        <p class="intro">Create a new password for your account. For your security, this reset link expires after 60 minutes.</p>
        @if ($status)<div class="error" role="alert">{{ $status }}</div>@endif
        @if ($errors->any())<div class="error" role="alert">{{ $errors->first() }}</div>@endif
        <form method="POST" action="{{ route('password.update') }}">
            @csrf
            <input type="hidden" name="token" value="{{ $token }}">
            <div class="field">
                <label for="email">Account email</label>
                <input id="email" type="email" name="email" value="{{ old('email', $email) }}" required autocomplete="email" inputmode="email" autocapitalize="none" spellcheck="false" aria-invalid="{{ $errors->has('email') ? 'true' : 'false' }}">
            </div>
            <div class="field">
                <label for="password">New password</label>
                <div class="password-wrap">
                    <input id="password" type="password" name="password" required minlength="8" autocomplete="new-password" aria-describedby="password-hint" aria-invalid="{{ $errors->has('password') ? 'true' : 'false' }}">
                    <button class="toggle" type="button" data-toggle="password" aria-controls="password" aria-pressed="false">Show</button>
                </div>
                <p class="hint" id="password-hint">Use at least 8 characters.</p>
            </div>
            <div class="field">
                <label for="password_confirmation">Confirm new password</label>
                <div class="password-wrap">
                    <input id="password_confirmation" type="password" name="password_confirmation" required minlength="8" autocomplete="new-password" aria-invalid="{{ $errors->has('password') ? 'true' : 'false' }}">
                    <button class="toggle" type="button" data-toggle="password_confirmation" aria-controls="password_confirmation" aria-pressed="false">Show</button>
                </div>
            </div>
            <button class="submit" type="submit">Save new password</button>
        </form>
        <p class="footer"><a href="/">Back to Farm App</a></p>
    @endif
    <p class="help">If you did not request this change, you can safely ignore this page.</p>
</main>
<script>
    document.querySelectorAll('[data-toggle]').forEach((button) => {
        button.addEventListener('click', () => {
            const input = document.getElementById(button.dataset.toggle);
            const visible = input.type === 'password';
            input.type = visible ? 'text' : 'password';
            button.textContent = visible ? 'Hide' : 'Show';
            button.setAttribute('aria-pressed', String(visible));
        });
    });
</script>
</body>
</html>
