UTCM monitors should not report active configuration drifts.

Microsoft Entra Unified Tenant Configuration Management (UTCM) monitors compare your configured baseline against actual tenant state. Active drifts indicate baseline deviation and can represent weakened or inconsistent security controls.

#### Remediation action:

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), open **Identity** > **Monitoring and health** > **Configuration management**.
2. Review the monitors listed with active drifts in this test result.
3. For each drifted monitor, inspect the drifted resources and determine whether to:
   - update the tenant configuration to match the approved baseline, or
   - update the baseline monitor if the current configuration is the intended secure state.
4. Re-run Maester to verify all drifts are resolved.

#### Related links

* [List configurationDrifts (Microsoft Graph beta)](https://learn.microsoft.com/en-us/graph/api/configurationmanagement-list-configurationdrifts?view=graph-rest-beta&tabs=http)
* [configurationDrift resource type (Microsoft Graph beta)](https://learn.microsoft.com/en-us/graph/api/resources/unifiedtenantconfigurationmanagement-configurationdrift?view=graph-rest-beta)
* [configurationMonitor resource type (Microsoft Graph beta)](https://learn.microsoft.com/en-us/graph/api/resources/unifiedtenantconfigurationmanagement-configurationmonitor?view=graph-rest-beta)

<!--- Results --->
%TestResult%
