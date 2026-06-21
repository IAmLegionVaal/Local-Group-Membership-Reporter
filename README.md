# Local Group Membership Reporter

PowerShell tools for reporting local Windows group membership and applying guarded membership corrections.

## Report

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Group_Membership_Reporter.ps1
```

## Repair

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Local_Group_Membership_Repair_Toolkit.ps1 -GroupName 'Remote Desktop Users' -Member 'CONTOSO\User1' -AddMember -DryRun
```

Examples:

```powershell
.\Local_Group_Membership_Repair_Toolkit.ps1 -GroupName 'Support Operators' -CreateGroup
.\Local_Group_Membership_Repair_Toolkit.ps1 -GroupName Administrators -Member 'CONTOSO\ITAdmin' -AddMember
.\Local_Group_Membership_Repair_Toolkit.ps1 -GroupName 'Remote Desktop Users' -Member 'CONTOSO\OldUser' -RemoveMember
```

The repair script captures group membership before and after each change, supports `-DryRun`, confirmation, logs and clear exit codes. It refuses to remove the current user from the local Administrators group.

## Author

Dewald Pretorius — L2 IT Support Engineer
