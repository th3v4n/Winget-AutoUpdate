#Function to get the Domain/Local Policies (GPO)

Function Get-Policies {
    #Get WAU Policies and set the Configurations Registry Accordingly
    $WAUPolicies = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Romanitho\Winget-AutoUpdate" -ErrorAction SilentlyContinue
    if ($WAUPolicies) {
        if ($($WAUPolicies.WAU_ActivateGPOManagement -eq 1)) {
            $ChangedSettings = 0

            #If WAU Policies detected, replace default conf by ones from Policies
            $WAUPolicies.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                if ($($WAUPolicies.($_.Name)) -ne $($WAUConfig.($_.Name))) {
                    $WAUConfig.PSObject.Properties.add($_)
                    $ChangedSettings++
                }
            }

            if ($WAUConfig.WAU_UserContext -eq 1) {
                # Settings for the scheduled task in User context
                $taskAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$($WAUConfig.InstallLocation)\Invisible.vbs`" `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"`"`"$($WAUConfig.InstallLocation)\winget-upgrade.ps1`"`""
                $taskUserPrincipal = New-ScheduledTaskPrincipal -GroupId S-1-5-11
                $taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 03:00:00

                # Set up the task for user apps
                $task = New-ScheduledTask -Action $taskAction -Principal $taskUserPrincipal -Settings $taskSettings
                Register-ScheduledTask -TaskName 'Winget-AutoUpdate-UserContext' -InputObject $task -Force

                $ChangedSettings++
            }
            else {
                Get-ScheduledTask -TaskName "Winget-AutoUpdate-UserContext" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$False
            }

            if ($WAUConfig.WAU_DesktopShortcut -eq 1) {
                Add-Shortcut "wscript.exe" "${env:Public}\Desktop\WAU - Check for updated Apps.lnk" "`"$($WAUConfig.InstallLocation)\Invisible.vbs`" `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"`"`"$($WAUConfig.InstallLocation)\user-run.ps1`"`"" "${env:SystemRoot}\System32\shell32.dll,-16739" "Manual start of Winget-AutoUpdate (WAU)..."

                $ChangedSettings++
            }
            else {
                Remove-Item -Path "${env:Public}\Desktop\WAU - Check for updated Apps.lnk" -Force | Out-Null
            }

            if ($WAUConfig.WAU_StartMenuShortcut -eq 1) {
                if (!(Test-Path "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)")) {
                    New-Item -ItemType Directory -Force -Path "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)" | Out-Null
                }
                Add-Shortcut "wscript.exe" "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Check for updated Apps.lnk" "`"$($WAUConfig.InstallLocation)\Invisible.vbs`" `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"`"`"$($WAUConfig.InstallLocation)\user-run.ps1`"`"" "${env:SystemRoot}\System32\shell32.dll,-16739" "Manual start of Winget-AutoUpdate (WAU)..."
                Add-Shortcut "wscript.exe" "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Open logs.lnk" "`"$($WAUConfig.InstallLocation)\Invisible.vbs`" `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"`"`"$($WAUConfig.InstallLocation)\user-run.ps1`" -Logs`"" "${env:SystemRoot}\System32\shell32.dll,-16763" "Open existing WAU logs..."
                Add-Shortcut "wscript.exe" "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Web Help.lnk" "`"$($WAUConfig.InstallLocation)\Invisible.vbs`" `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"`"`"$($WAUConfig.InstallLocation)\user-run.ps1`" -Help`"" "${env:SystemRoot}\System32\shell32.dll,-24" "Help for WAU..."

                $ChangedSettings++
            }
            else {
                Remove-Item -Path "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)" -Recurse -Force | Out-Null
            }
        }
    }
    Return $($WAUPolicies.WAU_ActivateGPOManagement), $ChangedSettings
}
