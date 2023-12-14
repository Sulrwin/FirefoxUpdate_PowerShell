#Set the File locations and links
$GeneralFolder = "C:\Installs\Updates\" #log/temp folder
$LogFile = "C:\Installs\Updates\UpdateFirefox.log" #Log file name with path
$MSILocAndName = "C:\Installs\Updates\FirefoxInstaller.msi" #Installer name with path
$MSILOGLocAndName = "C:\Installs\Updates\FirefoxInstaller.log" #Installer log file name with path
$JSONUrl = "https://product-details.mozilla.org/1.0/firefox_versions.json" #Json file LINK
$MSIUrl = "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US" #Installer file LINK

#SuccessCodes
$DownloadSuccessCode = 200 # DON'T CHANGE ME (Unless you have to!)
$InstallSuccessCode = 0 # Might be universial not sure

#Info/Warning/Error Messages (Useful to personalise for individual programs)
$CHKFailedCurrent = "Failed to check current version. Probably not installed."
$CHKFailedNewest = "FAILED TO CHECK NEWEST VERSION"
$DLFailedNewest = "FAILED TO DOWNLOAD NEWEST INSTALLER"
$INSFailed = "FAILED TO INSTALL NEWEST VERSION"

New-Item -ItemType Directory -Force -Path $GeneralFolder # Force creation of log/temp folder

#Test to see if previous log is there and delete. ###### Possible to disable this and the logs will just be added on to existing
if (Test-Path $LogFile) {
    rm $LogFile
}
 
#Function to Create a Log File
Function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string] $message,
        [Parameter(Mandatory = $false)] [ValidateSet("INFO","WARNING","ERROR")] [string] $level = "INFO"
    )
    $Timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss") #Timestamps in the format Cory likes
    Add-Content -Path $LogFile -Value "$timestamp [$level] - $message"
}
 
#Call the Function to Log a Message
Write-Log -level INFO -message "Started Script" #Log the start of the script - Mostly here as a placeholder/example of the command.



$Main = {

    # Get current firefox version
    try {
        $ProgInstalled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\Mozilla Firefox' | Select 'CurrentVersion').CurrentVersion #Read current version of program from the file properties. FIREFOX ONLY Maybe?
        if ($ProgInstalled -eq $null) {
            throw
        }
        Write-Log -level INFO -message ("Current Version: " + $ProgInstalled) #Log Current Version
    }
    catch { #In case the program is not installed \/
        Write-Log -level WARNING -message $CHKFailedCurrent #Log failure to aquire version - Its set to WARNING as this is not a problem its likely not installed.
    }
    if ($ProgInstalled -eq $null) { #If we failed to aquire version we pull out of the process and end safely as we don't want to install the program or show an error
        return                      # We do this in an if statement as returning from our catch just puts us back in the main loop
    }

    # Get newest firefox version
    try {
        $ProgLatest = ( Invoke-WebRequest $JSONUrl -UseBasicParsing | ConvertFrom-Json ).LATEST_FIREFOX_VERSION #Pull current version from the provided JSON. FIREFOX ONLY
        if ($ProgLatest -eq $null) { #If that fails its likely the JSON was modified or moved
            throw
        }
        Write-Log -level INFO -message ("Newest Version: " + $ProgLatest) #Log newest version
    }
    catch { #It failed, this is bad, Log error and crash.
        Write-Log -level ERROR -message $CHKFailedNewest
        throw $CHKFailedNewest
    }

    #Compare versions and determine if up to date
    If ($ProgInstalled -match $ProgLatest) {
        Write-Log -level INFO -message "Newest is installed" #Log if newest is already installed and end safely
        return
    } else {
        Write-Log -level INFO -message "Downloading newest version of installer..." #Log start of download
        $ProgDownloadResult = (wget $MSIUrl -OutFile $MSILocAndName -PassThru) #Download file
        if ($ProgDownloadResult.StatusCode -eq $DownloadSuccessCode) { #Determine if download was a success or not
            Write-Log -level INFO -message "Download Complete"
            #Write-Log -level INFO -message ("Return Code: " + $ProgDownloadResult.StatusCode) #This will return a code on success in case you need to see what the success code is for modifications
        } else {
            Write-Log -level ERROR -message $DLFailedNewest
            Write-Log -level INFO -message ("Return Code: " + $ProgDownloadResult.StatusCode) #Return failure code
        }

        #####Disabled process to uninstall Firefox. Determined was not needed. 
        <#
        Write-Log -level INFO -message "Uninstalling old version of Firefox..."
        $ProgUninstallResult = $(Start-Process -FilePath "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" -ArgumentList "-ms /s" -Wait -PassThru)
        if ( $ProgUninstallResult.ExitCode -eq 0 ) {
            Write-Log -level INFO -message "Completed Uninstall!"
            Write-Log -level INFO -message ("Return Code: " + $ProgUninstallResult.ExitCode)
        } else {
            Write-Log -level ERROR -message "FAILED TO UNINSTALL OLD VERSION OF FIREFOX"
            Write-Log -level INFO -message ("Return Code: " + $ProgUninstallResult.ExitCode)
        }
        #>

        Write-Log -level INFO -message "Installing new version of Firefox..." #Log installation start
        $ProgInstallResult = $(Start-Process msiexec.exe -Wait -ArgumentList ('/i ' + $MSILocAndName + ' /q /le ' + $MSILOGLocAndName) -PassThru) #Start installation and log process
        if ( $ProgInstallResult.ExitCode -eq $InstallSuccessCode ) {
            Write-Log -level INFO -message "Completed Installation!"
            #Write-Log -level INFO -message ("Return Code: " + $ProgInstallResult.ExitCode) #Same as before this is for modifications
            rm $MSILOGLocAndName #Here we can remove the log created from the installer on success. You can disable for troubleshooting issues if needed.
        } else {
            Write-Log -level ERROR -message $INSFailed
            Write-Log -level INFO -message ("Return Code: " + $ProgInstallResult.ExitCode) #Log failure to install with code and crash.
            throw $INSFailed
        }
        rm $MSILocAndName #Delete MSI installer after success or failure. No one will be left behind!

    }
}

#Run Main body
Invoke-Command -Scriptblock $Main

#Log script has completed successfully
Write-Log -level INFO -message "Completed Script" #Nice to make sure script operated properly and made it to the end.