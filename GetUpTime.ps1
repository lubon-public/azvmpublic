#This script calculates and displays the system uptime in days, hours, and minutes.

$bootuptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$CurrentDate = Get-Date
$uptime = $CurrentDate - $bootuptime
$uptime | select-object Days, Hours, Minutes