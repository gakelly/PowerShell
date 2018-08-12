 <#


.Synopsis

   SQL Patching Script


.DESCRIPTION

   Installs and tests patches for SQL Boxes

.EXAMPLE


   Check for patch compliance


   Start-SQLServerPatches -Environment Development -CheckPatches


.EXAMPLE


   Install any pending patches for the entire environment


   Start-SQLServerPatches -Environment Development -InstallPatches



#>


function Start-SQLServerPatches


{


    [CmdletBinding()]


    [Alias()]


    Param


    (


        # Param1 help description


        [Parameter(Mandatory=$true,


                   ValueFromPipelineByPropertyName=$true,


                   Position=0)]


                   [ValidateSet("Production","Pre-Production", "Development")]


        $Environment,

        # Param2 help description

        [Switch]

        $CheckPatches,

        [switch]

        $installPatches,

        [switch]

        $rebootPrimary,

        [switch]


        $rebootSecondary



　


　


    )



    Begin


    {


        switch ($Environment) {


            'Production' {


            $servergroups = @("msSQL16_sERVERS_prod","msSQL12_sERVERS_prod")



            $serverList = foreach ($group in $servergroups){(Get-ADGroupMember -Identity $group| Where-Object  {$_.name -ne "$env:COMPUTERNAME" } |Sort-Object name).NAME}


             }


            'Pre-Production' {


            $servergroups = @("msSQL16_sERVERS_pre","msSQL12_sERVERS_pre")



            $serverList = foreach ($group in $servergroups){(Get-ADGroupMember -Identity $group| Where-Object  {$_.name -ne "$env:COMPUTERNAME" } |Sort-Object name).NAME}


            }


            'Development' {


            $servergroups = @("msSQL16_sERVERS_Dev","msSQL12_sERVERS_Dev")



            $serverList = foreach ($group in $servergroups){(Get-ADGroupMember -Identity $group| Where-Object  {$_.name -ne "$env:COMPUTERNAME" } |Sort-Object name).NAME}


            }


            Default {}


        }



　


    }


    Process


    {


       # $serverList


        if ($checkPatches){


            foreach ($server in $serverList)


        {



#Check if Server is online or not


#


 If ((Test-NetConnection  -ComputerName $server).pingsucceeded)


    {


        #Check if SCCM client service is running or not


        #


        $SMSAgentService = get-service -ComputerName $server -name CcmExec |select status



        #If SCCM client service is running, execute the below


        #


        If ($SMSAgentService.Status -eq "Running")


        {


            #Query CCM_SoftwareUpdate for KBs list


            #


            $kb = get-wmiobject -ComputerName $server -query "SELECT * FROM CCM_SoftwareUpdate" -namespace "ROOT\ccm\ClientSDK"|select name


            $kbs= $kb.name|out-string


         #   $kbs


            #Check if there any KBs to install, if not set KBs to Null


            #


           # if ($kbs -like $null)


               # {


             #    $kbs ="None"



            #    }


            $rebootstatus =(get-wmiobject -ComputerName $server -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -list).DetermineIfRebootPending().RebootPending


            $rebootstatusresult = $rebootstatus |Out-string



          if ($kbs -like $null)


          {


           write-host $server -ForegroundColor Green -NoNewline; Write-Host " does not have any new security patches to install"



          }



         if (!($kbs -like $null))


          {


           write-host $server -ForegroundColor Cyan -NoNewline; Write-Host " Requires the following patches: `n $kbs"



          }



          If($rebootstatusresult -match "False"){



          write-host $server -ForegroundColor Green -NoNewline; Write-Host " does not require a reboot`n"



          }



          If(!($rebootstatusresult -match "False")){



          write-host $server -ForegroundColor Cyan -NoNewline; Write-Host " requires a reboot`n"



          }



          $kbs = $null



          }



　


          }



}


if ($installPatches){


 ForEach ($system in $serverList){



$wmicheck=$null


$wmicheck =Get-WmiObject -ComputerName $system -namespace root\cimv2 -Class Win32_BIOS -ErrorAction SilentlyContinue


if ($wmicheck)


{


    # Get list of all instances of CCM_SoftwareUpdate from root\CCM\ClientSDK for missing updates https://msdn.microsoft.com/en-us/library/jj155450.aspx?f=255&MSPPError=-2147217396


    $TargetedUpdates= Get-WmiObject -ComputerName $system -Namespace root\CCM\ClientSDK -Class CCM_SoftwareUpdate -Filter ComplianceState=0


    $approvedUpdates= ($TargetedUpdates |Measure-Object).count


    $pendingpatches=($TargetedUpdates |Where-Object {$TargetedUpdates.EvaluationState -ne 8} |Measure-Object).count


    $rebootpending=($TargetedUpdates |Where-Object {$TargetedUpdates.EvaluationState -eq 8} |Measure-Object).count


if ($pendingpatches -gt 0)


{


  try {


	$MissingUpdatesReformatted = @($TargetedUpdates | ForEach-Object {if($_.ComplianceState -eq 0){[WMI]$_.__PATH}})


	# The following is the invoke of the CCM_SoftwareUpdatesManager.InstallUpdates with our found updates


	$InstallReturn = Invoke-WmiMethod -ComputerName $system -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList (,$MissingUpdatesReformatted) -Namespace root\ccm\clientsdk


	"$system,Targeted Patches :$approvedUpdates,Pending patches:$pendingpatches,Reboot Pending patches :$rebootpending,initiated $pendingpatches patches for install"# | Out-File $log -append


	  }


	catch {"$System,pending patches - $pendingpatches but unable to install them ,please check Further" }#| Out-File $log -append }


}


else {"$system,Targeted Patches :$approvedUpdates,Pending patches:$pendingpatches,Reboot Pending patches :$rebootpending,Compliant" }#| Out-File $log -append }


}


else {"$system,Unable to connect to remote system ,please check further" }# | Out-File $log -append }


}


    }



　

        }



　


　


if ($rebootPrimary){



　


    $Primary =  foreach ($server in $serverList){



　


        if ($server.EndsWith("1")){



        $server



        }



        }


        $Primary


}



　


　


if ($rebootSecondary){



　


    $Secondary =  foreach ($server in $serverList){



　


        if ($server.EndsWith("2")){



        $server



        }



        }


        $Secondary


}



　


　


　


　


    }


    End


    {


    }


} 
