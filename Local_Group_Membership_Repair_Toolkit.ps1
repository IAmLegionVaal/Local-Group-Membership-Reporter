[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GroupName,
    [string]$Member,
    [switch]$AddMember,
    [switch]$RemoveMember,
    [switch]$CreateGroup,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'LocalGroupRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows.'; exit 3 }
if (-not ($CreateGroup -or $AddMember -or $RemoveMember)) { Write-Error 'Choose at least one repair action.'; exit 2 }
if (($AddMember -or $RemoveMember) -and [string]::IsNullOrWhiteSpace($Member)) { Write-Error '-Member is required.'; exit 2 }
if ($AddMember -and $RemoveMember) { Write-Error 'Choose either -AddMember or -RemoveMember.'; exit 2 }
if (-not (Get-Command Get-LocalGroup -ErrorAction SilentlyContinue)) { Write-Error 'Microsoft.PowerShell.LocalAccounts is unavailable in this PowerShell host.'; exit 3 }
if (-not $DryRun -and -not (Test-Administrator)) { Write-Error 'Run from an elevated PowerShell session.'; exit 4 }

$existingGroup = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
if (-not $existingGroup -and -not $CreateGroup) { Write-Error "Local group '$GroupName' does not exist. Use -CreateGroup to create it."; exit 2 }
if ($RemoveMember -and $GroupName -ieq 'Administrators') {
    $currentCandidates = @($env:USERNAME, "$env:COMPUTERNAME\$env:USERNAME", "$env:USERDOMAIN\$env:USERNAME")
    if ($currentCandidates -icontains $Member) { Write-Error 'Refusing to remove the current user from Administrators.'; exit 2 }
}

$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.json'
$afterPath = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append
}
function Get-RepairState {
    $group = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
    $members = @()
    if ($group) {
        $members = @(Get-LocalGroupMember -Group $group.Name -ErrorAction SilentlyContinue |
            Select-Object Name,ObjectClass,PrincipalSource,SID)
    }
    [pscustomobject]@{ Group = $group; Members = $members }
}
function Test-MemberPresent([object[]]$Members,[string]$RequestedMember) {
    foreach ($entry in $Members) {
        $name = [string]$entry.Name
        if ($name -ieq $RequestedMember -or $name -ilike "*\$RequestedMember") { return $true }
        if ($entry.SID -and ([string]$entry.SID -ieq $RequestedMember)) { return $true }
    }
    return $false
}
function Invoke-RepairAction([string]$Description,[scriptblock]$Script) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        & $Script
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}

Get-RepairState | ConvertTo-Json -Depth 6 | Set-Content $beforePath -Encoding UTF8
Write-Log "Saved pre-change group state to $beforePath"

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host "Apply selected changes to local group '$GroupName'? Type YES") -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($CreateGroup -and -not $existingGroup) {
    Invoke-RepairAction "Creating local group $GroupName" { New-LocalGroup -Name $GroupName | Out-Null }
}
if ($AddMember) {
    Invoke-RepairAction "Adding $Member to $GroupName" {
        $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
        $members = @(Get-LocalGroupMember -Group $group.Name -ErrorAction SilentlyContinue)
        if (-not (Test-MemberPresent -Members $members -RequestedMember $Member)) {
            Add-LocalGroupMember -Group $group.Name -Member $Member
        }
    }
}
if ($RemoveMember) {
    Invoke-RepairAction "Removing $Member from $GroupName" {
        $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
        $members = @(Get-LocalGroupMember -Group $group.Name -ErrorAction SilentlyContinue)
        if (Test-MemberPresent -Members $members -RequestedMember $Member) {
            Remove-LocalGroupMember -Group $group.Name -Member $Member
        }
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 1 }
$finalState = Get-RepairState
$finalState | ConvertTo-Json -Depth 6 | Set-Content $afterPath -Encoding UTF8

if (-not $DryRun) {
    if ($CreateGroup -and -not $finalState.Group) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: group was not created.' }
    if ($AddMember -and -not (Test-MemberPresent -Members $finalState.Members -RequestedMember $Member)) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: requested member is not present.' }
    if ($RemoveMember -and (Test-MemberPresent -Members $finalState.Members -RequestedMember $Member)) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: requested member is still present.' }
}

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Workflow completed. Actions: $script:Actions; DryRun: $DryRun"
exit 0
