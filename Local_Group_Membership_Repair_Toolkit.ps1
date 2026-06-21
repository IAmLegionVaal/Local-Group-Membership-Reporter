[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [Parameter(Mandatory)][string]$GroupName,
 [string]$Member,
 [switch]$AddMember,
 [switch]$RemoveMember,
 [switch]$CreateGroup,
 [switch]$DryRun,
 [switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'LocalGroupRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.json';$after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State{[pscustomobject]@{Group=Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue;Members=Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue|Select-Object Name,ObjectClass,PrincipalSource,SID}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 5|Set-Content $before -Encoding UTF8
if(-not($CreateGroup -or $AddMember -or $RemoveMember)){Write-Error 'Choose at least one repair action.';exit 2}
if(($AddMember -or $RemoveMember) -and -not $Member){Write-Error '-Member is required.';exit 2}
if($AddMember -and $RemoveMember){Write-Error 'Choose either -AddMember or -RemoveMember.';exit 2}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
if($RemoveMember -and $GroupName -ieq 'Administrators' -and $Member -match "\\$([regex]::Escape($env:USERNAME))$"){Write-Error 'Refusing to remove the current user from Administrators.';exit 2}
if(-not $Yes -and -not $DryRun){if((Read-Host "Apply selected changes to local group '$GroupName'? Type YES") -ne 'YES'){Log 'Cancelled.';exit 10}}
if($CreateGroup -and -not(Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue)){Act "Creating local group $GroupName" {New-LocalGroup -Name $GroupName|Out-Null}}
if($AddMember){Get-LocalGroup -Name $GroupName -ErrorAction Stop|Out-Null;Act "Adding $Member to $GroupName" {Add-LocalGroupMember -Group $GroupName -Member $Member}}
if($RemoveMember){Get-LocalGroup -Name $GroupName -ErrorAction Stop|Out-Null;Act "Removing $Member from $GroupName" {Remove-LocalGroupMember -Group $GroupName -Member $Member}}
Start-Sleep 1;State|ConvertTo-Json -Depth 5|Set-Content $after -Encoding UTF8
if($script:Failures){exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
