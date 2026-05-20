$ErrorActionPreference = "Stop"

$powerBiApp = Get-AppxPackage -Name "Microsoft.MicrosoftPowerBIDesktop" -ErrorAction SilentlyContinue

if ($null -eq $powerBiApp) {
    Write-Host "Power BI Desktop was not found. Install it from Microsoft Store first."
    exit 1
}

Write-Host "Opening Power BI Desktop..."
Start-Process "shell:AppsFolder\Microsoft.MicrosoftPowerBIDesktop_8wekyb3d8bbwe!App"
Write-Host "Use dashboards\powerbi_build_guide.md to create the report."
