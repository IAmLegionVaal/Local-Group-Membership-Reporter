# Local Group Membership Reporter

A read-only PowerShell toolkit for Windows local group membership reporting.

## Features

- Local group inventory
- Member type and source reporting
- Empty-group and privileged-group visibility
- CSV, JSON, and HTML reports

## Run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Group_Membership_Reporter.ps1
```

## Safety

Read-only reporting only. No group memberships are changed.
