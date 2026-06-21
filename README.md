# Local Group Membership Reporter

PowerShell tooling for reporting local Windows group membership and applying guarded, target-specific membership repairs.

## Scripts

- `Local_Group_Membership_Reporter.ps1` — read-only local group and membership reporting.
- `Local_Group_Membership_Repair_Toolkit.ps1` — creates one named group or adds/removes one named member.

## Repair actions

The repair script supports:

- creating a missing local group with `-CreateGroup`;
- adding a member with `-AddMember`;
- removing a member with `-RemoveMember`.

It refuses conflicting add/remove requests and refuses to remove the currently signed-in user from the local Administrators group. Windows, the `Microsoft.PowerShell.LocalAccounts` cmdlets, and elevation are required for actual changes.

## Examples

Preview adding a domain user:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Group_Membership_Repair_Toolkit.ps1 `
  -GroupName "Remote Desktop Users" -Member "CONTOSO\User1" `
  -AddMember -DryRun
```

Create a group and add a member in one run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Group_Membership_Repair_Toolkit.ps1 `
  -GroupName "Support Operators" -CreateGroup `
  -Member "CONTOSO\SupportUser" -AddMember -Yes
```

Omit `-Yes` to require typing `YES` before changes are made.

## Evidence and verification

Each run writes `before.json`, `after.json`, and `repair.log` to a timestamped directory under `%ProgramData%\LocalGroupRepair` unless `-OutputPath` is supplied. The before-state file records the existing group and membership as recovery evidence. Applied changes are verified against the requested final membership state.

`-DryRun` logs planned actions without changing or verifying membership.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including a successful dry run |
| 2 | Invalid arguments, missing group, or safety refusal |
| 3 | Unsupported platform or missing LocalAccounts cmdlets |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | One or more repair actions failed |
| 30 | Post-repair verification failed |

## Validation status

The scripts were source-reviewed during this update. They were not runtime-tested on a Windows endpoint.

## Author

Dewald Pretorius — L2 IT Support Engineer
