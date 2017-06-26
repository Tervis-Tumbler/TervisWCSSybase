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

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID 3459
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    $Results = Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow

    $ConveyorScaleNumberOfUniqueWeights = $Results | 
    Group-Object -Property Weight | 
    Measure-Object | 
    Select-Object -ExpandProperty Count

    $ConveyorScaleNumberOfUniqueWeights
}

function Get-TervisWCSTervisContentsLabelsAndTervisSalesChannelXRefFileName {
    param (
        [Parameter(Mandatory)]$PasswordID
    )
    $Query = @"
select * from  TervisContentsLabels;

select * from TervisSalesChannelXRef;
"@

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $PasswordID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow
}

function Update-TervisWCSTervisContentsLabelsAndTervisSalesChannelXRefFileName {
    param (
        [Parameter(Mandatory)]$ComputerName,
        $OldComputerName,
        [Parameter(Mandatory)]$PasswordID
    )
    $Query = @"
update TervisContentsLabels
set filename = replace(filename, '$OldComputerName', '$ComputerName');

update TervisSalesChannelXRef
set filename = replace(filename, '$OldComputerName', '$ComputerName');
"@

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $PasswordID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow
}

function Update-WCSTableColumnSearchAndReplaceString {
    param (
        [Parameter(Mandatory)]$Table,
        [Parameter(Mandatory)]$Column,
        [Parameter(Mandatory)]$SearchString,
        [Parameter(Mandatory)]$ReplaceString,
        [Parameter(Mandatory)]$PasswordID
    )
    $Query = @"
update $Table
set $Column = replace($Column, '$SearchString', '$ReplaceString');
"@

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $PasswordID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow
}

function Update-TervisWCSReferencesToComputerName {
    param (
        [Parameter(Mandatory)]$ComputerName,
        $OldComputerName,
        [Parameter(Mandatory)]$PasswordID
    )

    $Parameters = @{
        SearchString = $OldComputerName
        ReplaceString = $ComputerName
        PasswordID = $PasswordID
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
        [Parameter(Mandatory)]$PasswordID
    )
    $Query = @"
update SystemParameters
set value = '$CS_Server'
where Name = 'CS_Server';
"@

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $PasswordID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow    
}

function Get-TervisWCSSystemParameterCS_Server {
    param (
        [Parameter(Mandatory)]$PasswordID
    )
    $Query = @"
select name,value from SystemParameters
where Name = 'CS_Server';
"@

    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $PasswordID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow    
}

function Get-WCSEquipment {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [ValidateSet("Top","Bottom")]$PrintEngineOrientationRelativeToLabel
    )
    $WCSEnvironmentState = Get-WCSEnvironmentState -EnvironmentName $EnvironmentName
    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $WCSEnvironmentState.SybaseQCUserPasswordEntryID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString

    $Query = @"
SELECT * FROM "qc"."Equipment"
"@
    $WCSEquipment = Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow

    if ($PrintEngineOrientationRelativeToLabel -eq "Top") {
        $WCSEquipment |
        where id -Match Shipping |
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
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderRoute -TemplateVariables @{WorkOrderId=$WorkOrderId}
}

function Get-WCSWorkOrderOrder {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderOrder -TemplateVariables @{WorkOrderId=$WorkOrderId}
}

function Get-WCSWorkOrderLine {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        $WorkOrderId = "1101-9774649-0"
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSWorkOrderLine -TemplateVariables @{WorkOrderId=$WorkOrderId}
}

function Get-WCSCartonRouteStatusesForWorkOrderLineOperations {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        $Top = 10
    )
    Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSCartonRouteStatusesForWorkOrderLineOperations -TemplateVariables @{Top=$Top}    
}

function Invoke-WCSSQLUsingTemplate {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$TemplateName,
        $TemplateVariables
    )
    $Query = Invoke-ProcessTemplateFile -TemplateFile "$(Get-WCSJavaApplicationGitRepositoryPath)\SQL\$TemplateName.sql.pstemplate" -TemplateVariables $TemplateVariables
    Invoke-WCSSQL -EnvironmentName $EnvironmentName -Query $Query
}

function Invoke-WCSSQL {
    param (
        [Parameter(Mandatory)]$EnvironmentName,
        [Parameter(Mandatory)]$Query
    )
    $WCSEnvironmentState = Get-WCSEnvironmentState -EnvironmentName $EnvironmentName
    $SybaseDatabaseEntryDetails = Get-PasswordstateSybaseDatabaseEntryDetails -PasswordID $WCSEnvironmentState.SybaseQCUserPasswordEntryID
    $ConnectionString = $SybaseDatabaseEntryDetails | ConvertTo-SQLAnywhereConnectionString
    Invoke-SQLAnywhereSQL -ConnectionString $ConnectionString -SQLCommand $Query -DatabaseEngineClassMapName SQLAnywhere -ConvertFromDataRow
}

function Get-WCSSQLConnectShipShipmentMSNMax {
    param (
        [Parameter(Mandatory)]$EnvironmentName
    )
    process {
        Invoke-WCSSQLUsingTemplate -EnvironmentName $EnvironmentName -TemplateName WCSConnectShipMSNMax |
        Select -ExpandProperty MSNMax
    }
}
