<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <title>Reset your FarmApp password</title>
</head>
<body style="margin:0;padding:0;background:#f4f7f3;font-family:Arial,Helvetica,sans-serif;color:#183426">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f7f3;padding:28px 12px">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #dce7dc;border-radius:18px;overflow:hidden">
                    <tr>
                        <td style="padding:30px 28px 12px">
                            <p style="margin:0;color:#176b4d;font-size:12px;font-weight:bold;letter-spacing:2px;text-transform:uppercase">FarmApp</p>
                            <h1 style="margin:14px 0 10px;font-size:25px;line-height:1.25;color:#183426">Reset your password</h1>
                            <p style="margin:0;color:#65766a;font-size:15px;line-height:1.65">Hello {{ $name }}, we received a request to set a new password for your FarmApp account.</p>
                        </td>
                    </tr>
                    <tr>
                        <td align="center" style="padding:22px 28px">
                            <a href="{{ $resetUrl }}" style="display:inline-block;padding:14px 24px;border-radius:11px;background:#176b4d;color:#ffffff;font-size:15px;font-weight:bold;text-decoration:none">Set a new password</a>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:0 28px 28px">
                            <p style="margin:0 0 12px;color:#65766a;font-size:13px;line-height:1.6">This secure link expires in {{ $expiresIn }} minutes and can only be used once.</p>
                            <p style="margin:0 0 8px;color:#65766a;font-size:13px;line-height:1.6">If the button does not work, copy and paste this address into your browser:</p>
                            <p style="margin:0;overflow-wrap:anywhere;color:#176b4d;font-size:12px;line-height:1.6"><a href="{{ $resetUrl }}" style="color:#176b4d">{{ $resetUrl }}</a></p>
                            <hr style="height:1px;margin:22px 0;border:0;background:#e5ece4">
                            <p style="margin:0;color:#8a968d;font-size:12px;line-height:1.6">If you did not request a password reset, you can ignore this email. Your password will not change.</p>
                        </td>
                    </tr>
                </table>
                <p style="margin:16px 0 0;color:#8a968d;font-size:11px">© {{ date('Y') }} FarmApp</p>
            </td>
        </tr>
    </table>
</body>
</html>
