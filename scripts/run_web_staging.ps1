$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\web-staging.json"
$examplePath = Join-Path $repoRoot "config\web-staging.example.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Missing $configPath. Copy config\web-staging.example.json to config\web-staging.json and fill in the real Firebase Web SDK values (run: firebase apps:sdkconfig web <appId> --project adfoot-staging)."
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$required = @("projectId", "apiKey", "appId", "authDomain", "storageBucket", "messagingSenderId")
foreach ($field in $required) {
    if ([string]::IsNullOrWhiteSpace($config.$field)) {
        Write-Error "config\web-staging.json is missing or empty field '$field'. See $examplePath for the expected shape."
        exit 1
    }
}

# sentryDsn est facultatif -- voir build_web_staging.ps1. On le laisse
# generalement vide en local : pas besoin d'envoyer les erreurs de dev a
# Sentry, la console du navigateur suffit pendant le hot-reload.
$sentryDsn = $config.sentryDsn
$sentryEnabled = if ([string]::IsNullOrWhiteSpace($sentryDsn)) { "false" } else { "true" }

# flutter run (debug, hot-reload) contre le projet Firebase adfoot-staging.
# Contrairement a build_web_staging.ps1 (build release pour Hosting), ce
# script sert a reproduire un bug localement dans Chrome, DevTools ouverts,
# pour voir l'erreur reseau/console exacte (ex: approbation video).
flutter run -d chrome `
    --dart-define=APP_ENV=staging `
    --dart-define=FIREBASE_PROJECT_ID=$($config.projectId) `
    --dart-define=FIREBASE_FUNCTIONS_REGION=europe-west1 `
    --dart-define=FIREBASE_WEB_API_KEY=$($config.apiKey) `
    --dart-define=FIREBASE_WEB_APP_ID=$($config.appId) `
    --dart-define=FIREBASE_WEB_AUTH_DOMAIN=$($config.authDomain) `
    --dart-define=FIREBASE_STORAGE_BUCKET=$($config.storageBucket) `
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=$($config.messagingSenderId) `
    --dart-define=SENTRY_ENABLED=$sentryEnabled `
    --dart-define=SENTRY_DSN=$sentryDsn

exit $LASTEXITCODE
