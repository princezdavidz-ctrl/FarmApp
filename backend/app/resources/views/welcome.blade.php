<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{{ config('app.name', 'Backend API') }}</title>
        <style>
            body {
                align-items: center;
                background: #f4f7f5;
                color: #20332a;
                display: flex;
                font-family: system-ui, sans-serif;
                justify-content: center;
                margin: 0;
                min-height: 100vh;
            }
            main {
                background: #fff;
                border: 1px solid #e0e8e3;
                border-radius: 12px;
                max-width: 32rem;
                padding: 2rem;
                text-align: center;
                width: calc(100% - 4rem);
            }
            h1 { margin: 0 0 .75rem; }
            p { color: #53665b; margin: 0; }
        </style>
    </head>
    <body>
        <main>
            <h1>{{ config('app.name', 'Backend API') }}</h1>
            <p>The backend service is ready.</p>
        </main>
    </body>
</html>
