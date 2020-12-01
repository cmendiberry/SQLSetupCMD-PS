[string]$usuario = Read-Host -Prompt "Ingrese el nombre de usuario"
$passdo = Read-Host -Prompt "Ingrese la contraseña del usuario" -AsSecureString
$credo = New-Object -TypeName System.Management.Automation.PSCredential ($usuario, $passdo)

$SqlInstance = 'SQLTestDBA'

Invoke-Command -ComputerName $SqlINstance -Credential $credo -ScriptBlock{ `
New-Item -Path 'E:\BDs' -ItemType "directory" 
New-Item -Path 'E:\Backups' -ItemType "directory"
New-Item -Path 'E:\Backups\Diario' -ItemType "directory"
New-Item -Path 'E:\Tempdb' -ItemType "directory"

New-SmbShare -Name  "Diario" -Path "E:\Backups\Diario" -FullAccess "do\bkpsuser"

New-NetFirewallRule -DisplayName "AllowSQLConn" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow} 
Write-Host "listo"

#Configuracion del INI
$IniFile = Get-IniContent -FilePath "X:\InisSQL\ConfigurationFile.ini"

$IniFile.OPTIONS.SQLUSERDBDIR    = '"E:\BDs"'

$IniFile.OPTIONS.SQLBACKUPDIR    = '"E:\Backups"'

$IniFile.OPTIONS.SQLUSERDBLOGDIR = '"E:\BDs"'

$IniFile.OPTIONS.SQLTEMPDBDIR    = '"E:\TempDB"'

$IniFile | Out-IniFile -FilePath "X:\InisSQL\Resultado.ini" -Force
New-PSDrive -Name SQLremoto -PSProvider FileSystem -Root "\\SQLTestDBA\e$" -Credential $credo

Copy-Item -Path "X:\InisSQL\Resultado.ini" -Destination "sqlremoto:"

#Instalación en el servidor
$ArgumentList =  @()
$ArgumentList += '/PID="Licencia"'
$ArgumentList += '/SAPWD="Escribir una contraseña"'
$ArgumentList += '/SQLSYSADMINACCOUNTS="dominio\cuentasysadmin"'
$ArgumentList += '/SQLSVCPASSWORD="**********"'
$ArgumentList += '/AGTSVCPASSWORD="*********"'
$ArgumentList += '/ConfigurationFile="E:\Resultado.ini"'
$ArgumentList += '/IAcceptSqlServerLicenseTerms'
Start-Process  -FilePath "d:\setup.exe" -ArgumentList $ArgumentList -Wait
#
                                            
Set-DbaSpn -SPN MSSQLSvc/SQLTestDBA.do.scba.gov.ar -ServiceAccount dominio\cuentaServicioSQL -Credential $credo
Get-DbaSpn -ComputerName $SqlInstance -Credential $credo



$pass = Read-Host "Ingrese contraseña de dominio\cuentasysadmin" -AsSecureString
$credential = New-Object -TypeName System.Management.Automation.PSCredential ('dominio\cuentasysadmin', $pass)

$sqluser = = Read-Host "Ingrese nombre usuario sql"
$securePassword = Read-Host "Input password" -AsSecureString
New-DbaLogin -SqlInstance $SqlInstance -SqlCredential $credential -Login $sqluser -SecurePassword $securePassword -Force
Invoke-DbaQuery  -SqlInstance $SqlInstance -SqlCredential $credential -File "X:\InstalacionSqlServer\HandlingSA.sql" 
$credusersql = New-Object -TypeName System.Management.Automation.PSCredential ($usersql, $securePassword)


Set-DbaSpConfigure -SqlInstance $SqlInstance -SqlCredential $credential -Name 'backup compression default' -Value 1
Get-DbaSpConfigure -SqlInstance $SqlInstance -SqlCredential $credential -Name 'backup compression default' | Select-Object displayName, RunningValue |Format-Table

Invoke-DbaQuery  -SqlInstance $SqlInstance -SqlCredential $credential -File "X:\InstalacionSQLServer\PMSolucionParametrizada.sql"
Invoke-DbaQuery  -SqlInstance $SqlInstance -SqlCredential $creddbascba -Query "Select name from sys.procedures"

Invoke-DbaQuery  -SqlInstance $SqlInstance -SqlCredential $creddbascba -File "X:\InstalacionSQLServer\AIBDDatabaseMailYOperadorConfiguracion.sql"