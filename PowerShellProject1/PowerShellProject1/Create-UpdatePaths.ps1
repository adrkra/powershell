$PiriosPath = Get-Content "C:\Users\Adrian\Dropbox\Projects\PowerShellProject\PowerShellProject\Paths\pirios.txt"
$date = Get-Date -UFormat "%d-%m-%Y" 
$upgradePath = $PiriosPath+"\_upgrade\"+$date

function CreatePaths
{
    try
    {
        Write-Host "Start to create new paths..."
        New-Item -ItemType directory -Path $upgradePath\"modules" -Force | Out-Null 
        New-Item -ItemType directory -Path $upgradePath\"WEB" -Force | Out-Null 
        Write-Host "Status: [OK]" -ForegroundColor Green  
        Write-Host "------------------------------------------------------" 
    }
    catch{
        Write-Host $_.Exception.Message -foregroundcolor Red
        Write-Host "Status: [FAIL]" -ForegroundColor Red
        Write-Host "------------------------------------------------------"
        break
    }
}

#1
CreatePaths
