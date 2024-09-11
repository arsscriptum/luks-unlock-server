

function Get-MiniSrvSshProfile { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]       
        [Alias('b')]
        [switch]$Boot,
        [Parameter(Mandatory=$false)]       
        [Alias('r')]
        [switch]$Root 
    )

    try{

        if($Boot){
            return "miniautoboot"
        }

        if($Root){
            return "miniautoroot"
        }

        return "mini"

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 


function Reboot-MiniSrv { 
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try{

        $SshExe = (Get-Command 'ssh.exe').Source
        $MiniProfile = Get-MiniSrvSshProfile -Root
     
        &"$SshExe" "$MiniProfile" "/sbin/reboot"

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 

function Wait-Online { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]       
        [String]$ServerIp,        
        [Parameter(Mandatory=$false)]       
        [int]$Timeout = 30
    )
    try{
        $Start = (Get-Date)
        $IsConnected = $False
        Write-Host "[WAITING] " -NoNewLine -f DarkYellow
        Write-Host "Waiting for $ServerIp to be up..." -NoNewLine  -f DarkGray
        While($IsConnected -eq $False){
            [Timespan]$ts = (Get-Date) - $Start
            if($ts.TotalSeconds -gt $Timeout){
                Write-Host "[TIMEOUT] " -NoNewLine -f DarkRed
                Write-Host "$ServerIp is OFFLINE" -f DarkYellow
                break;
            }
            Start-Sleep 1
            Write-Host "." -NoNewLine -f DarkGray
            $IsConnected = Test-Connection -TargetName "$ServerIp" -Ping -IPv4 -Count 1 -TimeoutSeconds 1 -Quiet -ErrorAction Ignore
        }
        if($IsConnected){
            Write-Host "[ONLINE] " -NoNewLine -f DarkGreen
            Write-Host "Looks like $ServerIp is online!" -f DarkGray
        }
    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 


function Unblock-MiniSrvRootFs { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]       
        [String]$ServerIp = "10.0.0.111"   
    )

    try{
        $SshExe = (Get-Command 'ssh.exe').Source
        $Credz = Get-AppCredentials -Id "minisrv.initramfs"

        if($Null -eq $Credz){ throw "no credentials found!" }
        Write-Host "unlocking root fs..." -NoNewLine  -f DarkYellow
        $Username = $Credz.UserName
        $Password = $Credz.GetNetworkCredential().Password
        $MiniProfile = Get-MiniSrvSshProfile -Boot
        $Cmd = 'echo -ne "{0}" >/lib/cryptsetup/passfifo' -f $Password
        &"$SshExe" "$MiniProfile" "$Cmd"

        Write-Host "`ndone!"  -f DarkGreen

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 



function Reboot-MiniSrvFull { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]       
        [String]$ServerIp = "10.0.0.111"   
    )

    try{

        Write-Host "=====================================================" -f DarkRed
        Write-Host "Rebooting mini server and decrypt root file system..." -f DarkYellow
        Write-Host "=====================================================`n`n" -f DarkRed

        Write-Host "Rebooting..." -f DarkYellow -NoNewLine
        Reboot-MiniSrv
        Start-Sleep 7
        Wait-Online -ServerIp $ServerIp -Timeout 20

        Unblock-MiniSrvRootFs -ServerIp "$ServerIp" 
        
        Write-Host "Finish boot sequence..." -f DarkYellow
        Start-Sleep 2
        $Start = Get-Date 
        $WaitFor = 12
        $Start = (Get-Date)
        $Wait = $True
        Initialize-AsciiProgressBar -EstimatedSeconds $WaitFor -Size 30
        While($Wait){
            [Timespan]$ts = (Get-Date) - $Start
            $Elapsed = [math]::Round( [math]::Abs(( $ts.TotalSeconds ) ) )
            $p = [math]::Round( [math]::Abs(( ($Elapsed/$WaitFor)*100 ) ) )
            if($p -gt 99){
                $p = 100
                $Wait = $False
                Write-Host "=====================`nREADY!`n" -f DarkCyan
            }
            if($Elapsed -gt $WaitFor){
                $Wait = $False
                Write-Host "=====================`nREADY!`n" -f DarkCyan
            }
            Show-AsciiProgressBar $p "please wait..." -UpdateDelay 50 -ProgressDelay 2 -ForegroundColor DarkYellow
            Start-Sleep -Milliseconds 200
        }
        Write-Host "Rebooting - your good now. " -f DarkYellow
        $SshExe = (Get-Command 'ssh.exe').Source
        &"$SshExe" "mini"

    }catch{
      Write-Host "$_" -f DarkRed
    }    
} 

