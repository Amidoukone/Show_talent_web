param(
    [string]$MobileRepoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$adminRepoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-MobileRepoPath {
    param([string]$ExplicitPath)

    $candidates = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates.Add($ExplicitPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ADFOOT_MOBILE_REPO)) {
        $candidates.Add($env:ADFOOT_MOBILE_REPO)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $candidates.Add(
            (Join-Path $env:USERPROFILE "Desktop\ODC_PROJECT\MOBILE\Show-Talent")
        )
    }

    foreach ($candidate in $candidates) {
        try {
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
            $script = Join-Path $resolved "scripts\check-admin-mobile-contract.ps1"
            if (Test-Path -LiteralPath $script) {
                return $resolved
            }
        } catch {
            # Try the next candidate.
        }
    }

    throw "Mobile repo not found. Set ADFOOT_MOBILE_REPO or pass -MobileRepoPath."
}

$resolvedMobileRepoPath = Resolve-MobileRepoPath $MobileRepoPath
$contractScript = Join-Path $resolvedMobileRepoPath "scripts\check-admin-mobile-contract.ps1"

Write-Host "Admin repo : $adminRepoRoot"
Write-Host "Mobile repo: $resolvedMobileRepoPath"
Write-Host ""

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $contractScript `
    -Strict `
    -AdminRepoPath $adminRepoRoot

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}

# Le controle du depot mobile verifie une direction : que chaque callable de sa
# liste requise soit bien atteint par ce portail. Rien ne verifiait l'autre, et
# c'est elle que le runbook raconte comme incident -- "Deployer ce portail avant
# le mobile peut casser silencieusement une correction faite par un
# administrateur (aucune erreur visible nulle part)".
#
# Un callable appele par le portail et absent du backend produit exactement ce
# silence : l'operateur clique, le SDK rend `not-found`, et le message qu'il
# lit parle de reseau. Le seul moment ou cela se voit sans cout, c'est ici.
Write-Host ""
Write-Host "Checking that every callable this portal calls exists in the backend..."

$serviceFiles = @(
    (Join-Path $adminRepoRoot "lib\services\admin_content_service.dart"),
    (Join-Path $adminRepoRoot "lib\services\managed_account_service.dart")
)

$calledCallables = New-Object System.Collections.Generic.List[string]
foreach ($serviceFile in $serviceFiles) {
    if (-not (Test-Path -LiteralPath $serviceFile)) {
        Write-Error "Admin service file not found: $serviceFile"
        exit 1
    }

    $raw = Get-Content -LiteralPath $serviceFile -Raw
    # Le nom passe a _callable(), seul endroit du portail ou un callable est
    # nomme. Les deux services y passent sans exception.
    foreach ($match in [regex]::Matches($raw, "_callable\(\s*'([a-zA-Z][A-Za-z0-9]*)'")) {
        $name = $match.Groups[1].Value
        if (-not $calledCallables.Contains($name)) {
            $calledCallables.Add($name)
        }
    }
}

if ($calledCallables.Count -eq 0) {
    # Un motif qui ne trouve plus rien serait un controle vert qui ne verifie
    # rien : c'est le defaut exact que ces garde-fous existent pour eviter.
    Write-Error "No callable found in the admin services. The detection pattern no longer matches -- fix it rather than trusting a green check."
    exit 1
}

$functionsIndexPath = Join-Path $resolvedMobileRepoPath "functions\src\index.ts"
if (-not (Test-Path -LiteralPath $functionsIndexPath)) {
    Write-Error "Mobile functions index not found: $functionsIndexPath"
    exit 1
}

$functionsIndexRaw = Get-Content -LiteralPath $functionsIndexPath -Raw
$unbacked = New-Object System.Collections.Generic.List[string]
foreach ($callable in $calledCallables) {
    $pattern = "(?<![A-Za-z0-9_])" + [regex]::Escape($callable) + "(?![A-Za-z0-9_])"
    if (-not [regex]::IsMatch($functionsIndexRaw, $pattern)) {
        $unbacked.Add($callable)
    }
}

if ($unbacked.Count -gt 0) {
    Write-Host ""
    Write-Error @"
This portal calls $($unbacked.Count) callable(s) that the mobile backend does not export:

$($unbacked -join "`n")

Checked against: $functionsIndexPath

Deploy order is not negotiable (see CLAUDE.md and the production runbook):
Cloud Functions and rules go out from the mobile repo FIRST, then the mobile
build, then this portal. Releasing the portal now would give operators refusals
that no screen explains.
"@
    exit 1
}

Write-Host "  $($calledCallables.Count) callable(s) checked, all backed by the mobile repo."

Write-Host ""
Write-Host "Admin/mobile contract is valid."
exit 0
