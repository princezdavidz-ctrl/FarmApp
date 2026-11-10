# Farm App password reset page

This static page is intended to be hosted at
`https://password.example.invalid/`.
The API emails links to this page with `token` and `email` query parameters.
When submitted, the page posts the reset data to
`http://localhost:8000/api/v1/auth/reset-password`.

Configure the backend environment:

```dotenv
PASSWORD_RESET_FRONTEND_URL=https://password.example.invalid/
CORS_ALLOWED_ORIGINS=https://crm.example.invalid,https://password.example.invalid
```

Deploy the static files to the document root configured for your password
reset page. The root `index.html` is the default document. Set the API base URL
in the page before deployment, enable HTTPS, and add that page's exact origin
to the API CORS allowlist before testing password-reset emails.
