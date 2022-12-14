<#
command usage:Example
>.\ElInstallScript.ps1 -clinicid "1337" -apikey "64A2BBFA-D243-4B36-AEA9-D05BBDDB144A" -account "ngms\testashok" -password "Entrada1!" -env "prod" -downloadPath "C:\EntradaFiles\ExpressLink" 
#>

param(
#usage: -clinicid "1337"
[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$clinicid=(throw "argument for ClinicId is required"),
#usage: -apiKey "64A2BBFA-D243-4B36-AEA9-D05BBDDB144A"
[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$apiKey = (throw "argument for ApiKey is required"),
#usage: -localSystem "true" | -localSystem "true"
[Parameter()]
[string]$localSystem,
#usage: -account "{username}"
[Parameter()]
[string]$account,
#password: -password "{password}"
[Parameter()]
[string]$password,
#usage -runInParallel "1" | -runInParallel "0"
[Parameter()]
[string]$runInParallel = "1",
[ValidateNotNullOrEmpty()]
#accepted env's are: 'prod' | 'qa-patch' | 'qa-patch1' | 'staging' | 'perf' | 'qa-major' | 'dev-major' | 'qa-hotfix' | 'dev-hotfix' | 'dev-patch'.
[Parameter()]
[string]$env = (throw "argument for env is Required..!"),
#usage -downloadPath "C:\Entrada\ExpressLink" not to provide \ at the end.
[Parameter()]
[ValidateNotNullOrEmpty()]
[string]$downloadPath =(throw "download path is required")
#[string]$downloadPath = "D:\Ashok\NGMS\ngms-expresslink\ExpressLinkClient\Installer\Entrada.ExpressLink.BundledInstaller\bin\Release"#++++++++++++++++
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# check if both way of login entry is missed.
if(-not $localSystem -and (-not $account) -and (-not $password)){
    throw "Logon for Localsystem or serviceAccount one of these is must";
}

# trim the last "\" if user enters it in the path
$lastIndex = $downloadPath.Length;
$lastIndex= $lastIndex - 1;
if($downloadPath[$lastIndex] -eq "\"){
$downloadPath = $downloadPath.Remove($lastIndex)
}


#constant variable that holds bundler name.
$BundlerName = "NextGen.ExpressLink.BundledInstaller.exe";

#preparing environment.
$environments = @{};
$environments['prod'] = "https://expresslink.entradahealth.net";
$environments['staging'] = "https://expresslink-stage.entradahealth.net";
$environments['qa-patch'] = "https://expresslink-qa-patch.entradahealth.net";
$environments['qa-patch1'] = "https://expresslink-qa-patch1.entradahealth.net";
$environments['perf'] = "https://expresslink-perf.entradahealth.net";
$environments['qa-hotfix'] = "https://expresslink-qa-hotfix.entradahealth.net";
$environments['qa-major'] = "https://expresslink-qa-major.entradahealth.net";
$environments['dev-hotfix'] = "https://expresslink-dev-hotfix.entradahealth.net";
$environments['dev-patch'] = "https://expresslink-dev-patch.entradahealth.net";
$environments['dev-major'] = "https://expresslink-dev-major.entradahealth.net";

#setting environment from Hashtable.
foreach($key in $environments.GetEnumerator()){
    if($env -eq $key.name){
        $Environment = $key.Value;
    }
}

#if environment key entry is invalid then throws errors
if(-not $Environment){
    throw "Envirnment details for key `"$env`" not found";
}

#download the installer.
#force download the installer even if it is available.
#delete the file if exists.
$FullyQualifiedBundlerPath = -join($downloadPath, "\", $BundlerName);

$DownloadURL = -join($Environment, "/", $BundlerName);

#remove existing exe file if exists in the specified path.
$FileExists = Test-Path -Path $FullyQualifiedBundlerPath -PathType Leaf
if($FileExists -eq $true){
    Remove-Item $FullyQualifiedBundlerPath -force;
}
$folderExists = Test-Path -Path $downloadPath

if($folderExists -eq $false){
    New-Item -Path $downloadPath -ItemType Directory  | Out-Null
}
#now after deleting existing installer download the latest installer.
Invoke-RestMethod -URI $DownloadURL -OutFile $FullyQualifiedBundlerPath;

#check for the file after downloading
$FileExists = Test-Path -Path $FullyQualifiedBundlerPath -PathType Leaf
if ($FileExists -eq $false) {
    throw "Installer not found at Specified path: $downloadPath Failed to download Installer...";
}

#building the install command and parameter.
$additionalParameters="";
$parameters = 'CmdInstall="TRUE"', "ClinicId=$clinicid", "Environment=$environment", "ApiKey=$apiKey", "RunInParallel=$runInParallel";
if(-not $localSystem){
$additionalParameters = "Account=$account","Password=$password";
}
else{
$additionalParameters = "LocalSystem=$localSystem";
}


# executes Install command*
#################################################################################################
& $FullyQualifiedBundlerPath $parameters $additionalParameters /q /wait;
#################################################################################################

#preparing return data
[hashtable]$returnData = @{};
$returnData.ApiKey=$apiKey;
$returnData.ClinicId=$clinicid;
$returnData.FilePath=$downloadPath;

for ($i = 1; $i -le 100; $i++ ) {
    $check = ($i%5) -eq 0;
    $check1 =$i -ge 5;
    if($check -and $check1){
        $serviceStatus = Get-Service -name 'NextGen-MS-Expresslink-Client' -ErrorAction SilentlyContinue;
        if($serviceStatus){
            Write-Progress -Activity "Installtion Completed" -Status "100% Complete" -PercentComplete 100;
            Start-Sleep -Seconds 1;
            $returnData.ReturnString = "Installation Succeeded.";
            $returnData.ExitCode = [int]0;
            return $returnData;
        }
    }
    else
    {
        Write-Progress -Activity "Installtion in Progress" -Status "$i% Complete" -PercentComplete $i
    }
    Start-Sleep -seconds 1
}

    $returnData.ReturnString = "Installation Failed.";
    $returnData.ExitCode = [int]1;
    return $returnData;
####################-End-#####################