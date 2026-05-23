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

Write-Host ""
Write-Host "Admin/mobile contract is valid."
exit 0
