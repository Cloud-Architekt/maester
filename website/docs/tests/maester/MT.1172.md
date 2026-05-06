---
title: MT.1172 - No active UTCM configuration drifts detected
description: Checks whether any active configuration drifts are reported by Microsoft Entra Unified Tenant Configuration Management (UTCM) monitors.
slug: /tests/MT.1172
sidebar_class_name: hidden
---

# No active UTCM configuration drifts detected

## Overview

> **Preview:** This check uses the Microsoft Graph beta API (`/beta/admin/configurationManagement/configurationDrifts`).
> Beta APIs are subject to change and are not guaranteed to be available in all tenants.
> The `ConfigurationMonitoring.Read.All` permission is required.

Microsoft Entra **Unified Tenant Configuration Management (UTCM)** allows administrators to define security and compliance baselines (called *monitors*) for their Microsoft 365 tenant.
When a live tenant setting no longer matches the baseline, the service creates a **configuration drift** record.

This check queries all active drifts filtered to the current tenant and groups them by monitor ID.
One test result is produced per monitor — a failing result means one or more resources have drifted from the defined baseline.

Each failing result includes a detailed table showing:

- Which baseline resource drifted (`baselineResourceDisplayName`)
- The resource type (e.g. `microsoft.exchange.accepteddomain`)
- The exact resource instance (`resourceInstanceIdentifier`)
- When the drift was first detected (`firstReportedDateTime`)
- Property-level detail: property name, current (drifted) value, and desired (baseline) value

## How to fix

Review and remediate each active drift in the Microsoft Entra admin portal:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Administrator** or **Security Administrator**.
2. Browse to **[Configuration Management](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/TenantConfigMonitorBlade)**.
3. Select the monitor with active drifts.
4. Review the drifted properties and restore the setting to its baseline value.
5. Once remediated, the drift status will automatically transition to `fixed`.

If a drift is intentional (e.g. an approved exception), consider updating the baseline to reflect the approved state or documenting the exception.

## Required permission

This check requires the `ConfigurationMonitoring.Read.All` Microsoft Graph permission.
Add it to your connection scope:

```powershell
Connect-MgGraph -Scopes (Get-MtGraphScope), 'ConfigurationMonitoring.Read.All'
```

## Learn more

- [List configurationDrifts - Microsoft Graph beta](https://learn.microsoft.com/en-us/graph/api/configurationmanagement-list-configurationdrifts?view=graph-rest-beta)
- [configurationDrift resource type](https://learn.microsoft.com/en-us/graph/api/resources/configurationdrift?view=graph-rest-beta)
- [Entra admin center - Configuration Management](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/TenantConfigMonitorBlade)
