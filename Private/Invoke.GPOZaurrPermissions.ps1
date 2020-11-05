﻿$GPOZaurrPermissions = [ordered] @{
    Name       = 'Group Policy Permissions'
    Enabled    = $true
    Data       = $null
    Execute    = {
        Get-GPOZaurrPermission -Type All -IncludePermissionType GpoEditDeleteModifySecurity, GpoEdit, GpoCustom #-IncludeOwner
    }
    Processing = {

    }
    Variables  = @{

    }
    Overview   = {

    }
    Solution   = {
        New-HTMLTable -DataTable $GPOZaurrPermissions['Data'] -Filtering
    }
}