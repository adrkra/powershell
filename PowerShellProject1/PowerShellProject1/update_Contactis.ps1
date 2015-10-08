$WebPath = Get-Content "C:\Users\Adrian\Dropbox\Projects\PowerShellProject\PowerShellProject\Paths\web.txt"
$ModulesPath = Get-Content "C:\Users\Adrian\Dropbox\Projects\PowerShellProject\PowerShellProject\Paths\modules.txt"
$PiriosPath = Get-Content "C:\Users\Adrian\Dropbox\Projects\PowerShellProject\PowerShellProject\Paths\pirios.txt"
$date = Get-Date -UFormat "%d-%m-%Y" 
$backupPath = $PiriosPath+"_backup\"+$date
$upgradePath = $PiriosPath+"_upgrade\"+$date

#Copy
$exclude = ('log','SoWave','*.log')
$UpdateExclude = ( '*.config','*.cfg')

function Test-Administrator  
{  
	Write-Host "Administrator startus checking.."
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if ($isAdmin)
    {
        Write-Host "Status: [OK]" -foregroundcolor Green
        Write-Host "------------------------------------------------------"
    }
    else
    {
        Write-Host "Status: [FAIL]" -foregroundcolor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

function Stop-WatchDog
{
    Try
    {
        $wd = Get-Service -Name Watchdog -ErrorAction silentlycontinue
        if ($wd.status -eq "Running")
        {
			Write-Host "1.Stopping WatchDog..." 
			Stop-Service Watchdog
			Write-Host "Status: [OK]" -ForegroundColor Green
			Write-Host "------------------------------------------------------"
        }
		else
		{
			Write-Host "No running WatchDog found so leave it like it is..." 
		}
    }
    Catch
    {
        Write-Host $_.Exception.Message -foregroundcolor Red
        Write-Host "Status: [FAIL]" -ForegroundColor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

function Start-WatchDog
{
    Try
    {
        $wd = Get-Service -Name Watchdog -ErrorAction silentlycontinue
        if ($wd.status -eq "Stopped")
        {
			Write-Host "1.Starting WatchDog..." 
			Start-Service Watchdog
			Write-Host "Status: [OK]" -ForegroundColor Green
			Write-Host "------------------------------------------------------"
        }
        else
		{
			Write-Host "No running WatchDog found so leave it like it is..." 
		}
    }
    Catch
    {
        Write-Host $_.Exception.Message -foregroundcolor Red
        Write-Host "Status: [FAIL]" -ForegroundColor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

function Test-BackupPath
{
    Write-Host "BackupPath preaparing and checking..."
    if(Test-Path $backupPath) 
    { 
        Write-Host $backupPath
        Write-Host "Status: [OK]" -ForegroundColor Green
    }
    else
    { 
        Write-Host "Need to create backup paths..."
        New-Item -ItemType directory -Path $backupPath\"Modules" -Force | Out-Null 
        New-Item -ItemType directory -Path $backupPath\"WEB" -Force | Out-Null
        Try
        {
            if(Test-Path $backupPath)
            {
				Write-Host "Status: [OK]" -ForegroundColor Green
            }

        }
        Catch
        {
			Write-Host $_.Exception.Message -foregroundcolor Red
			Write-Host "Status: [FAIL]" -ForegroundColor Red
			Write-Host "------------------------------------------------------"
			break
        }
    }
}

function Test-UpgradePath
{
    if(Test-Path $upgradePath) 
    { 
        Write-Host $upgradePath
        Write-Host "Status: [OK]" -ForegroundColor Green
        Write-Host "------------------------------------------------------"
    }
    else
    { 
        Write-Host $upgradePath 
        Write-Host "Status: [FAIL]" -ForegroundColor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

function Backup-Env
{
    try
    {
		if(Test-Path $ModulesPath)
		{
			Write-Host "modules backup.."
			Copy-Item $ModulesPath\* -Destination $backupPath\Modules -exclude $exclude -recurse -Force
			Write-Host "Status: [OK]" -ForegroundColor Green  
			Write-Host "------------------------------------------------------" 
		}
		if(Test-Path $WebPath)
		{
			Write-Host "WEB backup.."
			Copy-Item $WebPath\* -Destination $backupPath\WEB -exclude $exclude -recurse -Force
			Write-Host "Status: [OK]" -ForegroundColor Green  
			Write-Host "------------------------------------------------------" 
		}
    }
    catch
	{
        Write-Host $_.Exception.Message -foregroundcolor Red
        Write-Host "Status: [FAIL]" -ForegroundColor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

function Update-Modules 
{
	try
	{
		$arrayInstalled = New-Object System.Collections.ArrayList
		$arrayFailed = New-Object System.Collections.ArrayList
		$ModulesToUpdate = Get-ChildItem $UpgradePath\Modules\
		if($ModulesToUpdate)
		{
			Write-Host "------------------------------------------------------" -ForegroundColor DarkRed

			foreach ($Module in $ModulesToUpdate)
			{
				Write-Host "Czy $Module jest w $ModulesPath$Module"
				if(Test-Path $ModulesPath$Module)
				#update
				{
					Write-Host "Folder z $Module jest w lokalizacji docelowej więc wykonuje update"
					try
					{
						$serviceToStop = get-service | Where-Object { $_.name -like "*$Module*" } #bo nie ma konsekwencji w nazewnictwie
						Write-Host Szukam serwisu o nazwie: $serviceToStop.name i zatrzymuje go
						Stop-Service -Name $serviceToStop.name
						Start-Sleep -s 5
						Write-Host "Podmieniam usługe $Module"  
						Remove-Item -Path $UpgradePath\Modules\$Module\* -Include $UpdateExclude #usuwam pliki konfiguracyjne
						Copy-Item $UpgradePath\Modules\$Module -Destination $ModulesPath -exclude $UpdateExclude -recurse -Force
						Write-Host "Zakończyłem wykonywanie update $Module, dodaje do listy"
						$arrayInstalled.Add($module)
						Write-Host "Uruchamiam ponownie $Module"
						Start-Service -Name $serviceToStop.name
						Write-Host "------------------------------------------------------" -ForegroundColor DarkRed
					}
					catch
					{
						Write-Host $module nie zostanie zaktualizowany ze względu na // $_.exception.message // -f Yellow
						$arrayFailed.Add($module)
					}
				
				}
				else
				#install
				{
					$modulePath = "$UpgradePath\Modules\$module\"
					Write-Host "Folder z $Module nie jest w lokalizacji docelowej więc wykonuje install"
					try
					{
						Copy-Item $modulePath -Destination $ModulesPath -recurse -Force
						$moduleExe = Get-ChildItem -Path $ModulesPath$module -Include *.exe -Recurs -Exclude *host*
						& $moduleExe -i
						Write-Host  "$module został zainstalowany, dopisuje do listy"
						$arrayInstalled.Add($module)
						Write-Host "------------------------------------------------------" -ForegroundColor DarkRed
					}
					catch
					{
						Write-Host $module nie zostanie zainstalowany ze względu na // $_.exception.message // -f Yellow
						$arrayFailed.Add($module)
					}
				}
			}
			if($arrayInstalled)
			{
				Write-Host Lista poprawnie zainstalowanych/zaktualizowanych modułów 
				foreach ($item in $arrayInstalled) 
				{
					Write-Host $item -f Green 
				}
			}
			if($arrayFailed)
			{
				Write-Host Lista NIE zainstalowanych/zaktualizowanych modułów
				foreach ($item in $arrayFailed) 
				{
					Write-Host $item -f Red
				}
			}	
		}	
	}
	catch
	{
		Write-Host $_.exception.message
	}
}

function WebUpdate
{
	if(Test-Path -Path $upgradePath\WEB\*)
	{
		try
		{
			Write-Host "WEB need update so its gonna be easier..."
			Write-Host "Just replace core of WEB..."
			Copy-Item $UpgradePath\WEB\* -Destination $WebPath -exclude $exclude -recurse -Force
			Write-Host "Status: [OK]" -ForegroundColor Green  
			Write-Host "------------------------------------------------------" 
		}
		catch
		{
			Write-Host $_.Exception.Message -foregroundcolor Red
			Write-Host "Status: [FAIL]" -ForegroundColor Red
			Write-Host "------------------------------------------------------"
			break
		}
	}
	else
	{
		Write-Host "No need to update WEB"
	}
}

Write-Host "======================================================"
Write-Host "System check and backup procedure started..." -foregroundcolor yellow
Write-Host "------------------------------------------------------"

#1
Test-Administrator
#2
Test-BackupPath
Test-UpgradePath
#3
Backup-Env

Write-Host "======================================================"
Write-Host "System update procedure started..." -foregroundcolor yellow
Write-Host "------------------------------------------------------"

#4
Stop-WatchDog
Start-Sleep -s 2
Update-Modules
Start-WatchDog
WebUpdate

#END
Write-Host "======================================================"
Write-Host "Done." -ForegroundColor Green
