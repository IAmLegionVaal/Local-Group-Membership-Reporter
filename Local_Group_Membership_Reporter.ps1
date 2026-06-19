#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Local_Group_Reports'}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$rows=@()
foreach($group in Get-LocalGroup -ErrorAction SilentlyContinue){$members=Get-LocalGroupMember -Group $group.Name -ErrorAction SilentlyContinue;if($members){foreach($member in $members){$rows+=[PSCustomObject]@{Group=$group.Name;GroupDescription=$group.Description;Member=$member.Name;ObjectClass=$member.ObjectClass;PrincipalSource=$member.PrincipalSource;SID=$member.SID}}}else{$rows+=[PSCustomObject]@{Group=$group.Name;GroupDescription=$group.Description;Member=$null;ObjectClass=$null;PrincipalSource=$null;SID=$null}}}
$rows|Export-Csv (Join-Path $OutputPath "local_group_memberships_$stamp.csv") -NoTypeInformation -Encoding UTF8
$rows|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "local_group_memberships_$stamp.json") -Encoding UTF8
$html="<h1>Local Group Memberships - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>$($rows|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Local Group Membership Reporter'|Set-Content (Join-Path $OutputPath "local_group_memberships_$stamp.html") -Encoding UTF8
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
