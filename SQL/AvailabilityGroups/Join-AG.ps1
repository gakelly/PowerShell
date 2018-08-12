<#
.Synopsis

   Join-AG
   Create an AG for SQL Server 2016

.DESCRIPTION

   Join-AG MSDBA Team, Using SQL Server and DBATools

.EXAMPLE

   Join-AG -AGDatabase "DatabaseName" -AGName "AG NAme"

.EXAMPLE

   Join-AG -AGDatabase "DatabaseName" -AGName "AG NAme" -NoBackups

#>

Function Join-AG {

    Param
    (

        [CmdletBinding()]

        # Param1 help description
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        $AGDatabase,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        $AGName,
        
        [Switch] $NoBackups

    )

    Write-Output -Message "Looking for the Availability Group [$AGName]"
    $dbs = (Get-DbaAgReplica -SqlInstance $AGName -AvailabilityGroup $AGName | Select-Object role, replica, AvailabilityMode, SeedingMode -ErrorAction SilentlyContinue)
    
    $Instance = @{Primary = $null ; Secondary = @()}# creates hash table

    $Instance.Primary = ($dbs.where{$_.Role -eq 'Primary'} | Select-Object Replica ).Replica

    foreach ($secondaryRep in ($dbs.where{$_.Role -eq 'Secondary'} | Select-Object Replica )) {

        $Instance.Secondary += $secondaryRep.replica
    
    }

    Write-Output -Message "Looking for database [$AGDatabase] on primary instance [$($Instance.Primary)]"
    if (!(Get-SqlDatabase -ServerInstance $Instance.Primary -Name $AGDatabase -ErrorAction SilentlyContinue)) {

        Write-Error "$AGDatabase does not exist on $($Instance.Primary)"
        break;
    }

    $date = Get-Date -Format yyyyMMddHHmm
    $PrimaryComputer = $($Instance.primary).Split("\")[0]

    #$SecondaryComputer = $($Instance.Secondary).Split("\")[0]
    #Backup Paths on Primary Instance

    $DatabaseBackupFile = "\\$PrimaryComputer\SQL01_Backups\$AGDatabase`_$date.bak"
    $LogBackupFile = "\\$PrimaryComputer\SQL01_Backups\$AGDatabase`_$date.trn"
    $AGPrimaryPath = "SQLSERVER:\SQL\$($Instance.Primary)\AvailabilityGroups\$AGName"


    if (!$NoBackups) {
        #Backup Database

        Write-Output -Message "Backing up Database [$AGDatabase] on primary instance [$($Instance.Primary)] "
        Backup-SqlDatabase -Database $AGDatabase -BackupFile $DatabaseBackupFile -ServerInstance $($Instance.Primary)
        Backup-SqlDatabase -Database $AGDatabase -BackupFile $LogBackupFile -ServerInstance $($Instance.Primary) -BackupAction Log

        #Restore Database to Secondary Node
        foreach ($Secondary in $Instance.Secondary) {

            Write-Output -Message "Restoring Database [$AGDatabase] to secondary instance [$($Secondary)] "
            Restore-SqlDatabase -Database $AGDatabase -BackupFile $DatabaseBackupFile -ServerInstance $($Secondary) -NoRecovery
            Restore-SqlDatabase -Database $AGDatabase -BackupFile $LogBackupFile -ServerInstance $($Secondary) -RestoreAction Log -NoRecovery
        }
    }

    Else {

        Write-Output -Message "Creating NULL backup Database [$AGDatabase] on primary instance [$($Instance.Primary)] "
        Invoke-Sqlcmd2 -ServerInstance $($Instance.Primary) -Query "BACKUP DATABASE [$AGDatabase] to disk = N'NUL'"
    }

    #Add Database to Availability Group

    Write-Output -Message "Adding Database [$AGDatabase] to Availability Group on Primary Node [$($Instance.Primary)]"
    Add-SqlAvailabilityDatabase -Path $AGPrimaryPath -Database $AGDatabase

    #Add all Secondary DBs to Availability Group


    foreach ($Secondary in $Instance.Secondary) {

        $AGSecondaryPath = "SQLSERVER:\SQL\$($Secondary)\AvailabilityGroups\$AGName"
        #Add Secondary Database to Availability Group
        Write-Output -Message "Adding Database [$AGDatabase] to Availability Group on Secondary Node [$($Secondary)]"
        try {
            Add-SqlAvailabilityDatabase -Path $AGSecondaryPath -Database $AGDatabase
        }

        Catch {

            Write-Output -Message "Database [$AGDatabase] Already added to Secondary Node  [$($Secondary)] via Direct Seeding"

        }

    }
}
