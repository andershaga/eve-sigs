<#
.SYNOPSIS
    Keeps track over scanned signatures in EVE
.INPUTS
    Clipboard
.OUTPUTS
    Signature identification compared to local database
.NOTES
    Made by: Anders Haga
    Started: 2020-26-10
#>

BEGIN
{
    # ui

    $host.UI.RawUI.WindowTitle = "EVE Signature Recorder"
    $host.UI.RawUI.BackgroundColor = 'Black'

    # functions

    function Get-EveLocalSignatures
    {
        param
        (
            [parameter(Mandatory=$true)]$Path,
            [switch]$Purge
        )

        # verify
        try 
        {
            $localFile = Get-ChildItem $path -ea stop
        }
        catch 
        {
            throw $_
        }

        # get data
        $data = Get-Content $localFile | ConvertFrom-Csv -Delimiter ';' -ea stop
        
        # ttl days
        $groups = @{

            'Combat Site'   = 3
            'Data Site'     = 1
            'Gas Site'      = 3
            'Relic Site'    = 1
            'Wormhole'      = 2
        }
        
        # purge
        if ($purge)
        {
            $purgeItems = @()
            
            # Use a default TTL of 3 days for all entries
            $defaultTTL = 3
            $time = (get-date).ToUniversalTime().AddDays(-$defaultTTL) | get-date -format yyyyMMddHHmm

            $purgeItems += $data | ? {$_.timestamp -lt $time}

            if ($purgeItems)
            {
                $data = $data | ? {$_ -notin $purgeItems}
                $data | Select-Object ID, GROUP, TIMESTAMP | ConvertTo-Csv -Delimiter ";" | out-file $localFile -force
            }
        }

        return $data
    }
    
    function Resolve-EveSignatures
    {
        param
        (
            [parameter(Mandatory=$true)]$CosmicSignature
        )

        # Check if this is the script's export format (semicolon-separated) and ignore it
        if ($CosmicSignature -match '^[A-Z]{3}-[0-9]{3};.*;.*$')
        {
            return $false
        }

        # get clipboard to object
        try
        {
            $data = ($CosmicSignature).Replace("`t",";") | convertfrom-csv -Delimiter ";" -Header "ID","TYPE","GROUP","NAME","SIGNAL","DISTANCE","TIMESTAMP"
            if ($data.id -notmatch '^[a-z]{3}-[0-9]{3}') {throw}
        }
        catch
        {
            return $false
        }

        return $data
    }
}
PROCESS
{
    $localFilePath = [System.IO.FileInfo]"$PSScriptRoot\evesigs.csv"
    
    if (!(get-content $localFilePath -ea 0))
    {
        '"ID";"GROUP";"TIMESTAMP"' | out-file $localFilePath -force
    }

    while ($true)
    {
        $localData = Get-EveLocalSignatures -Path $localFilePath -Purge
        $localData = Get-EveLocalSignatures -Path .\evesigs.csv -Purge

        clear-host
        write-host ""

        if ($clipBoard = Resolve-EveSignatures -CosmicSignature (Get-Clipboard))
        {
            $addToLocalData = @()
            
            foreach ($clip in $clipBoard)
            {
                write-host "  " -n
                if ($clip.id -in $localData.id)
                {
                    $existingClip = $localData | ? {$_.id -eq $clip.id}
                    $localDataTime = $existingClip.timestamp
                    $localDataAge = (get-date).ToUniversalTime() - (get-date -Year $localDataTime.Substring(0,4) -Month $localDataTime.Substring(4,2) -Day $localDataTime.Substring(6,2) -Hour $localDataTime.Substring(8,2) -Minute $localDataTime.Substring(10,2))
                    
                    # Check if we have new group information to update
                    if ($clip.group -and (!$existingClip.group -or $existingClip.group -eq ""))
                    {
                        write-host " " -b darkyellow -n
                        # Update existing entry with new group information
                        $clip.TIMESTAMP = $existingClip.timestamp  # Keep original timestamp
                        $addToLocalData += $clip
                    }
                    else
                    {
                        # Use green for identified signatures, red for unknown
                        if ($clip.group -or $existingClip.group)
                        {
                            write-host " " -b darkgreen -n
                        }
                        else
                        {
                            write-host " " -b darkred -n
                        }
                        $clip = $existingClip  # Use existing data for display
                    }
                    
                    # Format age as "x days x hours"
                    $ageDisplay = ""
                    if ($localDataAge.days -gt 0) { $ageDisplay += "$($localDataAge.days) day" + $(if ($localDataAge.days -ne 1) {"s"}) }
                    if ($localDataAge.days -gt 0 -and $localDataAge.hours -gt 0) { $ageDisplay += " " }
                    if ($localDataAge.hours -gt 0) { $ageDisplay += "$($localDataAge.hours) hour" + $(if ($localDataAge.hours -ne 1) {"s"}) }
                    if ($localDataAge.days -eq 0 -and $localDataAge.hours -eq 0) { $ageDisplay = "0 hours" }
                }
                else
                {
                    $localDataTime = $null
                    $ageDisplay = ""

                    if ($clip.group)
                    {
                        write-host " " -b darkyellow -n
                        $clip.TIMESTAMP = (get-date).ToUniversalTime() | get-date -format yyyyMMddHHmm
                        $addToLocalData += $clip
                    }
                    else
                    {
                        write-host " " -b darkred -n
                        # Don't save unresolved signatures - just display them
                    }
                }

                # Show ID and group/name, with age if available
                $displayInfo = $clip.id
                if ($clip.group) { $displayInfo += " ($($clip.group))" }
                elseif ($clip.name) { $displayInfo += " ($($clip.name))" }
                else { $displayInfo += " (Unknown)" }
                
                write-host " $displayInfo" -f white -n

                if ($ageDisplay)
                {
                    write-host " [$ageDisplay]" -f gray -n
                }
                
                write-host ""
            }

            if ($addToLocalData)
            {
                # Get IDs that are being updated
                $updateIds = $addToLocalData | % {$_.id}
                
                # Remove existing entries that are being updated
                $localData = $localData | ? {$_.id -notin $updateIds}
                
                # Convert to array and add the new/updated data
                $localData = @($localData) + $addToLocalData
                
                # Write all data back to file
                $localData | Select-Object ID, GROUP, TIMESTAMP | ConvertTo-Csv -Delimiter ";" | out-file $localFilePath -force
            }
        }
        else
        {
            write-host "  Unrecognizable data" -ForegroundColor red
        }
        write-host ""
        write-host "  [A] Show All [R] Register [D] Delete [X] Export [I] Import" -f darkgray
        write-host "`n   - Press any other key to reload " -f gray -n
        write-host " ($($localdata.count) sigs identified) " -f darkgray -n

        switch ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character)
        {
            'A'
            {
                clear-host
                write-host "`n  All Signatures:" -f white
                write-host ""
                
                foreach ($entry in $localData | Sort-Object ID)
                {
                    $ageDisplay = ""
                    if ($entry.timestamp)
                    {
                        $entryTime = [DateTime]::ParseExact($entry.timestamp, "yyyyMMddHHmm", $null)
                        $age = (get-date).ToUniversalTime() - $entryTime
                        if ($age.days -gt 0) { $ageDisplay += "$($age.days) day" + $(if ($age.days -ne 1) {"s"}) }
                        if ($age.days -gt 0 -and $age.hours -gt 0) { $ageDisplay += " " }
                        if ($age.hours -gt 0) { $ageDisplay += "$($age.hours) hour" + $(if ($age.hours -ne 1) {"s"}) }
                        if ($age.days -eq 0 -and $age.hours -eq 0) { $ageDisplay = "0 hours" }
                    }
                    
                    # All saved signatures have group information
                    write-host "  " -n
                    write-host " " -b darkgreen -n
                    write-host " $($entry.id) ($($entry.group)) [$ageDisplay]" -f white
                }
                
                write-host "`n  Total: $($localData.count) signatures" -f darkgray
                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
            }
            'R'
            {
                clear-host
                write-host "`n  Register manually:" -f white
                write-host "  Enter signature ID (ie: NEH-246): " -n
                if ($hostInputID = read-host)
                {
                    if ($hostInputID.Trim())
                    {
                        $hostInputID = $hostInputID.ToUpper()
                        
                        write-host "`n  Select group type:" -f white
                        write-host "  1. Combat Site" -f gray
                        write-host "  2. Data Site" -f gray
                        write-host "  3. Gas Site" -f gray
                        write-host "  4. Relic Site" -f gray
                        write-host "  5. Wormhole" -f gray
                        write-host "`n  Selection (1-5): " -f darkgray -n
                        
                        if ($groupSelection = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"))
                        {
                            $hostGroup = $null
                            
                            switch ($groupSelection.character)
                            {
                                '1' { $hostGroup = "Combat Site" }
                                '2' { $hostGroup = "Data Site" }
                                '3' { $hostGroup = "Gas Site" }
                                '4' { $hostGroup = "Relic Site" }
                                '5' { $hostGroup = "Wormhole" }
                                default
                                {
                                    write-host "`n`n  Invalid selection" -f red
                                    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                    break
                                }
                            }
                            
                            if ($hostGroup)
                            {
                                Set-Clipboard "$hostInputID`tCosmic Signature`t$hostGroup"
                                write-host "`n`n  Added to clipboard: $hostInputID - $hostGroup" -f green
                                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                            }
                        }
                    }
                }
            }
            'D'
            {
                clear-host

                write-host "`n  Delete ID (ie: NEH-246): " -n
                if ($hostInput = read-host)
                {
                    if ($hostInput.Trim())
                    {
                        # Use wildcard matching on the first characters
                        $remove = $localData | ? {$_.id -like "$($hostInput.Trim())*"}
                        
                        if ($remove.Count -eq 0)
                        {
                            write-host "`n  No match for `"$hostInput`"" -f red
                            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                        }
                        elseif ($remove.Count -eq 1)
                        {
                            # Single match - show details and confirm deletion
                            write-host ""
                            write-host "  " -n
                            write-host " " -b darkgreen -n
                            write-host " $($remove.id) ($($remove.group))" -f white
                            write-host "`n  Delete this entry? (Y/n): " -f yellow -n
                            $confirmKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
                            if ($confirmKey -ne 'n')
                            {
                                $localData = $localData | ? {$_.id -ne $remove.id}
                                $localData | Select-Object ID, GROUP, TIMESTAMP | ConvertTo-Csv -Delimiter ";" | out-file $localFilePath -force
                                write-host "`n  Entry deleted successfully" -f green
                                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                            }
                        }
                        else
                        {
                            # Multiple matches - show all matches and ask for more specific input
                            write-host ""
                            write-host "  Multiple matches found:" -f yellow
                            write-host ""
                            
                            foreach ($entry in $remove | Sort-Object ID)
                            {
                                write-host "  " -n
                                write-host " " -b darkgreen -n
                                write-host " $($entry.id) ($($entry.group))" -f white
                            }
                            
                            write-host "`n  Please enter a more specific ID: " -f yellow -n
                            if ($specificInput = read-host)
                            {
                                if ($specificInput.Trim())
                                {
                                    $specificRemove = $remove | ? {$_.id -like "$($specificInput.Trim())*"}
                                    
                                    if ($specificRemove.Count -eq 0)
                                    {
                                        write-host "`n  No match for `"$specificInput`"" -f red
                                        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                    }
                                    elseif ($specificRemove.Count -eq 1)
                                    {
                                        # Single specific match - confirm deletion
                                        write-host ""
                                        write-host "  " -n
                                        write-host " " -b darkgreen -n
                                        write-host " $($specificRemove.id) ($($specificRemove.group))" -f white
                                        write-host "`n  Delete this entry? (Y/n): " -f yellow -n
                                        $confirmKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
                                        if ($confirmKey -ne 'n')
                                        {
                                            $localData = $localData | ? {$_.id -ne $specificRemove.id}
                                            $localData | Select-Object ID, GROUP, TIMESTAMP | ConvertTo-Csv -Delimiter ";" | out-file $localFilePath -force
                                            write-host "`n  Entry deleted successfully" -f green
                                            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                        }
                                    }
                                    else
                                    {
                                        # Still multiple matches - show them again
                                        write-host ""
                                        write-host "  Multiple matches found:" -f yellow
                                        write-host ""
                                        
                                        foreach ($entry in $specificRemove | Sort-Object ID)
                                        {
                                            write-host "  " -n
                                            write-host " " -b darkgreen -n
                                            write-host " $($entry.id) ($($entry.group))" -f white
                                        }
                                        
                                        write-host "`n  Please enter a more specific ID: " -f yellow -n
                                        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                    }
                                }
                            }
                        }
                    }
                }
            }
            'X'
            {
                clear-host
                
                # Export all local data to clipboard in script format
                if ($localData.Count -gt 0)
                {
                    write-host "`n  Exporting $($localData.Count) signatures:" -f white
                    foreach ($entry in $localData | Sort-Object ID)
                    {
                        $ageDisplay = ""
                        if ($entry.timestamp)
                        {
                            $entryTime = [DateTime]::ParseExact($entry.timestamp, "yyyyMMddHHmm", $null)
                            $age = (get-date).ToUniversalTime() - $entryTime
                            if ($age.days -gt 0) { $ageDisplay += "$($age.days) day" + $(if ($age.days -ne 1) {"s"}) }
                            if ($age.days -gt 0 -and $age.hours -gt 0) { $ageDisplay += " " }
                            if ($age.hours -gt 0) { $ageDisplay += "$($age.hours) hour" + $(if ($age.hours -ne 1) {"s"}) }
                            if ($age.days -eq 0 -and $age.hours -eq 0) { $ageDisplay = "0 hours" }
                        }
                        write-host "    $($entry.id) ($($entry.group)) [$ageDisplay]" -f gray
                    }
                    
                    # Create single-line export
                    $exportString = ($localData | % {"$($_.id);$($_.group);$($_.timestamp)"}) -join " "
                    $exportString | Set-Clipboard
                    
                    write-host "`n  Exported to clipboard as single line" -f green
                    write-host "  Format: ID;GROUP;TIMESTAMP ID;GROUP;TIMESTAMP ..." -f gray
                }
                else
                {
                    write-host "`n  No data to export" -f yellow
                }
                
                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
            }
            'I'
            {
                clear-host
                
                write-host "`n  Import shared data:" -f white
                write-host "  Paste the shared data and press Enter:" -f gray
                write-host "  (Format: ID;GROUP;TIMESTAMP)" -f gray
                write-host "`n  Data: " -n
                
                if ($importData = read-host)
                {
                    if ($importData.Trim())
                    {
                        try
                        {
                            $importedCount = 0
                            $updatedCount = 0
                            $skippedCount = 0
                            
                            # Parse imported data - handle group names with spaces
                            $importLines = @()
                            $entries = $importData -split " "
                            $currentEntry = ""
                            
                            foreach ($part in $entries)
                            {
                                if ($part -match '^[A-Z]{3}-[0-9]{3};')
                                {
                                    # This is a new entry starting with a signature ID
                                    if ($currentEntry -and $currentEntry -match '^[A-Z]{3}-[0-9]{3};.*;.*$')
                                    {
                                        $importLines += $currentEntry
                                    }
                                    $currentEntry = $part
                                }
                                else
                                {
                                    # This is part of the current entry (group name or timestamp)
                                    $currentEntry += " " + $part
                                }
                            }
                            
                            # Add the last entry if it's complete
                            if ($currentEntry -and $currentEntry -match '^[A-Z]{3}-[0-9]{3};.*;.*$')
                            {
                                $importLines += $currentEntry
                            }
                            
                            write-host "`n  Parsed $($importLines.Count) valid entries" -f gray
                            
                            if ($importLines.Count -eq 0)
                            {
                                write-host "`n  No valid entries found to import" -f red
                                write-host "  Expected format: ID;GROUP;TIMESTAMP" -f gray
                                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                break
                            }
                            
                            foreach ($line in $importLines)
                            {
                                try
                                {
                                    $parts = $line.Trim() -split ';'
                                    if ($parts.Count -eq 3)
                                    {
                                        $importId = $parts[0]
                                        $importGroup = $parts[1]
                                        $importTimestamp = $parts[2]
                                        
                                        # Check if entry already exists
                                        $existingEntry = $localData | ? {$_.id -eq $importId}
                                        
                                        if ($existingEntry)
                                        {
                                            # Compare timestamps - favor the oldest
                                            $existingTime = [DateTime]::ParseExact($existingEntry.timestamp, "yyyyMMddHHmm", $null)
                                            $importTime = [DateTime]::ParseExact($importTimestamp, "yyyyMMddHHmm", $null)
                                            
                                            if ($importTime -lt $existingTime)
                                            {
                                                # Imported data is older, update existing entry
                                                $localData = $localData | ? {$_.id -ne $importId}
                                                $localData += [PSCustomObject]@{
                                                    ID = $importId
                                                    GROUP = $importGroup
                                                    TIMESTAMP = $importTimestamp
                                                }
                                                $updatedCount++
                                            }
                                            else
                                            {
                                                $skippedCount++
                                            }
                                        }
                                        else
                                        {
                                            # New entry, add it
                                            $localData += [PSCustomObject]@{
                                                ID = $importId
                                                GROUP = $importGroup
                                                TIMESTAMP = $importTimestamp
                                            }
                                            $importedCount++
                                        }
                                    }
                                }
                                catch
                                {
                                    write-host "  Error processing entry: $line" -f red
                                }
                            }
                            
                            # Save updated data
                            if ($importedCount -gt 0 -or $updatedCount -gt 0)
                            {
                                $localData | Select-Object ID, GROUP, TIMESTAMP | ConvertTo-Csv -Delimiter ";" | out-file $localFilePath -force
                                # Refresh local data to show updates immediately
                                $localData = Get-EveLocalSignatures -Path $localFilePath
                            }
                            
                            write-host "`n  Import complete:" -f green
                            write-host "  New entries: $importedCount" -f gray
                            write-host "  Updated entries: $updatedCount" -f gray
                            write-host "  Skipped entries: $skippedCount" -f gray
                        }
                        catch
                        {
                            write-host "`n  Import failed with error: $($_.Exception.Message)" -f red
                        }
                    }
                }
                
                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
            }
        }
    }
}
END
{

}
