<#
.SYNOPSIS
    Keeps track over scanned signatures in EVE
.INPUTS
    Clipboard
.OUTPUTS
    Signature identification compared to local database
.NOTES
    Made by: Nehalennia
    Started: 2020-26-10
    Updated: 2020-01-11
#>

BEGIN
{
    # ui

    $host.UI.RawUI.WindowTitle = "EVE Signature Recorder (Nehalennia)"
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

            0..(($groups.keys.count) - 1) | % {

                $group = $($groups.keys)[$_]
                $value = $($groups.values)[$_]
                $time = (get-date).AddDays(-$value) | get-date -format yyyyMMddHHmm

                $purgeItems += $data | ? {($_.group -eq $group) -and ($_.timestamp -lt $time)}
            }

            if ($purgeItems)
            {
                $data = $data | ? {$_ -notin $purgeItems}
                $data | ConvertTo-Csv -Delimiter ";" | out-file $localFile -force
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
        '"ID";"TYPE";"GROUP";"NAME";"SIGNAL";"DISTANCE";"TIMESTAMP"' | out-file $localFilePath -force
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
                    $clip = $localData | ? {$_.id -eq $clip.id}
                    $localDataTime = $clip.timestamp
                    $localDataAge = (get-date).ToUniversalTime() - (get-date -Year $localDataTime.Substring(0,4) -Month $localDataTime.Substring(4,2) -Day $localDataTime.Substring(6,2) -Hour $localDataTime.Substring(8,2) -Minute $localDataTime.Substring(10,2))
                    write-host " " -b darkgreen -n
                }
                else
                {
                    $localDataTime = $null

                    if ($clip.group)
                    {
                        write-host " " -b darkyellow -n
                        $clip.TIMESTAMP = (get-date).ToUniversalTime() | get-date -format yyyyMMddHHmm
                        $addToLocalData += $clip
                    }
                    else
                    {
                        write-host " " -b darkred -n
                    }
                }

                write-host " "$(($clip | select id,group | convertto-csv -Delimiter "`t" | select -skip 1) -replace '"','') -f white -n

                if ($localDataTime)
                {
                    write-host "`t$($localDataAge.days)d $($localDataAge.hours)h $($localDataAge.minutes)m" -f gray -n
                }
                
                write-host ""
            }

            if ($addToLocalData)
            {
                $addToLocalData | ConvertTo-Csv -Delimiter ";" | select -Skip 1 | out-file $localFilePath -Append
            }
        }
        else
        {
            write-host "  Unrecognizable data" -ForegroundColor red
        }
        write-host ""
        write-host "  [A] Show All [R] Register [V] Register from clipboard [D] Delete" -f darkgray
        write-host "`n   - Press any other key to reload " -f gray -n
        write-host " ($($localdata.count) sigs identified) " -f darkgray -n

        switch ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character)
        {
            'A'
            {
                clear-host
                $localData | sort id | ft
                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
            }
            'R'
            {
                clear-host
                write-host "`n  Register manually (ie: NEH-246,Combat Site): " -n
                if ($hostInput = read-host)
                {
                    if ($hostInput.Trim())
                    {
                        $hostInputID = $hostInput.Split(',')[0].ToUpper()
                        $hostInputGroup = $hostInput.Split(',')[1]

                        if ($hostInputGroup.split(' ').count -lt 2)
                        {
                            $hostGroup = $hostInputGroup.Split(' ')[0].Substring(0,1).ToUpper() + $hostInputGroup.Split(' ')[0].Substring(1,(($hostInputGroup.Split(' ')[0].Length) -1 ))
                        }
                        else
                        {
                            $hostGroup = $hostInputGroup.Split(' ')[0].Substring(0,1).ToUpper() + $hostInputGroup.Split(' ')[0].Substring(1,(($hostInputGroup.Split(' ')[0].Length) -1 )) + " " +`
                                        $hostInputGroup.Split(' ')[1].Substring(0,1).ToUpper() + $hostInputGroup.Split(' ')[1].Substring(1,(($hostInputGroup.Split(' ')[1].Length) -1 ))
                        }
                        
                        Set-Clipboard "$hostInputID`tCosmic Signature`t$hostGroup"
                    }
                }
            }
            'V'
            {
                clear-host

                write-host ""
                $n = $null

                if ($UnknownSigs = ($clipboard | ? {!$_.group -and ($_.id -notin $localdata.id)}))
                {
                    foreach ($sig in $UnknownSigs)
                    {
                        $n++

                        write-host "  $n. $($sig.id)`t$($sig.name)"
                    }

                    write-host "`n  Selection: " -f darkgray -n

                    if ($selectNumber =  $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"))
                    {
                        if (1..$UnknownSigs.count -match $selectNumber.character)
                        {
                            $SelectedToImport = $UnknownSigs[$($selectNumber.character.ToString() - 1)]
                            write-host "$($selectNumber.character)`n`n [C]ombat, [D]ata, [G]as, [R]elic, [W]ormhole " -f darkgray -n
                            if ($selectSiteKey =  $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"))
                            {
                                $selectSite = $null

                                switch ($selectSiteKey.character)
                                {
                                    'W'{$selectSite = "Wormhole"}
                                    'D'{$selectSite = "Data Site"}
                                    'R'{$selectSite = "Relic Site"}
                                    'G'{$selectSite = "Gas Site"}
                                    'C'{$selectSite = "Combat Site"}
                                    default
                                    {
                                        write-host "`n`n Invalid selection " -f red -n
                                        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                                    }
                                }

                                if ($selectSite)
                                {
                                    ($clipBoard | ? {$_.id -eq $SelectedToImport.id}).group = $selectSite
                                    Set-Clipboard $($clipBoard | % {"$($_.id)`t$($_.type)`t$($_.group)`t$($_.name)`t$($_.signal)`t$($_.distance)"})
                                }
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
                    if ($remove = $localData | ? {$_.id -like "*$hostInput*"})
                    {
                        write-host ""
                        $remove.id | % {write-host "  "$_ -f darkgray}
                        write-host "`n  Delete $($remove.count) entries? (Yes): " -f yellow -n
                        switch (read-host)
                        {
                            'yes'
                            {
                                $localData | ? {$_.id -ne $hostInput} | ConvertTo-Csv -Delimiter ";" | out-file $localFilePath -force
                            }
                        }
                    }
                    else
                    {
                        write-host "`n No match for `"$hostInput`""
                        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
                    }
                }
            }
        }
    }
}
END
{

}




