# To suppress Invalid certificate prompt
#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$VCServer = "Inserisci l'indirizzo del cluster"
#$File="C:\Users\jonathan\Documents\Archivio\SCRIPT-HA-CLUSTER\Password.txt"
$User="Inserisci il nome utente"
$pass="Inserisci la password"
#$File_tmp="C:\Program Files\NSClient++\scripts\tmp.txt"
#$File_HA="C:\Program Files\NSClient++\scripts\Ha_Status_VcenterAZ.txt"
$File_tmp="C:\Temp\tmp.txt"
$File_HA="Inserisci il percorso del file .txt dove va a scrivere lo stato degli host"
$Numhosts=3
$count=0

# Correcting the Environment Variable to the PowerCLI Module, due to a bug in the PowerCLI installer
#Save the current value in the $p variable.
$p = [Environment]::GetEnvironmentVariable('PSModulePath')

#Add the new path to the $p variable. Begin with a semi-colon separator.
$p += ';C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Modules\'

#Add the paths in $p to the PSModulePath value.
[Environment]::SetEnvironmentVariable('PSModulePath',$p)

Import-Module -Name VMware.VimAutomation.Core


function toglispazi([String] $text){
	$chars=$text.ToCharArray()
	$check=0
	for ($i=0;$i -lt $text.Length; $i++ ){
		if($chars[$i] -eq ' '){
			if($check -ne 1){
				$chars[$i]=';'
				$check=1
			}
		}
	}
	$text = New-Object System.String($chars,0,$chars.Length)
	$text = $text.Replace(' ','')
    return $text
}

try{
	$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, ($pass | ConvertTo-SecureString -AsPlainText -Force)
	
	# Create connection with VC
	Connect-VIServer -Server $VCServer -Credential $credential >$null 2>&1

	# Get cluster name
	$ClusterName = Get-Cluster | Select -ExpandProperty Name

	# Get HA agents status
	Get-Cluster -Name $ClusterName | Get-VMHost | Select Name,@{N='State';E={$_.ExtensionData.Runtime.DasHostState.State}} | Out-File -FilePath $File_tmp
	
	# Trim 3 header lines
	Get-Content $File_tmp | Select-Object -Skip 3 | Out-File -FilePath $File_HA
	
	# Verifica se il file esiste altrimenti esci
	if ((Test-Path $File_HA)){
		$Ha_Status = $File_HA
	}else{
		$host.SetShouldExit(2)
	}

	$text = Get-Content $File_HA
	$text = $text -split '\n' #preleva le singole righe di ciascun host
	del $File_tmp
	
	for ($i=0; $i -lt $Numhosts; $i++){
		$text_nospace=toglispazi($text[$i])
		$parts = $text_nospace -split ';' #preleva nome e stato dell'host 
		$Name = $parts[0] 
		$Status = $parts[1]

		if($Status -eq "connectedToMaster" -Or $Status -eq "master"){
			$count=$count+1
			$ok = $Name + "->" + $Status + " " + $ok
		}else{
			$critical= $Name + "->" + $Status + " " + $critical
		}
	}
	
	if($count -eq 3){
		write-host "VMware HA - OK" $ok
		exit 0
	}else{
		write-host "VMware HA - Critical" $critical
		#$host.SetShouldExit(2)
		exit 2
	}
}catch {
    write-host "VMware HA - Critical - Problema errore nel codice"
	$host.SetShouldExit(2)
	exit 2
}