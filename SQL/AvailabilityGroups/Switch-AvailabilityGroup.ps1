 
Function Switch-AvailabilityGroup {
    Param
    (
        [CmdletBinding()]
        # Param1 help description
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String[]] $AGNames
    )


foreach ($AGName in $AGNames){

Write-Output -Message "Looking for the Availability Group [$AGName]"

$dbs = (Get-DbaAgReplica -SqlInstance $AGName -AvailabilityGroup $AGName | Select-Object role, replica -ErrorAction SilentlyContinue)
$Instance = [PSCustomObject]@{

$dbs[0].role = $dbs[0].replica
$dbs[1].role = $dbs[1].replica
}

$Instance
$ag = "SQLSERVER:\Sql\$($Instance.Secondary)\AvailabilityGroups\$AGName"

Write-Output -Message "Switching Availability Group [$ag]"
Switch-SqlAvailabilityGroup -Path $ag -Verbose
}
}