param(
    [string]$ExpectedProjectId = "adfoot-production",
    [string]$ExpectedStorageBucket = "adfoot-production.firebasestorage.app",
    [string]$ExpectedAuthDomain = "adfoot-production.firebaseapp.com",
    [string]$ExpectedFunctionsRegion = "europe-west1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]
$checkedFiles = New-Object System.Collections.Generic.List[string]

function Read-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("Missing required file: $RelativePath")
        return ""
    }

    $checkedFiles.Add($RelativePath)
    return Get-Content -LiteralPath $path -Raw
}

function Assert-ContainsRegex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Raw,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Raw -notmatch $Pattern) {
        $errors.Add($Message)
    }
}

$firebaseOptionsRaw = Read-RequiredFile "lib/firebase_options.dart"
$appEnvironmentRaw = Read-RequiredFile "lib/config/app_environment.dart"
$firebaseBootstrapRaw = Read-RequiredFile "lib/config/firebase_bootstrap.dart"
$managedAccountServiceRaw = Read-RequiredFile "lib/services/managed_account_service.dart"
$rolePolicyRaw = Read-RequiredFile "lib/utils/account_role_policy.dart"
$userControllerRaw = Read-RequiredFile "lib/controller/user_controller.dart"
$packageRaw = Read-RequiredFile "package.json"

if ($errors.Count -eq 0) {
    Assert-ContainsRegex `
        -Raw $firebaseOptionsRaw `
        -Pattern ("projectId:\s*'" + [regex]::Escape($ExpectedProjectId) + "'") `
        -Message "firebase_options.dart does not default to projectId '$ExpectedProjectId'."

    Assert-ContainsRegex `
        -Raw $firebaseOptionsRaw `
        -Pattern ("storageBucket:\s*'" + [regex]::Escape($ExpectedStorageBucket) + "'") `
        -Message "firebase_options.dart does not default to storage bucket '$ExpectedStorageBucket'."

    Assert-ContainsRegex `
        -Raw $firebaseOptionsRaw `
        -Pattern ("authDomain:\s*'" + [regex]::Escape($ExpectedAuthDomain) + "'") `
        -Message "firebase_options.dart does not default to auth domain '$ExpectedAuthDomain'."

    Assert-ContainsRegex `
        -Raw $appEnvironmentRaw `
        -Pattern "String\.fromEnvironment\('APP_ENV',\s*defaultValue:\s*'production'\)" `
        -Message "APP_ENV default is no longer production."

    Assert-ContainsRegex `
        -Raw $appEnvironmentRaw `
        -Pattern ("String\.fromEnvironment\(\s*'FIREBASE_FUNCTIONS_REGION',\s*defaultValue:\s*'" + [regex]::Escape($ExpectedFunctionsRegion) + "'") `
        -Message "Functions region default is not '$ExpectedFunctionsRegion'."

    Assert-ContainsRegex `
        -Raw $firebaseBootstrapRaw `
        -Pattern "Firebase\.initializeApp\(\s*options:\s*AppEnvironmentConfig\.firebaseOptions" `
        -Message "Firebase bootstrap does not initialize with AppEnvironmentConfig.firebaseOptions."

    Assert-ContainsRegex `
        -Raw $managedAccountServiceRaw `
        -Pattern "FirebaseFunctions\.instanceFor\(\s*region:\s*AppEnvironmentConfig\.functionsRegion" `
        -Message "Managed account service does not use the configured Functions region."

    foreach ($callable in @(
        "provisionManagedAccount",
        "deleteManagedAccount",
        "changeManagedAccountRole",
        "resendManagedAccountInvite",
        "disableManagedAccountAuth",
        "enableManagedAccountAuth",
        "updateManagedAccountProfile"
    )) {
        Assert-ContainsRegex `
            -Raw $managedAccountServiceRaw `
            -Pattern ([regex]::Escape("'$callable'")) `
            -Message "Managed account service is missing callable '$callable'."
    }

    Assert-ContainsRegex `
        -Raw $rolePolicyRaw `
        -Pattern "const List<String> publicSelfSignupRoles = \[\];" `
        -Message "Public self-signup roles must stay disabled in admin role policy."

    foreach ($role in @("joueur", "fan", "club", "recruteur", "agent", "admin")) {
        Assert-ContainsRegex `
            -Raw $rolePolicyRaw `
            -Pattern ([regex]::Escape("'$role'")) `
            -Message "Role policy is missing '$role'."
    }

    Assert-ContainsRegex `
        -Raw $userControllerRaw `
        -Pattern "grantedClaims\.isEmpty" `
        -Message "Admin access must still require at least one admin custom claim."

    foreach ($scriptName in @("production:check", "contract:mobile", "build:web:production", "release:check")) {
        Assert-ContainsRegex `
            -Raw $packageRaw `
            -Pattern ([regex]::Escape('"' + $scriptName + '"')) `
            -Message "package.json is missing npm script '$scriptName'."
    }
}

Write-Host "Checked files:"
foreach ($file in $checkedFiles) {
    Write-Host "- $file"
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors:"
    foreach ($errorMessage in $errors) {
        Write-Host "- $errorMessage"
    }
    exit 1
}

Write-Host ""
Write-Host "Admin production configuration is valid."
exit 0
