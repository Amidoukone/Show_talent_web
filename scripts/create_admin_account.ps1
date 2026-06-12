param(
    [ValidateSet("staging", "production")]
    [string]$Environment = "staging",
    [string]$Email,
    [string]$Name = "Admin Adfoot",
    [ValidateSet("admin", "platformAdmin", "superAdmin")]
    [string]$Claim = "superAdmin",
    [string]$ServiceAccount,
    [string]$Password,
    [string]$Phone,
    [switch]$UpdatePassword,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectId {
    param([Parameter(Mandatory = $true)][string]$TargetEnvironment)

    switch ($TargetEnvironment) {
        "staging" { return "adfoot-staging" }
        "production" { return "adfoot-production" }
        default { throw "Unsupported environment: $TargetEnvironment" }
    }
}

function Resolve-ServiceAccountPath {
    param(
        [string]$ExplicitPath,
        [Parameter(Mandatory = $true)][string]$ProjectId
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    foreach ($envPath in @(
        $env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH,
        $env:GOOGLE_APPLICATION_CREDENTIALS
    )) {
        if (-not [string]::IsNullOrWhiteSpace($envPath)) {
            return (Resolve-Path -LiteralPath $envPath).Path
        }
    }

    $credentialsDir = Join-Path $repoRoot ".credentials"
    $expectedFile = Join-Path $credentialsDir "$ProjectId-admin-sdk.json"
    if (Test-Path -LiteralPath $expectedFile) {
        return (Resolve-Path -LiteralPath $expectedFile).Path
    }

    if (Test-Path -LiteralPath $credentialsDir) {
        $projectCandidateFiles = @(
            Get-ChildItem -LiteralPath $credentialsDir -Filter "*.json" |
                Where-Object { $_.Name -like "*$ProjectId*.json" }
        )

        if ($projectCandidateFiles.Count -eq 1) {
            return $projectCandidateFiles[0].FullName
        }

        if ($projectCandidateFiles.Count -gt 1) {
            $names = ($projectCandidateFiles | ForEach-Object { $_.FullName }) -join "`n- "
            throw "Multiple service account candidates found for $ProjectId. Pass -ServiceAccount explicitly.`n- $names"
        }

        $candidateFiles = @(
            Get-ChildItem -LiteralPath $credentialsDir -Filter "*.json" |
                Where-Object { $_.Name -like "*admin-sdk*.json" }
        )

        if ($candidateFiles.Count -eq 1) {
            return $candidateFiles[0].FullName
        }

        if ($candidateFiles.Count -gt 1) {
            $names = ($candidateFiles | ForEach-Object { $_.FullName }) -join "`n- "
            throw "Multiple service account candidates found. Pass -ServiceAccount explicitly.`n- $names"
        }
    }

    throw "No service account found for $ProjectId. Pass -ServiceAccount or set FIREBASE_SERVICE_ACCOUNT_KEY_PATH."
}

function Require-Email {
    param([string]$Value)

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value.Trim().ToLowerInvariant()
    }

    $entered = Read-Host "Admin email"
    if ([string]::IsNullOrWhiteSpace($entered)) {
        throw "Admin email is required."
    }

    return $entered.Trim().ToLowerInvariant()
}

$projectId = Resolve-ProjectId -TargetEnvironment $Environment
$resolvedServiceAccount = Resolve-ServiceAccountPath `
    -ExplicitPath $ServiceAccount `
    -ProjectId $projectId
$resolvedEmail = Require-Email -Value $Email

$nodeArgs = @(
    "scripts/create_admin_account.mjs",
    "--serviceAccount", $resolvedServiceAccount,
    "--projectId", $projectId,
    "--email", $resolvedEmail,
    "--name", $Name,
    "--claim", $Claim
)

if (-not [string]::IsNullOrWhiteSpace($Password)) {
    $nodeArgs += @("--password", $Password)
}

if (-not [string]::IsNullOrWhiteSpace($Phone)) {
    $nodeArgs += @("--phone", $Phone)
}

if ($UpdatePassword) {
    $nodeArgs += "--update-password"
}

Write-Host ""
Write-Host "Admin bootstrap target"
Write-Host "- Environment : $Environment"
Write-Host "- Project ID  : $projectId"
Write-Host "- Email       : $resolvedEmail"
Write-Host "- Name        : $Name"
Write-Host "- Claim       : $Claim"
Write-Host "- Service acct: $resolvedServiceAccount"
Write-Host "- Email verification required: false"
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run only. No Firebase Auth or Firestore change was made."
    exit 0
}

& node @nodeArgs
exit $LASTEXITCODE
