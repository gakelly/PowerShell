 <#


.Synopsis


   New-AG


   New Availability group for SQL Server 2016


.DESCRIPTION


   New-AG MSDBA Team, Using SQL Server and DBATools


.EXAMPLE


   New-AG -AGDatabase "Arc_NQSC-ARC-01-PR02" -AGName "AG-ARC-01-PR02" -PrimaryInstance PRSQLDBS881\SQL01 -SecondaryInstance PRQLDBS882\SQL01


.EXAMPLE


   Another example of how to use this cmdlet


#>



function New-AG  {


    Param


    (


        [CmdletBinding()]


        # Param1 help description


        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]


        $AGDatabase,



        # Param2 help description


        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]


        $BackUpShare,


        


        # Param2 help description


        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]


        [string[]]$ListenerIPs,



        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]


        $PrimaryInstance,



        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]


        $SecondaryInstance,



        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]


        $AGName



　


　


　


    )



    $date = Get-Date -Format yyyyMMddHHmm



    $PrimaryComputer = $($PrimaryInstance).Split("\")[0]


    $SecondaryComputer = $($SecondaryInstance).Split("\")[0]



　


    if($AGDatabase -ne $null){


    #Backup Paths on Primary Instance


    $DatabaseBackupFile = "\\$PrimaryComputer\SQL01_Backups\$AGDatabase`_$date.bak"


    $LogBackupFile = "\\$PrimaryComputer\SQL01_Backups\$AGDatabase`_$date.trn"



    #Backup Database


    Write-Output "Backing up Database [$AGDatabase] on primary instance [$($PrimaryInstance)] "


    Backup-SqlDatabase -Database $AGDatabase -BackupFile $DatabaseBackupFile -ServerInstance $($PrimaryInstance)


    Backup-SqlDatabase -Database $AGDatabase -BackupFile $LogBackupFile -ServerInstance $($PrimaryInstance) -BackupAction Log



    #Restore Database to Secondary Node


    Write-Output "Restoring Database [$AGDatabase] to secondary instance [$($SecondaryInstance)] "


    Restore-SqlDatabase -Database $AGDatabase -BackupFile $DatabaseBackupFile -ServerInstance $($SecondaryInstance) -NoRecovery


    Restore-SqlDatabase -Database $AGDatabase -BackupFile $LogBackupFile -ServerInstance $($SecondaryInstance) -RestoreAction Log -NoRecovery



   


    }



    #Connect to SQL Instances and Return Version Number


    $PrimaryServerPath = Get-Item "SQLSERVER:\SQL\$PrimaryInstance"


    $SecondaryServerPath = Get-Item "SQLSERVER:\SQL\$SecondaryInstance"


    Write-Output "SQL instance [$PrimaryInstance]; SQL Version [$($PrimaryServerPath.Version)] "


    Write-Output "SQL instance [$SecondaryInstance]; SQL Version [$($SecondaryServerPath.Version)] "



　


    #Create an in-memory representation of the primary replica.


    Write-Output "Creating new Primary Availability Replica on [$($PrimaryInstance)]"


    $primaryReplica = New-SqlAvailabilityReplica  -Name "$PrimaryInstance"  -EndpointURL "TCP://$PrimaryComputer`.$env:USERDNSDOMAIN`:5022" -AvailabilityMode "SynchronousCommit" -FailoverMode "Automatic" -SeedingMode "Automatic" -AsTemplate  -Version ($PrimaryServerPath.Version) 



    #Create an in-memory representation of the secondary replica.


    Write-Output "Creating new Secondary Availability Replica on [$($SecondaryInstance)]"


    $secondaryReplica = New-SqlAvailabilityReplica  -Name "$SecondaryInstance"  -EndpointURL "TCP://$SecondaryComputer`.$env:USERDNSDOMAIN`:5022"   -AvailabilityMode "SynchronousCommit"  -FailoverMode "Automatic" -SeedingMode "Automatic" -AsTemplate  -Version ($SecondaryServerPath.Version)



    #Create the availability group


    Write-Output "Creating new Availability Group [$AGName]"


    New-SqlAvailabilityGroup  -Name $AGName  -Path "SQLSERVER:\SQL\$PrimaryInstance"  -AvailabilityReplica @($primaryReplica,$secondaryReplica)



    #Join the secondary replica to the availability group.


    Write-Output "Joining Secondary instance [$SecondaryInstance] to Availability Group [$AGName]"


    Join-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$SecondaryInstance" -Name $AGName 



    #Give the AG the ability to auto seed a database


    Write-Output "Granting Auto Seeding permissions to [$AGName]"


    Grant-SqlAvailabilityGroupCreateAnyDatabase -Path "SQLSERVER:\SQL\$SecondaryInstance\AvailabilityGroups\$AGName"


    Grant-SqlAvailabilityGroupCreateAnyDatabase -Path "SQLSERVER:\SQL\$PrimaryInstance\AvailabilityGroups\$AGName"



    if($AGDatabase -ne $null){


    #Add DB on Primary Node


    Write-Output -Message "Adding Database [$AGDatabase] to Availability Group on Primary Node [$($PrimaryInstance)]"


    Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$PrimaryInstance\AvailabilityGroups\$AGName" -Database $AGDatabase


    #Add DB on Secondary Node


    


    Write-Output -Message "Adding Database [$AGDatabase] to Availability Group on Primary Node [$($SecondaryInstance)]"


    try{


    Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$SecondaryInstance\AvailabilityGroups\$AGName" -Database $AGDatabase


        }


    Catch {


    Write-Output -Message "Database [$AGDatabase] Already added to Secondary Node  [$($SecondaryInstance)] via Direct Seeding"


        }


  }



　


　


    if($ListenerIPs){


    Write-Output "Adding Listener IPs to [$AGName]"



    New-SqlAvailabilityGroupListener -Name $AGName -StaticIp $ListenerIPs -Path "SQLSERVER:\Sql\$PrimaryInstance\AvailabilityGroups\$AGName"



    }



　


} 
