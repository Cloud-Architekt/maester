BeforeDiscovery {
    $script:UtcmDriftDiscoveryError = $null

    try {
        # Fetch active drifts
        $driftsResponse = Invoke-MtGraphRequest -DisableCache -ApiVersion beta `
            -RelativeUri 'admin/configurationManagement/configurationDrifts' `
            -Filter "status eq 'active'" `
            -QueryParameters @{ '$select' = 'id,monitorId,tenantId,resourceType,baselineResourceDisplayName,firstReportedDateTime,status,driftedProperties' } `
            -OutputType Hashtable
        $activeDrifts = if ($null -ne $driftsResponse.value) { @($driftsResponse.value) } else { @() }
        Write-Verbose "Found $($activeDrifts.Count) active UTCM configuration drifts"

        # Fetch monitors to resolve displayNames
        $monitorsResponse = Invoke-MtGraphRequest -DisableCache -ApiVersion beta `
            -RelativeUri 'admin/configurationManagement/configurationMonitors' `
            -QueryParameters @{ '$select' = 'id,displayName' } `
            -OutputType Hashtable
        $monitorMap = @{}
        foreach ($monitor in @($monitorsResponse.value)) {
            if ($monitor.id) {
                $monitorMap[$monitor.id] = $monitor.displayName
            }
        }

        # Group by monitorId so each monitor produces one test
        $DriftGroups = $activeDrifts | Group-Object -Property { $_['monitorId'] } | ForEach-Object {
            $mId = $_.Name
            $mName = if ($monitorMap.ContainsKey($mId)) { $monitorMap[$mId] } else { $mId }
            @{
                MonitorId          = $mId
                MonitorDisplayName = $mName
                Drifts             = $_.Group
            }
        }

        # If there are no active drifts at all, create a single passing synthetic group
        if ($DriftGroups.Count -eq 0) {
            $DriftGroups = @(
                @{
                    MonitorId          = 'no-active-drifts'
                    MonitorDisplayName = 'Tenant configuration'
                    Drifts             = @()
                }
            )
        }
    } catch {
        Write-Verbose "Could not retrieve UTCM configuration drifts: $_"
        $script:UtcmDriftDiscoveryError = $_
        # Emit one synthetic group so that a skipped test is visible in the report
        $DriftGroups = @(
            @{
                MonitorId          = 'discovery-error'
                MonitorDisplayName = 'Tenant configuration'
                Drifts             = @()
            }
        )
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra", "Preview" -ForEach $DriftGroups {

    $TestTitle = if ($MonitorId -eq 'no-active-drifts') {
        "MT.1172: Tenant configuration should have no drifts. See https://maester.dev/docs/tests/MT.1172"
    } else {
        "MT.1172.${MonitorId}: $MonitorDisplayName should have no configuration drift. See https://maester.dev/docs/tests/MT.1172"
    }

    It $TestTitle -Tag "MT.1172", "Preview" {

        if (!(Test-MtConnection Graph)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
            return $null
        }

        if ($script:UtcmDriftDiscoveryError) {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $script:UtcmDriftDiscoveryError
            return $null
        }

        if ($MonitorId -eq 'no-active-drifts') {
            Add-MtTestResultDetail -Result "Well done. No active configuration drifts were found for any UTCM monitor in this tenant."
            $true | Should -Be $true
            return
        }

        #region Emoji map by resourceType prefix
        $emojiMap = [ordered]@{
            'microsoft.entra'    = '🔐'
            'microsoft.exchange' = '📧'
            'microsoft.teams'    = '💬'
            'microsoft.intune'   = '📱'
            'microsoft.defender' = '🛡️'
            'microsoft.purview'  = '🔒'
        }
        function Get-UtcmResourceEmoji([string]$rt) {
            foreach ($prefix in $emojiMap.Keys) {
                if ($rt -like "$prefix.*") { return $emojiMap[$prefix] }
            }
            return '⚙️'
        }
        #endregion

        #region Deep links for this monitor
        $monitorLink = "https://entra.microsoft.com/#view/Microsoft_Entra_TenantManagement/InternalMonitor.ReactView/initialTab/monitors/monitorFilterParams~/%7B%22id%22%3A%22$MonitorId%22%7D"
        $monitorResultsLink = "https://entra.microsoft.com/#view/Microsoft_Entra_TenantManagement/InternalMonitor.ReactView/initialTab/monitorResults/monitorResultsFilterParams~/%7B%22monitorId%22%3A%22$MonitorId%22%7D"
        $driftLogsLink = "https://entra.microsoft.com/#view/Microsoft_Entra_TenantManagement/InternalMonitor.ReactView/initialTab/driftLogs/driftLogsFilterParams~/%7B%22monitorId%22%3A%22$MonitorId%22%7D"
        #endregion

        #region Helper: compute diff between two values (already-array or JSON-array-or-scalar)
        function Get-UtcmDiff($currentVal, $desiredVal) {
            $lines = @()

            # Normalize each side: already-array, JSON-parseable array, or treat non-empty scalar as single-item array
            function Expand-ToArray($val) {
                if ($val -is [array]) { return [string[]]$val }
                $str = "$val".Trim()
                if ([string]::IsNullOrEmpty($str)) { return [string[]]@() }
                try {
                    $parsed = $str | ConvertFrom-Json -ErrorAction Stop
                    if ($parsed -is [array]) { return [string[]]$parsed }
                    return [string[]]@("$parsed")
                } catch {
                    return [string[]]@($str)
                }
            }

            $curArr = Expand-ToArray $currentVal
            $desArr = Expand-ToArray $desiredVal

            $onlyInCurrent = $curArr | Where-Object { $_ -notin $desArr }
            $onlyInDesired = $desArr | Where-Object { $_ -notin $curArr }
            foreach ($v in $onlyInCurrent) { $lines += "🔴 Remove ``$v``" }
            foreach ($v in $onlyInDesired) { $lines += "🟢 Add ``$v``" }
            return $lines
        }
        #endregion

        #region Build result markdown – one section per resource, properties in table
        $currentDrifts = @($_.Drifts)
        $DriftCount = $currentDrifts.Count
        $monitorLabel = if ([string]::IsNullOrEmpty($MonitorDisplayName)) { $MonitorId } else { "$MonitorDisplayName ($MonitorId)" }

        $latestDate = $currentDrifts | ForEach-Object { $_['firstReportedDateTime'] } | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
        $latestDateStr = if ($latestDate) {
            try { ([datetime]$latestDate).ToLocalTime().ToString("yyyy-MM-dd HH:mm") } catch { $latestDate }
        } else { 'unknown' }

        $resultMd = "**$DriftCount active configuration drift(s)** detected for monitor [$monitorLabel]($monitorLink)`n`nLast detected: $latestDateStr | 📊 [Monitor results]($monitorResultsLink) | 🔍 [Drift logs]($driftLogsLink)"

        $byResourceType = $currentDrifts | Group-Object -Property { $_['resourceType'] }
        foreach ($rtGroup in $byResourceType) {
            $resourceType = $rtGroup.Name
            $emoji = Get-UtcmResourceEmoji $resourceType
            $resultMd += "`n`n### $emoji $resourceType"

            foreach ($drift in $rtGroup.Group) {
                $resourceName = if ($drift['baselineResourceDisplayName']) { $drift['baselineResourceDisplayName'] } else { '(unknown)' }

                $firstReported = ''
                if ($drift['firstReportedDateTime']) {
                    try { $firstReported = ([datetime]$drift['firstReportedDateTime']).ToLocalTime().ToString('yyyy-MM-dd HH:mm') }
                    catch { $firstReported = $drift['firstReportedDateTime'] }
                }

                $resultMd += "`n`n---`n`n#### $resourceName"
                $resultMd += "`n*First detected: $firstReported*"

                if ($drift['driftedProperties'] -and $drift['driftedProperties'].Count -gt 0) {
                    foreach ($prop in $drift['driftedProperties']) {
                        $diffLines = Get-UtcmDiff $prop['currentValue'] $prop['desiredValue']
                        $resultMd += "`n`n**``$($prop['propertyName'])``**"
                        $resultMd += "`n- 🔴 **Current:** ``$($prop['currentValue'])``"
                        $resultMd += "`n- 🟢 **Desired:** ``$($prop['desiredValue'])``"
                        if ($diffLines.Count -gt 0) {
                            $resultMd += "`n- **Remediation:**"
                            foreach ($dl in $diffLines) { $resultMd += "`n  - $dl" }
                        }
                    }
                } else {
                    $resultMd += "`n`n_No drifted property details available._"
                }
            }
        }

        $resultMd += "`n`n---`n`n➡️ Open in the Entra admin portal: [Monitor]($monitorLink) | [Monitor results]($monitorResultsLink) | [Drift logs]($driftLogsLink)"
        #endregion

        Add-MtTestResultDetail -Result $resultMd -Severity "Medium"

        @($_.Drifts).Count | Should -Be 0 -Because "no active UTCM configuration drifts should exist for monitor '$MonitorDisplayName'"
    }
}
