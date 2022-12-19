########################################################
# This approach only returns process if they have logs #
########################################################


function Get-ListeningProcessLogs {
    

    # This portion get the network conections then matches the Listening connections with their Proces Names
    $NetConnections = Get-NetTCPConnection
    $ListeningProcess = (get-ciminstance win32_process | Where-Object {$NetConnections.owningprocess -eq $_.ProcessID})

    # To properly filter the EventLogs, we need the hex value of the listening process. This section of the code formats the hex version of the Process ID then takes the hex value and grabs the corrisponding event logs.
    $ListeningLogs = @()

    foreach ($process in $ListeningProcess) { 
        $hexProcess = ('0x{0:X}' -f [convert]::ToString($process.ProcessID,16)) 
        $ListeningLogs += Get-WinEvent -FilterHashtable @{LogName="Security"; ID="4688"; 'NewProcessID'= $hexProcess } -ErrorAction SilentlyContinue
    }

    # This sections takes the texted based logs message field and converts them to an object
    $MessageArr = @()

    ForEach ($log in $ListeningLogs) {
        $log | ForEach-Object {
            $logProperties = $log | Select-Object -ExpandProperty Properties
            $MessageObj = [PSCustomObject]@{
                TimeCreated = $log.TimeCreated
                TaskDisplayName = $log.TaskDisplayName
                RecordId = $log.RecordId
                ProviderName = $log.ProviderName
                MachineName = $log.MachineName
                LogName = $log.LogName
                LevelDisplayName = $log.LevelDisplayName
                KeywordsDisplayNames = $log.KeywordsDisplayNames
                Id = $log.Id
                ContainerLog = $log.ContainerLog
                UserSid = $logProperties[0].value.value
                UserName = $logProperties[1].value
                DomainName = $logProperties[2].value
                LogonIDHex = ('0x{0:X}' -f [convert]::ToString($logProperties[3].value,16))
                LogonIDDEC = $logProperties[3].value
                NewProcessIdHex = ('0x{0:X}' -f [convert]::ToString($logProperties[4].value,16))
                NewProcessIdDEC = $logProperties[4].value
                NewProcessName = $logProperties[5].value
                TokenElevationType = $logProperties[6].value
                ProcessIDHex = ('0x{0:X}' -f [convert]::ToString($logProperties[7].value,16))
                ProcessIDDec = $logProperties[7].value
                CommandLine = $logProperties[8].value

            }
            $MessageArr += $MessageObj
        }  
    }

    # This block of code creates the new Process Information Object.  More properties can be added from the variables used in the script.
    $ProcessInfo = @()

    foreach ($Message in $MessageArr){$info = [PSCustomObject]@{
        LocalAddress = ($NetConnections | Where-Object {$Message.NewProcessIdDEC -eq $_.Owningprocess}).LocalAddress
        LocalPort = ($NetConnections | Where-Object {$Message.NewProcessIdDEC -eq $_.Owningprocess}).LocalPort
        RemoteAddress = ($NetConnections | Where-Object {$Message.NewProcessIdDEC -eq $_.Owningprocess}).RemoteAddress
        RemotePort = ($NetConnections | Where-Object {$Message.NewProcessIdDEC -eq $_.Owningprocess}).RemotePort
        State = ($NetConnections | Where-Object {$Message.NewProcessIdDEC -eq $_.Owningprocess}).State
        ProcessIDDec = $Message.NewProcessIdDEC
        ProcessIDHex = $Message.NewProcessIdHex
        ProcessName = $Message.NewProcessName
        ProcessPath = ($ListeningProcess | Where-Object {$_.ProcessID -eq $Message.NewProcessIDDec}).path
        ProcessCMD = ($ListeningProcess | Where-Object {$_.ProcessID -eq $Message.NewProcessIDDec}).CommandLine
        LogTimeCreated = $Message.TimeCreated
        LogRecordId = $Message.RecordId
        LogProviderName = $Message.ProviderName
        LogName = $Message.LogName
        LogId = $Message.Id
        UserSid = $Message.UserSid
        UserName = $Message.UserName
        MachineName = $Message.MachineName
        DomainName = $Message.DomainName
        TokenElevationType = $Message.TokenElevationType
        
        }
        $ProcessInfo += $info
    }

    $ProcessInfo
}

Get-ListeningProcessLogs