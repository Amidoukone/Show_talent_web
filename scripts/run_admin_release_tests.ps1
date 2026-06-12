Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-LastExitCode {
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        exit $exitCode
    }
}

Push-Location $repoRoot
try {
    Write-Host ""
    Write-Host "==> Environment and release guardrails"
    & flutter test `
        "test\app_environment_test.dart" `
        "test\admin_release_guardrails_test.dart"
    Assert-LastExitCode

    Write-Host ""
    Write-Host "==> Managed account services"
    & flutter test `
        "test\managed_account_service_test.dart" `
        "test\managed_account_provision_result_test.dart"
    Assert-LastExitCode

    Write-Host ""
    Write-Host "==> Managed account widget"
    & flutter test "test\managed_accounts_widget_test.dart"
    Assert-LastExitCode

    Write-Host ""
    Write-Host "==> User management widget"
    & flutter test "test\user_management_widget_test.dart"
    Assert-LastExitCode
} finally {
    Pop-Location
}
