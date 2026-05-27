function Test-MtConfigurationDrift {
    <#
    .SYNOPSIS
    Checks for active configuration drift in Microsoft Entra UTCM monitors.

    .DESCRIPTION
    MT.1172 - UTCM monitors should not report active configuration drifts.

    The check queries Microsoft Graph UTCM configuration drifts filtered to active status and reports the monitors that currently have drifted resources.

    .EXAMPLE
    Test-MtConfigurationDrift

    Returns $true if no active configuration drifts are found.

    .LINK
    https://maester.dev/docs/commands/Test-MtConfigurationDrift
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Test-MtConfigurationDrift: Checking UTCM monitors for active configuration drifts."

    try {
        $ActiveDriftsResponse = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/configurationManagement/configurationDrifts" -Filter "status eq 'active'" -Select id, monitorId, resourceType, baselineResourceDisplayName, resourceInstanceIdentifier, status
        $MonitorsResponse = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/configurationManagement/configurationMonitors" -Select id, displayName

        $ActiveDrifts = @()
        if ($ActiveDriftsResponse -is [Array]) {
            $ActiveDrifts = $ActiveDriftsResponse
        } elseif ($null -ne $ActiveDriftsResponse.value) {
            $ActiveDrifts = $ActiveDriftsResponse.value
        } elseif ($null -ne $ActiveDriftsResponse) {
            $ActiveDrifts = @($ActiveDriftsResponse)
        }

        $Monitors = @()
        if ($MonitorsResponse -is [Array]) {
            $Monitors = $MonitorsResponse
        } elseif ($null -ne $MonitorsResponse.value) {
            $Monitors = $MonitorsResponse.value
        } elseif ($null -ne $MonitorsResponse) {
            $Monitors = @($MonitorsResponse)
        }

        $MonitorNamesById = @{}
        foreach ($Monitor in $Monitors) {
            $MonitorId = if ($null -ne $Monitor.id) { $Monitor.id } else { $Monitor.PSObject.Properties['id'].Value }
            if ([string]::IsNullOrWhiteSpace($MonitorId)) {
                continue
            }

            $MonitorDisplayName = if ($null -ne $Monitor.displayName) { $Monitor.displayName } else { $Monitor.PSObject.Properties['displayName'].Value }
            $MonitorNamesById[$MonitorId] = $MonitorDisplayName
        }

        if ($ActiveDrifts.Count -eq 0) {
            Add-MtTestResultDetail -Result "Well done. UTCM monitors have no active configuration drifts."
            return $true
        }

        $GroupedDrifts = @($ActiveDrifts | Group-Object -Property monitorId)
        $TestResultMarkdown = "Found $($ActiveDrifts.Count) active configuration drift(s) across $($GroupedDrifts.Count) UTCM monitor(s).`n`n"
        $TestResultMarkdown += "| Monitor | Active drifts |`n"
        $TestResultMarkdown += "| --- | ---: |`n"

        foreach ($DriftGroup in $GroupedDrifts | Sort-Object Name) {
            $MonitorId = $DriftGroup.Name
            $MonitorName = if ($MonitorNamesById.ContainsKey($MonitorId)) { $MonitorNamesById[$MonitorId] } else { "Unknown monitor ($MonitorId)" }
            $TestResultMarkdown += "| $(Get-MtSafeMarkdown $MonitorName) | $($DriftGroup.Count) |`n"
        }

        $TestResultMarkdown += "`n| Monitor | Baseline resource | Resource type | Resource identifier |`n"
        $TestResultMarkdown += "| --- | --- | --- | --- |`n"
        foreach ($Drift in $ActiveDrifts | Sort-Object monitorId, baselineResourceDisplayName) {
            $MonitorId = if ($null -ne $Drift.monitorId) { $Drift.monitorId } else { $Drift.PSObject.Properties['monitorId'].Value }
            $MonitorName = if ($MonitorNamesById.ContainsKey($MonitorId)) { $MonitorNamesById[$MonitorId] } else { "Unknown monitor ($MonitorId)" }
            $BaselineResource = if ($null -ne $Drift.baselineResourceDisplayName) { $Drift.baselineResourceDisplayName } else { "" }
            $ResourceType = if ($null -ne $Drift.resourceType) { $Drift.resourceType } else { "" }
            $ResourceIdentifier = if ($null -ne $Drift.resourceInstanceIdentifier) { $Drift.resourceInstanceIdentifier } else { "" }
            $TestResultMarkdown += "| $(Get-MtSafeMarkdown $MonitorName) | $(Get-MtSafeMarkdown $BaselineResource) | $(Get-MtSafeMarkdown $ResourceType) | $(Get-MtSafeMarkdown $ResourceIdentifier) |`n"
        }

        Add-MtTestResultDetail -Result $TestResultMarkdown
        return $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
