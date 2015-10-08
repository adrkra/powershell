#Lista serwerów CPD i usług do monitorowania
$ServerList = Get-Content "C:\Scripts\Stuff\systems.txt" 
$ServicesList = Get-Content "C:\Scripts\Stuff\proces.txt"  

#Lista serwerów IVR i usług do monitorowania
$IvrServerList = Get-Content "C:\Scripts\Stuff\Ivrsystems.txt" 
$IvrservicesList = Get-Content "C:\Scripts\Stuff\Ivrproces.txt" 

#modules 
$serviceslist196 = Get-Content "C:\Scripts\Stuff\modules196.txt"
$serviceslist197 = Get-Content "C:\Scripts\Stuff\modules197.txt" 

#Lista hostów do sprawdzeia do raportu zajętości dysków
#$computers = Get-Content "C:\Scripts\Stuff\systemsdisk.txt"

#Lista serwerów Batabase i usług do monitorowania
#$DBserverList = Get-Content "C:\Scripts\Stuff\DBsystems.txt" 
#$DBservicesList = Get-Content "C:\Scripts\Stuff\DBproces.txt" 

#Ustawienia serwera SMTP
$SMTPServer = "poczta.tpe.corp"
$SMTPPort = "25"
$MailUsername = "td-exu-contat"
$MailPassword = "V7uDzXQeYfPH510jgADC"
$who = "contactis@tauron-dystrybucja.pl"
$to = "support@pirios.com" 
$titleDate = get-date -uformat "%m-%d-%Y - %A"
$subject = "Daily Tauron Raport $titleDate"

#Zakresy powiadomien dot. zajętości dysków
$percentOk = 100;
$percentCritical = 10;
$percentWarning = 20;

#Zakresy powiadomien dot. mem i proc
$percentWarningelse = 80.0;

#Ustawienia do raportu zajętości dysków
$DiskReportPath = "C:\Scripts\ContentForMail";
$DiskReportName = "DiskSpaceRpt_$(get-date -format ssmmHHddMMyyyy).html";
$diskReport = $DiskReportPath + $DiskReportName

#Kolory komorek do raportu zajętości dysków
$redColor = "#FF0000"
$orangeColor = "#FBB917"
$whiteColor = "#FFFFFF"
$greenColor = "Aquamarine"
$normalColor = 'GainsBoro'

#Inne
$report = "C:\Scripts\ContentForMail\DailyServices.htm"  
$ServiceHeaderCPD = Get-Content "C:\Scripts\Stuff\ServiceHeaderCPD.htm" 
$ServiceHeaderIvr = Get-Content "C:\Scripts\Stuff\ServiceHeaderIvr.htm" 
#$ServiceHeaderDB = Get-Content "C:\Scripts\Stuff\ServiceHeaderDB" 
$ServerHeader = Get-Content "C:\Scripts\Stuff\ServerHeader.htm" 
$IvrHeader = Get-Content "C:\Scripts\Stuff\IvrHeader.htm" 
$ServerDiskHeader = Get-Content "C:\Scripts\Stuff\ServerDiskHeader.htm" 
$IvrDiskHeader = Get-Content "C:\Scripts\Stuff\IvrDiskHeader.htm" 
$now = Get-Date  
$MaxConnections = 5000 #próg dla koloru tcp/udp

#Creds
$password = "Tauron1212" | ConvertTo-SecureString -asPlainText -Force
$username = "tpe\x-akrawczyk" 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

function Check-ServiceReport 
{  
    $reportcheck = Test-Path $report
    if ($reportcheck)
    {
        Remove-Item $report 
    }
    else
    {
        New-Item $report -type file 
    }
}

function Check-ServerStatus ($computers)
{
  foreach($computer in $computers)
	{	
Write-Host $computer
$serverName = Invoke-Command -Computername $computer -ScriptBlock {hostname} -Credential $credential
$proc = Get-WmiObject -computername $computer win32_processor | Measure-Object -property LoadPercentage -Average | Select Average 
$procload = $proc.Average
$mem = Get-WmiObject -Class win32_operatingsystem -computername $computer | Select-Object @{Name = "MemoryUsage"; Expression = {“{0:N2}” -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) }} 
$memload = $mem.MemoryUsage
$ping = gwmi win32_pingstatus -f "Address = '$computer'" 
 if($ping.statuscode -eq 0) 
 { 
    $wmi = Get-WmiObject -ComputerName $computer -Query "SELECT LastBootUpTime FROM Win32_OperatingSystem"            
    $boottime = $wmi.ConvertToDateTime($wmi.LastBootUpTime) 
    $uptime = (Get-Date) - $boottime
    $DisplayUptime = "" + $Uptime.Days + "d " + $Uptime.Hours + "h " + $Uptime.Minutes + "m" 

    Write-Host $DisplayUptime
 } 
 else 
 { 
    $boottime = "offline"
    $DisplayUptime = ''
 } 
$TcpConnestions = Invoke-Command -Computername $computer -ScriptBlock {(netstat -an | ? {($_ -match '^  TCP')}).Count} -Credential $credential
$UdpConnestions = Invoke-Command -Computername $computer -ScriptBlock {(netstat -an | ? {($_ -match '^  UDP')}).Count} -Credential $credential
$TotalConnections = $TcpConnestions + $UdpConnestions

$connectionColor = $GreenColor
$memColor = $normalColor
$procColor = $normalColor

if($TotalConnections -gt $MaxConnections)
{
$connectionColor = $redColor 
}
if($procload -ge $percentWarningelse)       
{ 
$procColor = $orangeColor  
}
Write-Host Uzycie pamieci to $memload
if($memload > $percentWarningelse)       
{ 
$memColor = $orangeColor
}
$dataRow = "
				        <tr bgcolor= 'GainsBoro'font face='tahoma'>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$computer</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$serverName</b></td>
                        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$boottime</b></td>
                        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$DisplayUptime</b></td>
				        <td width='5%'  bgcolor= '$procColor' align='center'><b>$procload</b></td>
                        <td width='5%'  bgcolor= '$memColor' align='center'><b>$memload</b></td>
                        <td width='5%'  bgcolor= 'GainsBoro' align='center'><b>$TcpConnestions</b></td>
                        <td width='5%'  bgcolor= 'GainsBoro' align='center'><b>$UdpConnestions</b></td>
                        <td width='5%'  bgcolor= '$connectionColor' align='center'><b>$TotalConnections</b></td>
				        </tr>"
				Add-Content $report $dataRow			
	}
}

function Check-ServiceStatus ($computers, $serviceslist) 
{ 
foreach ($machineName in $computers)  
		{  
        if ($machineName -eq '10.170.10.196')
        {
        $serviceslist = $serviceslist196
        }
        if ($machineName -eq '10.170.10.197')
        {
        $serviceslist = $serviceslist197
        }
		foreach ($service in $serviceslist) 
		{ 
write-host $service $machineName
$serviceStatus = Get-Process $service  -ComputerName $machineName | Select-Object -First 1
$svcName = $serviceStatus.name  
$ping = gwmi win32_pingstatus -f "Address = '$machineName'" 
 if($ping.statuscode -eq 0) {
    $test = 'ok'
 } 
 else {
$test = 'notok'
 }

			if ($serviceStatus -and $test -eq 'ok')
			{ 
                
                $mem = [Math]::Round($serviceStatus.PrivateMemorySize64 / 1mb, 2) 
                if($mem -gt 2000)
                {
                    $memColor = $orangeColor
                }
                else 
                {
                    $memColor = "Aquamarine"
                }
				Write-Host $machineName `t $serviceStatus.name `t $serviceStatus.status -ForegroundColor Green  
				
				$svcState = $serviceStatus.status  
                $processTime = gwmi win32_process -computername $machineName| ? { $_.name -eq $service+'.exe' } | % { $_.ConvertToDateTime( $_.CreationDate )}     
                
                    $Processuptime = (Get-Date) - $processTime
    $DisplayprocessTime = "" + $Processuptime.Days + "d " + $Processuptime.Hours + "h " + $Processuptime.Minutes + "m" 

    Write-Host Proces $service działa od $DisplayUptime
                
                Add-Content $report "<tr>"  
				Add-Content $report "<td bgcolor= 'GainsBoro' align=center><B>$machineName</B></td>"  
				Add-Content $report "<td bgcolor= 'GainsBoro' align=center><B>$svcName</B></td>" 
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$processTime</B></td>"
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$DisplayprocessTime</B></td>"
                Add-Content $report "<td bgcolor= '$memColor' align=center>  <B>$mem</B></td>"  
                Add-Content $report "<td bgcolor= 'Aquamarine' align=center><B>Running</B></td>"   
				Add-Content $report "</tr>" 
                Write-Host 'Uruchomiony od: '$processTime
                Write-Host 'Wykorzystuje' $mem 'MB pamięci'
			} 
			else  
            {  
                Add-Content $report "<tr>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>$machineName</td>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>$service </td>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B></B></td>"
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B></B></td>" 
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center> <B>0</B></td>"  
                Add-Content $report "<td bgcolor= 'Red' align=center><B>Not Running</B></td>"  
                Add-Content $report "</tr>" 
			}              
		}  
	}
}

#Funkcja na potrzeby monitorowania serwera strike pod sql
function Check-ServiceStatusDB ($computers, $serviceslist) 
{ 
	foreach ($machineName in $computers)  
		{  
		foreach ($service in $serviceslist) 
		{ 
write-host $service $machineName
			$serviceStatus = Get-Process $service  -ComputerName $machineName
            $svcName = $serviceStatus.name  
			if ($serviceStatus)
			{ 
                
                $mem = [Math]::Round($serviceStatus.PrivateMemorySize64 / 1mb, 2) 
                if($mem -gt 8000)
                {
                    $memColor = $orangeColor
                }
                else 
                {
                    $memColor = "Aquamarine"
                }
				Write-Host $machineName `t $serviceStatus.name `t $serviceStatus.status -ForegroundColor Green  
				
				$svcState = $serviceStatus.status  
                $processTime = Get-WmiObject win32_process -computername $machineName| ? { $_.name -eq $service+'.exe' } | % { $_.ConvertToDateTime( $_.CreationDate )}     
				Add-Content $report "<tr>"  
				Add-Content $report "<td bgcolor= 'GainsBoro' align=center><B>$machineName</B></td>"  
				Add-Content $report "<td bgcolor= 'GainsBoro' align=center><B>$svcName</B></td>" 
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$processTime</B></td>"
                Add-Content $report "<td bgcolor= '$memColor' align=center>  <B>$mem</B></td>"  
                Add-Content $report "<td bgcolor= 'Aquamarine' align=center><B>Running</B></td>"   
				Add-Content $report "</tr>" 
                Write-Host 'Uruchomiony od: '$processTime
                Write-Host 'Wykorzystuje' $mem 'MB pamięci'
			} 
			else  
            {  
                Add-Content $report "<tr>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>$machineName</td>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>$service </td>"  
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$processTime</B></td>" 
                Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>0</B></td>"  
                Add-Content $report "<td bgcolor= 'Red' align=center><B>Not Running</B></td>"  
                Add-Content $report "</tr>" 
			}              
		}  
	}
}

function Close-HTMLtable
{
	Add-content $report "</table>"  
	Add-Content $report "</body>"  
	Add-Content $report "</html>"  
} 
 
function Check-DiskStatus ($computers)
{
  foreach($computer in $computers)
	{	
		$disks = Get-WmiObject -ComputerName $computer -Class Win32_LogicalDisk -Filter "DriveType = 3"
		$computer = $computer.toupper()
		foreach($disk in $disks)
		{        
			$deviceID = $disk.DeviceID;
			$volName = $disk.VolumeName;
			[float]$size = $disk.Size;
			[float]$freespace = $disk.FreeSpace; 
			$percentFree = [Math]::Round(($freespace / $size) * 100, 2);
			$sizeGB = [Math]::Round($size / 1073741824, 2);
			$freeSpaceGB = [Math]::Round($freespace / 1073741824, 2);
			$usedSpaceGB = [Math]::Round($sizeGB - $freeSpaceGB / 1, 2);
			if($percentFree -lt $percentCritical)       
			{ 
				$color = $redColor 
				$dataRow = "
				        <tr bgcolor= 'GainsBoro'font face='tahoma'>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$computer</b></td>
				        <td width='5%'  bgcolor= 'GainsBoro' align='center'><b>$deviceID</b></td>
				        <td width='15%'  bgcolor= 'GainsBoro' align='center'><b>$volName</b></td>
				        <td width='10%'   bgcolor= 'GainsBoro' align='center'><b>$sizeGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$usedSpaceGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$freeSpaceGB</b></td>
				        <td width='5%' bgcolor=`'$color`' align='center'><b>$percentFree</b></td>
				        </tr>"
				Add-Content $report $dataRow;
				Write-Host -ForegroundColor White "$computer $deviceID percentage free space = $percentFree";
			}
				if($percentFree -gt $percentCritical -and $percentFree -lt $percentWarning) 
				{ 
					$color = $orangeColor 
					$dataRow = "
				        <tr bgcolor= 'GainsBoro'font face='tahoma'>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$computer</b></td>
				        <td width='5%'  bgcolor= 'GainsBoro' align='center'><b>$deviceID</b></td>
				        <td width='15%'  bgcolor= 'GainsBoro' align='center'><b>$volName</b></td>
				        <td width='10%'   bgcolor= 'GainsBoro' align='center'><b>$sizeGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$usedSpaceGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$freeSpaceGB</b></td>
				        <td width='5%' bgcolor=`'$color`' align='center'><b>$percentFree</b></td>
				        </tr>"
					Add-Content $report $dataRow;
					Write-Host -ForegroundColor White "$computer $deviceID percentage free space = $percentFree";
				}
					if($percentFree -gt $percentWarning -and $percentFree -lt $percentOk) 
					{ 
						$color = $greenColor 
						$dataRow = "
				        <tr bgcolor= 'GainsBoro'font face='tahoma'>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$computer</b></td>
				        <td width='5%'  bgcolor= 'GainsBoro' align='center'><b>$deviceID</b></td>
				        <td width='15%'  bgcolor= 'GainsBoro' align='center'><b>$volName</b></td>
				        <td width='10%'   bgcolor= 'GainsBoro' align='center'><b>$sizeGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$usedSpaceGB</b></td>
				        <td width='10%'  bgcolor= 'GainsBoro' align='center'><b>$freeSpaceGB</b></td>
				        <td width='5%' bgcolor=`'$color`' align='center'><b>$percentFree</b></td>
				        </tr>"
						Add-Content $report $dataRow;
						Write-Host -ForegroundColor White "$computer $deviceID percentage free space = $percentFree";
					}
			$i++		
		}
	}
}

function Add-Legenda
{
	$tableDescription = "
		</table><br><table width='60%'>
		<tr bgcolor='White'>
		<td width='20%' align='center' bgcolor='$greenColor'>Stan Normalny - ponad 20% wolnego miejsca</td>
		<td width='20%' align='center' bgcolor='$orangeColor'>Stan Ostrzegawczy - poniżej 20% wolnego miejsca</td>
		<td width='20%' align='center' bgcolor='$redColor'>Stan Krytyczny - poniżej 10% wolnego miejsca</td>
		</tr>"
	Add-Content $report $tableDescription
	Add-Content $report "</body></html>"
}

function Send-Raport
{
	$body = Get-Content "C:\Scripts\ContentForMail\DailyServices.htm"  
	$message = New-Object System.Net.Mail.MailMessage
	$message.subject = $subject
	$message.body = $body
	$message.IsBodyHTML = $true
	$message.to.add($to)
	#$message.cc.add($cc)
	$message.from = $who
	#$message.attachments.add($attachment)
	$smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
	#$smtp.EnableSSL = $true
	$smtp.Credentials = New-Object System.Net.NetworkCredential($MailUsername, $MailPassword);
	$smtp.send($message)
}

function Add-DiskRaport
# Skleja raport zajętości dysków z raportem serwisów
{
	$disks = Get-Content -Path $diskReport
	Add-Content $report $disks
}
#1
Check-ServiceReport 
#2
Add-Content $report $ServiceHeaderCPD
Check-ServiceStatus $ServerList $ServicesList
Close-HTMLtable
#3
Add-Content $report $ServiceHeaderIvr
Check-ServiceStatus $IvrServerList $IvrServicesList
Close-HTMLtable
#4
Add-Content $report $ServerHeader
Check-ServerStatus $ServerList
Close-HTMLtable
#5
Add-Content $report $IvrHeader
Check-ServerStatus $IvrServerList
Close-HTMLtable
#6
Add-Content $report $ServerDiskHeader
Check-DiskStatus $ServerList
Close-HTMLtable
#7
Add-Content $report $IvrDiskHeader
Check-DiskStatus $IvrServerList
#8
Add-Legenda
#9
#Add-DiskRaport
#10
Send-Raport