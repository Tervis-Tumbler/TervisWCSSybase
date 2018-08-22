function Get-ConveyorScaleNumberOfUniqueWeights {
    param (
        [Parameter(Mandatory)]$NumberOfBoxesToSample
    )
    $Query = @"
SELECT top $NumberOfBoxesToSample
    ts,
    weight
FROM "qc"."ScaleLog"
order by ts DESC 
"@

    $Results = Invoke-WCSSQL -EnvironmentName Production -Query $Query

    $ConveyorScaleNumberOfUniqueWeights = $Results | 
    Group-Object -Property Weight | 
    Measure-Object | 
    Select-Object -ExpandProperty Count

    $ConveyorScaleNumberOfUniqueWeights
}

function Get-TervisWCSTervisContentsLabelsAndTervisSalesChannelXRefFileName {
    param (
        [Parameter(Mandatory)]$EnvironmentName
    )
    $Query = @"
select * from  TervisContentsLabels;

select * from TervisSalesChannelXRef;
"@

    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Update-TervisWCSTervisContentsLabelsAndTervisSalesChannelXRefFileName {
    param (
        [Parameter(Mandatory)]$ComputerName,
        $OldComputerName,
        [Parameter(Mandatory)]$EnvironmentName
    )
    $Query = @"
update TervisContentsLabels
set filename = replace(filename, '$OldComputerName', '$ComputerName');

update TervisSalesChannelXRef
set filename = replace(filename, '$OldComputerName', '$ComputerName');
"@

    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Update-WCSTableColumnSearchAndReplaceString {
    param (
        [Parameter(Mandatory)]$Table,
        [Parameter(Mandatory)]$Column,
        [Parameter(Mandatory)]$SearchString,
        [Parameter(Mandatory)]$ReplaceString,
        [Parameter(Mandatory)]$EnvironmentName
    )
    $Query = @"
update $Table
set $Column = replace($Column, '$SearchString', '$ReplaceString');
"@

    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Update-TervisWCSReferencesToComputerName {
    param (
        [Parameter(Mandatory)]$ComputerName,
        $OldComputerName,
        [Parameter(Mandatory)]$EnvironmentName
    )

    $Parameters = @{
        SearchString = $OldComputerName
        ReplaceString = $ComputerName
        EnvironmentName = $EnvironmentName
    }

    Update-WCSTableColumnSearchAndReplaceString -Table TervisContentsLabels -Column filename @Parameters
    Update-WCSTableColumnSearchAndReplaceString -Table TervisSalesChannelXRef -Column filename @Parameters
    Update-WCSTableColumnSearchAndReplaceString -Table TervisCustomer -Column fullGS1Format @Parameters
    Update-WCSTableColumnSearchAndReplaceString -Table TervisCustomer -Column miniContents @Parameters
    Update-WCSTableColumnSearchAndReplaceString -Table TervisCustomer -Column fullContents @Parameters
    Update-WCSTableColumnSearchAndReplaceString -Table TervisCustomer -Column orderPackSlip @Parameters
}

function Set-TervisWCSSystemParameterCS_Server {
    param (
        [Parameter(Mandatory)]$CS_Server,
        [Parameter(Mandatory)]$EnvironmentName
    )
    $Query = @"
update SystemParameters
set value = '$CS_Server'
where Name = 'CS_Server';
"@
    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Get-TervisWCSSystemParameterCS_Server {
    param (
        [Parameter(Mandatory)]$EnvironmentName
    )
    $Query = @"
select name,value from SystemParameters
where Name = 'CS_Server';
"@

    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Get-WCSEquipment {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [ValidateSet("Top","Bottom")]$PrintEngineOrientationRelativeToLabel
    )
    $Query = @"
SELECT * FROM "qc"."Equipment"
"@
    $WCSEquipment = Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query

    if ($PrintEngineOrientationRelativeToLabel -eq "Top") {
        $WCSEquipment |
        where {$_.id -Match "Shipping" -or $_.id -Match "PrintApply"} |
        where id -NotMatch _PL
    } elseif ($PrintEngineOrientationRelativeToLabel -eq "Bottom") {
        $WCSEquipment |
        where id -Match _PL
    } else {
        $WCSEquipment
    }
}

function Get-WCSDatabaseName {
    $ConnectionString = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID 3718 | ConvertTo-SQLAnywhereConnectionString
    Get-DatabaseNames -ConnectionString $ConnectionString
}

function Get-WCSWorkOrderRoute {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath,
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderRoute -TemplateVariables @{WorkOrderId=$WorkOrderId} -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
}

function Get-WCSWorkOrderOrder {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath,
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderOrder -TemplateVariables @{WorkOrderId=$WorkOrderId} -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
}

function Get-WCSWorkOrderLine {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath,
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderLine -TemplateVariables @{WorkOrderId=$WorkOrderId} -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
}

function Get-WCSCartonRouteStatusesForWorkOrderLineOperations {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath,
        $Top = 10
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSCartonRouteStatusesForWorkOrderLineOperations -TemplateVariables @{Top=$Top} -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
}

function Invoke-WCSSQLUsingTemplate {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$TemplateName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath,
        $TemplateVariables
    )
    $Query = Invoke-ProcessTemplateFile -TemplateFile "$WCSJavaApplicationGitRepositoryPath\SQL\$TemplateName.sql.pstemplate" -TemplateVariables $TemplateVariables
    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Invoke-WCSSQL {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$Query
    )
    $WCSEnvironmentState = Get-WCSEnvironmentState -EnvironmentName $EnvironmentName
    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -GUID $WCSEnvironmentState.SybaseQCUserPasswordEntryGUID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString
    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -ConvertFromDataRow
}

function Get-WCSSQLConnectShipShipmentMSNMax {
    param (
        [Parameter(Mandatory)]$EnvironmentName
    )
    begin {
        $WCSJavaApplicationGitRepositoryPath = (Get-WCSJavaApplicationGitRepositoryPath)
    }
    process {
        Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSConnectShipMSNMax -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath |
        Select -ExpandProperty MSNMax
    }
}

function Remove-TervisWCSSybaseConnectionsNotFromShipping {
    $ShippingComputers = Get-ADComputer -Filter {Name -like "Ship*"}
    $DNSResponsesForShippingComputers = $ShippingComputers | % { Resolve-DnsName -Name $_.name }

    $SystemsAllowedToConnectToWCSSybase = @"
p-weblogic01
ScheduledTasks
PRD-WCSApp01
PRD-Progis01
PRD-Bartender01
"@ -split "`r`n"
    
    $IPAddressesOfSystemsAllowedToConnectToWCSSybase = foreach ($Name in $SystemsAllowedToConnectToWCSSybase) {
         Resolve-DnsName -Name $Name |
         Select-Object -ExpandProperty IPAddress
    }

    $IPAddressesNotToRemove = $DNSResponsesForShippingComputers.IPAddress + $IPAddressesOfSystemsAllowedToConnectToWCSSybase
    #$IPAddressesNotToRemove = $IPAddressesOfSystemsAllowedToConnectToWCSSybase + "10.55.1.92"

    while ($true) {
        $Connections = Get-TervisSQLAnywhereConnection -EnvironmentName production

        $ConnectionsToRemove = $Connections | 
        where {$_.NodeAddr } | 
        where NodeAddr -ne "NA" |
        where NodeAddr -NotIn $IPAddressesNotToRemove

        $ConnectionsToRemove
        $ConnectionsToRemove | ConvertTo-Json | Out-File -Append $HOME\ConnectionsToRemove.Json -NoNewline -Encoding ascii
        $ConnectionsToRemove | % { Remove-TervisSQLAnywhereConnection -EnvironmentName Production -ID $_.Number}
        sleep 2

    }
}

function Get-TervisWCSSybaseConnectionsBlocked {
    $Connections = Get-TervisSQLAnywhereConnection -EnvironmentName production 
    
    $Connections |
    Where BlockedOn -ne 0
}

function Enable-WCSConnectShipCarrierXrefSmartPostFlagsForPrintapply {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath
    )
    process {
        Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName Enable-WCSConnectShipCarrierXrefSmartPostFlagsForPrintapply -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
    }
}

function Disable-WCSConnectShipCarrierXrefSmartPostFlagsForPrintapply {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$WCSJavaApplicationGitRepositoryPath
    )
    process {
        Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName Disable-WCSConnectShipCarrierXrefSmartPostFlagsForPrintapply -WCSJavaApplicationGitRepositoryPath $WCSJavaApplicationGitRepositoryPath
    } 
}

function Invoke-SQLAnywhereProvision {
    param (
        $EnvironmentName
    )
    Invoke-ApplicationProvision -ApplicationName "SQL Anywhere" -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisApplicationNode -ApplicationName "SQL Anywhere" -EnvironmentName $EnvironmentName   
}

function Get-WCSShipDate {
    param (
        $EnvironmentName
    )
    if (-not $Script:WCSShipDateQuery) {
        $Script:WCSShipDateQuery = Get-TervisPasswordstatePassword -Guid 0c8717f5-1d26-4394-aa0a-089febd45a1a |
        Select-Object -ExpandProperty Description    
    }
    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Script:WCSShipDateQuery
}