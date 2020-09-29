﻿function Remove-GPOZaurrOrphaned {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('SYSVOL', 'AD')][string[]] $Type = @('SYSVOL', 'AD'),
        [string] $BackupPath,
        [switch] $BackupDated,
        [int] $LimitProcessing = [int32]::MaxValue,

        [alias('ForestName')][string] $Forest,
        [string[]] $ExcludeDomains,
        [alias('Domain', 'Domains')][string[]] $IncludeDomains,
        [System.Collections.IDictionary] $ExtendedForestInformation
    )
    if ($BackupPath) {
        if ($BackupDated) {
            $BackupFinalPath = "$BackupPath\$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss'))"
        } else {
            $BackupFinalPath = $BackupPath
        }
    } else {
        $BackupFinalPath = ''
    }
    Get-GPOZaurrSysvol -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains -ExtendedForestInformation $ExtendedForestInformation | Where-Object {
        if ($Type -contains 'SYSVOL') {
            if ($_.Status -eq 'Not available in AD') {
                $_
            }
        }
        if ($Type -contains 'AD') {
            if ($_.Status -eq 'Not available on SYSVOL') {
                $_
            }
        }
    } | Select-Object | Select-Object -First $LimitProcessing | ForEach-Object {
        if ($_.Status -eq 'Not available in AD') {
            Write-Verbose "Remove-GPOZaurrOrphaned - Processing $($_.Path)"
            if ($BackupFinalPath) {
                Try {
                    Write-Verbose "Remove-GPOZaurrOrphaned - Backing up $($_.Path)"
                    Copy-Item -LiteralPath $_.Path -Recurse -Destination $BackupFinalPath -ErrorAction Stop
                    $BackupWorked = $true
                } catch {
                    Write-Warning "Remove-GPOZaurrOrphaned - Error backing up error: $($_.Exception.Message)"
                    $BackupWorked = $false
                }
            }
            if ($BackupWorked -or $BackupFinalPath -eq '') {
                Write-Verbose "Remove-GPOZaurrOrphaned - Deleting $($_.Path)"
                try {
                    Remove-Item -Recurse -Force -LiteralPath $_.Path
                } catch {
                    Write-Warning "Remove-GPOZaurrOrphaned - Failed to remove file $($_.Path): $($_.Exception.Message)."
                }
            }
        } elseif ($_.Status -eq 'Not available on SYSVOL') {
            try {
                $ExistingObject = Get-ADObject -Identity $_.DistinguishedName -Server $_.DomainName -ErrorAction Stop
            } catch {
                Write-Warning "Remove-GPOZaurrOrphaned - Error getting $($_.DistinguishedName) from AD error: $($_.Exception.Message)"
                $ExistingObject = $null
            }
            if ($ExistingObject -and $ExistingObject.ObjectClass -eq 'groupPolicyContainer') {
                Write-Verbose "Remove-GPOZaurrOrphaned - Removing DN: $($_.DistinguishedName) / ObjectClass: $($ExistingObject.ObjectClass)"
                try {
                    Remove-ADObject -Server $_.DomainName -Identity $_.DistinguishedName -Recursive -Confirm:$false
                } catch {
                    Write-Warning "Remove-GPOZaurrOrphaned - Failed to remove $($_.DistinguishedName) from AD error: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Remove-GPOZaurrOrphaned - DistinguishedName $($_.DistinguishedName) not found or ObjectClass is not groupPolicyContainer ($($ExistingObject.ObjectClass))"
            }
        }
    }
}