param (
    [string]$ip = "",
    [string]$user = "",
    [string]$pass = ""
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

if ($PSVersionTable.PSVersion.Major -lt 5) {
    [System.Windows.MessageBox]::Show("Requer PowerShell 5.1+", "Erro", 'OK', 'Error') | Out-Null
    exit
}

$script:AppRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { [Environment]::CurrentDirectory }
$script:BackupRoot = Join-Path $script:AppRoot "Backups"
$script:LogRoot = Join-Path $script:AppRoot "Logs"
New-Item -ItemType Directory -Force -Path $script:BackupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $script:LogRoot | Out-Null
$script:LogFile = Join-Path $script:LogRoot ("EdgeRouterSuiteWPF_{0}.log" -f (Get-Date -Format "yyyyMMdd"))
$script:ConfigCommandsCache = $null
$script:DhcpStaticMappings = @()
$script:PbrLeaseCandidates = @()

function Convert-OutputToText {
    param($Output)
    if ($null -eq $Output) { return "" }
    if ($Output -is [System.Array]) { return ($Output -join "`r`n") }
    return [string]$Output
}

function Write-AppLog {
    param([string]$Message,[string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpper(), $Message
    Add-Content -Path $script:LogFile -Value $line
    if ($script:txtLog) {
        $script:txtLog.AppendText($line + "`r`n")
        $script:txtLog.ScrollToEnd()
    }
    if ($script:txtStatus) {
        $script:txtStatus.Text = $Message
    }
}

function Set-OutputText {
    param(
        [Parameter(Mandatory=$true)]$Target,
        $Content,
        [string]$Title = ''
    )
    $text = Convert-OutputToText $Content
    if ($Title) {
        $Target.Text = $Title + "`r`n" + ('=' * $Title.Length) + "`r`n" + $text
    } else {
        $Target.Text = $text
    }
    $Target.ScrollToHome()
}

function Set-FirewallOutput {
    param(
        $Content,
        [string]$Title = ''
    )
    if ($script:txtFwInline) {
        Set-OutputText -Target $script:txtFwInline -Content $Content -Title $Title
    }
    if ($script:txtFwOut) {
        Set-OutputText -Target $script:txtFwOut -Content $Content -Title $Title
    }
}


$script:CurrentLanguage = 'pt'
$script:TranslationsPtToEn = [ordered]@{
    'EdgeRouter Suite Friendly - WPF Preview v20 DPI / Offload' = 'EdgeRouter Suite Friendly - WPF Preview v17 per-IP P2P blocking'
    'Conexão do Roteador' = 'Router Connection'
    'Usuário:' = 'User:'
    'Senha:' = 'Password:'
    'Testar SSH' = 'Test SSH'
    'O que este app faz?' = 'What does this app do?'
    'Status:' = 'Status:'
    'Base:' = 'Base:'
    'Pronto' = 'Ready'
    'Dashboard' = 'Dashboard'
    'DHCP' = 'DHCP'
    'Firewall / NAT' = 'Firewall / NAT'
    'Balanceamento / PBR' = 'Load Balancing / PBR'
    'DNS / Bloqueios' = 'DNS / Blocking'
    'Ferramentas / Log' = 'Tools / Log'
    'Resumo do Roteador' = 'Router Summary'
    'Interfaces / Rotas / ARP' = 'Interfaces / Routes / ARP'
    'Clientes DHCP' = 'DHCP Clients'
    'Ler Leases DHCP' = 'Read DHCP Leases'
    'Listar Reservas' = 'List Reservations'
    'Usar Lease Selecionado' = 'Use Selected Lease'
    'Listar online agora' = 'List online now'
    'Ler Bloqueios P2P' = 'Read P2P Blocks'
    'Bloquear P2P/Torrent' = 'Block P2P/Torrent'
    'Remover Bloqueio P2P' = 'Remove P2P Block'
    'Bloqueios P2P/Torrent' = 'P2P/Torrent Blocks'
    'Bloqueio P2P/Torrent por IP (DPI)' = 'Per-IP P2P/Torrent block (DPI)'
    'Clientes online agora' = 'Online clients now'
    'Criar Reserva DHCP' = 'Create DHCP Reservation'
    'Remover Reserva' = 'Remove Reservation'
    'Limpar Campos' = 'Clear Fields'
    'Reservas DHCP existentes' = 'Existing DHCP Reservations'
    'Saída / diagnóstico DHCP' = 'DHCP output / diagnostics'
    'Regras' = 'Rules'
    'NAT / Port Forward' = 'NAT / Port Forward'
    'QoS' = 'QoS'
    'Saída / Diagnóstico' = 'Output / Diagnostics'
    'Nome:' = 'Name:'
    'Ação:' = 'Action:'
    'Origem:' = 'Source:'
    'Descrição:' = 'Description:'
    'Listar Regras' = 'List Rules'
    'Criar Regra' = 'Create Rule'
    'Destino:' = 'Destination:'
    'Protocolo:' = 'Protocol:'
    'Porta dest.:' = 'Dest. port:'
    'Bloquear Internet do IP' = 'Block Internet for IP'
    'Permitir Só Web/DNS' = 'Allow Web/DNS Only'
    'Bloquear Porta/Proto' = 'Block Port/Proto'
    'Ler Regras do App' = 'Read App Rules'
    'Remover Regra Selecionada' = 'Remove Selected Rule'
    'Firewall' = 'Firewall'
    'Regra' = 'Rule'
    'Ação' = 'Action'
    'Origem' = 'Source'
    'Destino' = 'Destination'
    'Protocolo' = 'Protocol'
    'Porta' = 'Port'
    'Regra ID:' = 'Rule ID:'
    'Chain:' = 'Chain:'
    'Entrada WAN:' = 'WAN In:'
    'Porta Externa:' = 'External Port:'
    'IP Interno:' = 'Internal IP:'
    'Porta Interna:' = 'Internal Port:'
    'Listar Port Forward' = 'List Port Forward'
    'Criar Port Forward' = 'Create Port Forward'
    'Saída / diagnóstico NAT' = 'NAT output / diagnostics'
    'Política:' = 'Policy:'
    'Interface WAN:' = 'WAN Interface:'
    'Download (Mbit):' = 'Download (Mbit):'
    'Upload (Mbit):' = 'Upload (Mbit):'
    'Padrão' = 'Default'
    'Voz / WhatsApp' = 'Voice / WhatsApp'
    'Reuniões' = 'Meetings'
    'Jogos' = 'Gaming'
    'Ler QoS' = 'Read QoS'
    'Aplicar Smart Queue' = 'Apply Smart Queue'
    'Remover QoS' = 'Remove QoS'
    'Saída / diagnóstico QoS' = 'QoS output / diagnostics'
    'Por dispositivo' = 'Per device'
        'Limite download (Mbit):' = 'Download limit (Mbit):'
    'Limite upload (Mbit):' = 'Upload limit (Mbit):'
    'Banda total down (Mbit):' = 'Total down (Mbit):'
    'Banda total up (Mbit):' = 'Total up (Mbit):'
    'Nota:' = 'Note:'
    'Ler limites' = 'Read limits'
    'Aplicar limite' = 'Apply limit'
    'Remover limite selecionado' = 'Remove selected limit'
    'Limites por dispositivo' = 'Per-device limits'
    'Limites por dispositivo (Advanced Queue)' = 'Per-device limits (Advanced Queue)'
    'Este modo usa Advanced Queue global para limitar o IP em download e upload. Remova Smart Queue antes de usar.' = 'This mode uses global Advanced Queue to limit the IP on download and upload. Remove Smart Queue before using it.'
    'Fila Down' = 'Down Queue'
    'Fila Up' = 'Up Queue'
    'Sticky Sessions' = 'Sticky Sessions'
    'Grupo Load-Balance:' = 'Load-Balance Group:'
    'Ver Status' = 'View Status'
    'Ativar Sticky' = 'Enable Sticky'
    'Remover Sticky' = 'Disable Sticky'
    'Forçar rota por IP (PBR)' = 'Force route by IP (PBR)'
    'IP da máquina:' = 'Device IP:'
    'Tabela:' = 'Table:'
    'WAN fixa:' = 'Fixed WAN:'
    'Firewall Modify:' = 'Firewall Modify:'
    'Modo:' = 'Mode:'
    'Saída fixa' = 'Fixed output'
    'Preferir WAN1' = 'Prefer WAN1'
    'Preferir WAN2' = 'Prefer WAN2'
    'Kill switch: se a WAN preferida cair, este IP não usa a WAN de backup' = 'Kill switch: if the preferred WAN fails, this IP will not use the backup WAN'
    'Aplicar política' = 'Apply policy'
    'Políticas PBR' = 'PBR Policies'
    'Ler Políticas PBR' = 'Read PBR Policies'
    'Remover Política Selecionada' = 'Remove Selected Policy'
    'Descrição' = 'Description'
    'Tabela' = 'Table'
    'WAN' = 'WAN'
    'Carrega as políticas de PBR da chain informada para conferência e remoção.' = 'Loads PBR policies from the selected chain for review and removal.'
    'Remove a política de PBR selecionada da chain e limpa a tabela se ela não estiver mais em uso.' = 'Removes the selected PBR policy from the chain and clears the table if it is no longer in use.'
    'Modo Saída fixa = prende o IP na WAN informada. Preferir WAN1/WAN2 = tenta usar a WAN escolhida e, sem kill switch, usa a outra como backup.' = 'Fixed output mode = locks the IP to the selected WAN. Prefer WAN1/WAN2 = tries to use the chosen WAN and, without kill switch, uses the other as backup.'
    "Dica: use 'Usar Selecionado no PBR' para preencher o IP a partir da lista de leases abaixo." = "Tip: use 'Use Selected Lease in PBR' to fill the IP from the lease list below."
    'WAN 1:' = 'WAN 1:'
    'WAN 2:' = 'WAN 2:'
    'Peso WAN1:' = 'WAN1 Weight:'
    'Peso WAN2:' = 'WAN2 Weight:'
    'Aplicar Pesos' = 'Apply Weights'
    'WAN1 Principal' = 'WAN1 Primary'
    'WAN2 Principal' = 'WAN2 Primary'
    'Leases para usar no PBR' = 'Leases to use in PBR'
    'Ler Leases do PBR' = 'Read PBR Leases'
    'Usar Selecionado no PBR' = 'Use Selected Lease in PBR'
    'Saída / diagnóstico do balanceamento' = 'Load balancing output / diagnostics'
    'Domínio:' = 'Domain:'
    'Ler Sites Bloqueados' = 'Read Blocked Sites'
    'Bloquear Site' = 'Block Site'
    'Desbloquear Site' = 'Unblock Site'
    'Listar Regras DNS / DoH' = 'List DNS / DoH Rules'
    'Sites bloqueados' = 'Blocked sites'
    'Saída / diagnóstico DNS' = 'DNS output / diagnostics'
    'LAN:' = 'LAN:'
    'IP do roteador:' = 'Router IP:'
    'Regra DNS:' = 'DNS Rule:'
    'Ativar Interceptação' = 'Enable Interception'
    'Remover Interceptação' = 'Remove Interception'
    'Regra DoH:' = 'DoH Rule:'
    'Ativar Bloqueio DoH' = 'Enable DoH Blocking'
    'Remover Bloqueio DoH' = 'Remove DoH Blocking'
    'Host/IP:' = 'Host/IP:'
    'Ping' = 'Ping'
    'DNS Test' = 'DNS Test'
    'Backup da Config' = 'Config Backup'
    'Abrir Pasta Logs' = 'Open Logs Folder'
    'Ler Status DPI/Offload' = 'Read DPI/Offload Status'
    'Modo análise de tráfego' = 'Traffic analysis mode'
    'Modo desempenho' = 'Performance mode'
    'DPI ligado = melhor para investigar consumo por aplicação. Pode reduzir desempenho. Modo desempenho = desliga DPI/export e tenta religar offload para o dia a dia.' = 'DPI on = better to investigate usage by application. It may reduce performance. Performance mode = disables DPI/export and tries to re-enable offload for daily use.'
    'IP' = 'IP'
    'MAC' = 'MAC'
    'Nome' = 'Name'
    'Pool' = 'Pool'
    'Sub-rede' = 'Subnet'
    'Tipo' = 'Type'
    'IP do EdgeRouter' = 'EdgeRouter IP'
    'Usuário SSH' = 'SSH user'
    'Senha SSH' = 'SSH password'
    'Lê os leases DHCP dinâmicos.' = 'Reads dynamic DHCP leases.'
    'Lê as reservas DHCP existentes na configuração.' = 'Reads existing DHCP reservations from configuration.'
    'Preenche 50/50. Use Aplicar Pesos para colocar em balanceamento.' = 'Fills 50/50. Use Apply Weights to enable balancing.'
    'Deixa a WAN1 como principal e a WAN2 como backup.' = 'Sets WAN1 as primary and WAN2 as backup.'
    'Deixa a WAN2 como principal e a WAN1 como backup.' = 'Sets WAN2 as primary and WAN1 as backup.'
    'Escolha entre saída fixa ou preferência por WAN1/WAN2 com fallback opcional.' = 'Choose between fixed output or WAN1/WAN2 preference with optional fallback.'
    'Aplica a política escolhida para o IP informado.' = 'Applies the selected policy to the informed IP.'
    'Lista o port-forward atual do roteador.' = 'Lists current port forwarding rules.'
    'Cria uma regra de port-forward usando os campos preenchidos.' = 'Creates a port-forward rule using the filled fields.'
    'Lista as regras da chain informada e abre a subaba de saída.' = 'Lists rules from the selected chain and opens the output subtab.'
    'Cria uma nova regra simples de firewall na chain informada.' = 'Creates a simple firewall rule on the selected chain.'
    'Lê a configuração QoS/Smart Queue e o status atual das filas.' = 'Reads QoS/Smart Queue configuration and current queue status.'
    'Carrega um perfil neutro para Smart Queue.' = 'Loads a neutral Smart Queue profile.'
    'Prepara um perfil rápido para chamadas e WhatsApp, mantendo a lógica simples do Smart Queue.' = 'Prepares a quick profile for calls and WhatsApp while keeping Smart Queue simple.'
    'Prepara um perfil rápido para Teams, Meet e Zoom.' = 'Prepares a quick profile for Teams, Meet and Zoom.'
    'Prepara um perfil rápido pensando em baixa latência para jogos.' = 'Prepares a quick low-latency gaming profile.'
    'Aplica um Smart Queue básico na interface WAN escolhida.' = 'Applies a basic Smart Queue to the chosen WAN interface.'
    'Remove a política Smart Queue informada.' = 'Removes the selected Smart Queue policy.'
    'Lista regras relacionadas a DNS, interceptação e DoH.' = 'Lists rules related to DNS, interception and DoH.'
    'Cria NAT para interceptar DNS porta 53 na LAN.' = 'Creates NAT to intercept DNS port 53 on the LAN.'
    'Remove a regra NAT usada na interceptação DNS.' = 'Removes the NAT rule used for DNS interception.'
    'Ativa um bloqueio básico de DoH para endpoints comuns.' = 'Enables basic DoH blocking for common endpoints.'
    'Remove o bloqueio básico de DoH configurado pelo app.' = 'Removes the basic DoH blocking configured by the app.'
    'Selecione um modo para a política de PBR.' = 'Select a mode for the PBR policy.'
    'Modo de PBR não reconhecido.' = 'PBR mode not recognized.'
    'Testando...' = 'Testing...'
    'Conexão OK' = 'Connection OK'
    'Conexão SSH bem-sucedida.' = 'SSH connection successful.'
    'Erro de conexão' = 'Connection error'
    'Sobre a versão WPF' = 'About the WPF version'
    'Isto é um protótipo WPF paralelo ao fix16.`r`n`r`nObjetivo:`r`n- comparar aproveitamento de espaço`r`n- testar grids, rolagem e layout`r`n- preservar a lógica PowerShell/SSH que já funcionou no fix16`r`n- testar perfis rápidos de QoS, PBR por WAN e o modo WAN preferida com kill switch' = 'This is a WPF prototype running in parallel with fix16.`r`n`r`nGoal:`r`n- compare space usage`r`n- test grids, scrolling and layout`r`n- preserve the PowerShell/SSH logic that already worked in fix16`r`n- test quick QoS profiles, per-WAN PBR and preferred-WAN mode with kill switch'
    'Backup salvo' = 'Backup saved'
    'Backup salvo em:' = 'Backup saved to:'
}
$script:TranslationsEnToPt = @{}
foreach ($k in $script:TranslationsPtToEn.Keys) { $script:TranslationsEnToPt[$script:TranslationsPtToEn[$k]] = $k }

function Get-UiText {
    param([string]$Text)
    if ($null -eq $Text) { return $Text }
    if ($script:CurrentLanguage -eq 'en') {
        if ($script:TranslationsPtToEn.Contains($Text)) { return $script:TranslationsPtToEn[$Text] }
    } else {
        if ($script:TranslationsEnToPt.Contains($Text)) { return $script:TranslationsEnToPt[$Text] }
    }
    return $Text
}

function Get-PbrModeKey {
    param([object]$SelectedItem)
    if ($null -eq $SelectedItem) { return $null }
    $txt = if ($SelectedItem -is [string]) { [string]$SelectedItem } else { [string]$SelectedItem.Content }
    switch ($txt) {
        'Saída fixa' { return 'fixed' }
        'Fixed output' { return 'fixed' }
        'Preferir WAN1' { return 'prefer1' }
        'Prefer WAN1' { return 'prefer1' }
        'Preferir WAN2' { return 'prefer2' }
        'Prefer WAN2' { return 'prefer2' }
        default { return $null }
    }
}

function Update-UiLanguage {
    param([string]$Language)
    if ($Language -notin @('pt','en')) { return }
    $script:CurrentLanguage = $Language

    function _Apply($element) {
        if ($null -eq $element) { return }
        try {
            if ($element -is [System.Windows.Window]) {
                $element.Title = Get-UiText $element.Title
            }
            if ($element -is [System.Windows.Controls.TextBlock]) {
                $element.Text = Get-UiText ([string]$element.Text)
            }
            if ($element -is [System.Windows.Controls.Button]) {
                $element.Content = Get-UiText ([string]$element.Content)
            }
            elseif ($element -is [System.Windows.Controls.CheckBox]) {
                $element.Content = Get-UiText ([string]$element.Content)
            }
            elseif ($element -is [System.Windows.Controls.TabItem]) {
                $element.Header = Get-UiText ([string]$element.Header)
            }
            elseif ($element -is [System.Windows.Controls.ComboBox]) {
                foreach ($item in $element.Items) {
                    if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                        $item.Content = Get-UiText ([string]$item.Content)
                    }
                }
            }
            if ($element.PSObject.Properties['ToolTip']) {
                $tip = $element.ToolTip
                if ($tip -is [string]) { $element.ToolTip = Get-UiText $tip }
            }
            if ($element -is [System.Windows.Controls.DataGrid]) {
                foreach ($col in $element.Columns) {
                    if ($col.Header -is [string]) { $col.Header = Get-UiText ([string]$col.Header) }
                }
            }
            foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($element)) {
                if ($child -is [System.Windows.DependencyObject]) { _Apply $child }
            }
        } catch {}
    }

    _Apply $window
    if ($script:txtStatus) {
        if ($txtStatus.Text -in @('Pronto','Ready')) { $txtStatus.Text = Get-UiText 'Pronto' }
    }
    if ($script:btnLangToggle) {
        $btnLangToggle.Content = if ($script:CurrentLanguage -eq 'pt') { 'EN' } else { 'PT' }
        $btnLangToggle.ToolTip = if ($script:CurrentLanguage -eq 'pt') { 'Switch interface to English' } else { 'Trocar interface para Português' }
    }
}

function Toggle-UiLanguage {
    if ($script:CurrentLanguage -eq 'pt') { Update-UiLanguage 'en' } else { Update-UiLanguage 'pt' }
}

function Show-UiMessage {
    param([string]$Message,[string]$Title = 'Aviso',[string]$Icon = 'Information')
    [System.Windows.MessageBox]::Show($Message, $Title, 'OK', $Icon) | Out-Null
}

function Confirm-UiAction {
    param([string]$Message,[string]$Title = 'Confirmar')
    $answer = [System.Windows.MessageBox]::Show($Message, $Title, 'YesNo', 'Question')
    return ($answer -eq [System.Windows.MessageBoxResult]::Yes)
}

function Test-IPv4Address {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return [System.Net.IPAddress]::TryParse($Value, [ref]([System.Net.IPAddress]$null))
}

function Test-PortNumber {
    param([string]$Value)
    $n = 0
    return ([int]::TryParse($Value, [ref]$n) -and $n -ge 1 -and $n -le 65535)
}

function Test-MacAddress {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return ($Value.Trim() -match '^(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}$')
}

function Normalize-EdgeName {
    param([string]$Value, [string]$Default = 'host_reservado')
    $name = ($Value -replace '[^a-zA-Z0-9._-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($name)) { return $Default }
    return $name
}

function Get-EdgeCredential {
    $routerIp = $txtIp.Text.Trim()
    $routerUser = $txtUser.Text.Trim()
    $routerPass = $txtPass.Password

    if ([string]::IsNullOrWhiteSpace($routerIp) -or [string]::IsNullOrWhiteSpace($routerUser) -or [string]::IsNullOrWhiteSpace($routerPass)) {
        throw 'Preencha IP, usuário e senha.'
    }

    $sec = ConvertTo-SecureString $routerPass -AsPlainText -Force
    return [pscustomobject]@{
        IP = $routerIp
        User = $routerUser
        Credential = [pscredential]::new($routerUser, $sec)
    }
}

function Ensure-PoshSshModule {
    if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
        throw 'O módulo Posh-SSH não foi encontrado. Instale-o antes de usar a versão WPF.'
    }
    Import-Module Posh-SSH -ErrorAction Stop | Out-Null
}

function Invoke-EdgeRouterCommand {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [switch]$Silent
    )

    Ensure-PoshSshModule
    $conn = Get-EdgeCredential
    $session = $null
    try {
        $session = New-SSHSession -ComputerName $conn.IP -Credential $conn.Credential -AcceptKey -ConnectionTimeout 10 -ErrorAction Stop
        $result = Invoke-SSHCommand -SSHSession $session -Command $Command -TimeOut 30000 -ErrorAction Stop
        $text = Convert-OutputToText $result.Output
        if (-not $Silent) { Write-AppLog "Comando SSH executado: $Command" }
        return $text
    }
    finally {
        if ($session) {
            try { Remove-SSHSession -SSHSession $session | Out-Null } catch {}
        }
    }
}

function Save-EdgeBackup {
    param([string]$Reason = 'manual')
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeReason = ($Reason -replace '[^a-zA-Z0-9._-]', '_')
    $file = Join-Path $script:BackupRoot ("backup_{0}_{1}.txt" -f $stamp, $safeReason)
    $raw = Invoke-EdgeRouterCommand -Command 'cat /config/config.boot' -Silent
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        Set-Content -Path $file -Value $raw -Encoding UTF8
        Write-AppLog "Backup salvo: $file"
        return $file
    }
    return $null
}

function Invoke-EdgeConfigCommand {
    param(
        [string[]]$Commands,
        [string]$Reason = 'config'
    )

    if (-not $Commands -or $Commands.Count -eq 0) { return '' }

    $backupFile = Save-EdgeBackup -Reason $Reason
    $wrapped = @('/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin')
    $wrapped += $Commands
    $wrapped += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit'
    $wrapped += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper save'
    $wrapped += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end'

    try {
        $out = Invoke-EdgeRouterCommand -Command ($wrapped -join '; ')
        $script:ConfigCommandsCache = $null
        if ($backupFile) {
            return "Backup: $backupFile`r`n`r`n$out"
        }
        return $out
    } catch {
        try { Invoke-EdgeRouterCommand -Command '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end' -Silent | Out-Null } catch {}
        throw
    }
}

function Get-EdgeConfigCommandsText {
    param([switch]$ForceRefresh)
    if (-not $ForceRefresh -and $script:ConfigCommandsCache) { return $script:ConfigCommandsCache }
    $raw = Invoke-EdgeRouterCommand -Command '/opt/vyatta/bin/vyatta-op-cmd-wrapper show configuration commands' -Silent
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $script:ConfigCommandsCache = $raw
    }
    return $raw
}

function Get-EdgeConfigLines {
    param([switch]$ForceRefresh)
    $raw = Get-EdgeConfigCommandsText -ForceRefresh:$ForceRefresh
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    return @(($raw -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Unquote-EdgeToken {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value.Trim() -replace '^"|"$','' -replace "^'|'$",'')
}

function Get-AppManagedFirewallRules {
    $lines = Get-EdgeConfigLines
    $map = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^set firewall name (\S+) rule (\d+) (.+)$') { continue }
        $fw = $Matches[1]
        $rule = $Matches[2]
        $rest = $Matches[3]
        $key = "$fw|$rule"
        if (-not $map.ContainsKey($key)) {
            $map[$key] = [ordered]@{
                Firewall = $fw
                Rule = [int]$rule
                Action = ''
                Source = ''
                Destination = ''
                Protocol = ''
                Port = ''
                Description = ''
            }
        }
        $item = $map[$key]
        if ($rest -match '^description (.+)$') { $item.Description = Unquote-EdgeToken $Matches[1]; continue }
        if ($rest -match '^action (\S+)$') { $item.Action = $Matches[1]; continue }
        if ($rest -match '^source address (\S+)$') { $item.Source = $Matches[1]; continue }
        if ($rest -match '^destination address (\S+)$') { $item.Destination = $Matches[1]; continue }
        if ($rest -match '^destination port (\S+)$') { $item.Port = $Matches[1]; continue }
        if ($rest -match '^protocol (\S+)$') { $item.Protocol = $Matches[1]; continue }
    }
    $items = foreach ($k in $map.Keys) { [pscustomobject]$map[$k] }
    return @($items | Where-Object {
        $_.Description -like 'APP_*' -or $_.Description -like 'Regra_app_*' -or $_.Description -like 'APPFW_*'
    } | Sort-Object Firewall, Rule)
}

function Refresh-AppManagedFirewallRules {
    $items = Get-AppManagedFirewallRules
    if ($dgFwManaged) { $dgFwManaged.ItemsSource = $items }
    Write-AppLog "Regras de firewall do app carregadas: $($items.Count)"
    return $items
}

function New-AppFirewallRuleCommands {
    param(
        [string]$Firewall,
        [int]$Rule,
        [string]$Action,
        [string]$Source,
        [string]$Destination,
        [string]$Protocol,
        [string]$Port,
        [string]$Description,
        [switch]$EnableLog
    )
    $cmds = @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule description '$Description'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule action $Action"
    )
    if ($Source) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule source address $Source" }
    if ($Destination) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule destination address $Destination" }
    if ($Protocol -and $Protocol -ne 'any') { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule protocol $Protocol" }
    if ($Port) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule destination port $Port" }
    if ($EnableLog) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $Firewall rule $Rule log enable" }
    return ,$cmds
}

function Set-FirewallFieldsFromRule {
    param($RuleObject)
    if ($null -eq $RuleObject) { return }
    try {
        $txtFwName.Text = [string]$RuleObject.Firewall
        $txtFwRule.Text = [string]$RuleObject.Rule
        $txtFwSource.Text = [string]$RuleObject.Source
        $txtFwDest.Text = [string]$RuleObject.Destination
        $txtFwPort.Text = [string]$RuleObject.Port
        $txtFwDesc.Text = [string]$RuleObject.Description
        $proto = if ([string]::IsNullOrWhiteSpace([string]$RuleObject.Protocol)) { 'any' } else { [string]$RuleObject.Protocol }
        foreach ($it in $cmbFwProto.Items) {
            if ($it.Content.ToString() -eq $proto) { $cmbFwProto.SelectedItem = $it; break }
        }
        $act = if ([string]::IsNullOrWhiteSpace([string]$RuleObject.Action)) { 'drop' } else { [string]$RuleObject.Action }
        foreach ($it in $cmbFwAction.Items) {
            if ($it.Content.ToString() -eq $act) { $cmbFwAction.SelectedItem = $it; break }
        }
    } catch {}
}

function Get-RouterSummary {
    $cmd = @(
        "echo '=== SISTEMA ==='"
        'show version'
        "echo ''"
        "echo '=== UPTIME / CARGA ==='"
        'uptime'
        "echo ''"
        "echo '=== MEMORIA ==='"
        'free -m'
        "echo ''"
        "echo '=== DISCO ==='"
        'df -h'
        "echo ''"
        "echo '=== INTERFACES ==='"
        '/opt/vyatta/bin/vyatta-op-cmd-wrapper show interfaces'
    ) -join '; '
    return Invoke-EdgeRouterCommand -Command $cmd
}

function Get-EdgeInterfacesOverview {
    $cmd = @(
        "echo '=== ENDERECOS ==='"
        'ip -brief address'
        "echo ''"
        "echo '=== ROTAS ==='"
        'ip route'
        "echo ''"
        "echo '=== ARP ==='"
        '/opt/vyatta/bin/vyatta-op-cmd-wrapper show arp'
    ) -join '; '
    return Invoke-EdgeRouterCommand -Command $cmd
}

function Get-DhcpLeaseRawText {
    $commands = @(
        '/opt/vyatta/bin/vyatta-op-cmd-wrapper show dhcp leases',
        '/opt/vyatta/bin/vyatta-op-cmd-wrapper show dhcp server leases',
        'show dhcp leases'
    )
    foreach ($cmd in $commands) {
        $text = Convert-OutputToText (Invoke-EdgeRouterCommand -Command $cmd -Silent)
        if (-not [string]::IsNullOrWhiteSpace($text) -and $text -notmatch '(?i)(invalid command|unknown command|not found|usage:)') {
            return $text.Trim()
        }
    }
    return ''
}

function Convert-LeaseLineToDisplay {
    param([string]$Line)
    $trim = [string]$Line
    if ([string]::IsNullOrWhiteSpace($trim)) { return $null }
    $trim = $trim.Trim()
    $tokens = ($trim -split '\s+') | Where-Object { $_ }
    if (-not $tokens -or $tokens.Count -lt 2) { return $null }
    $ip = $tokens | Where-Object { $_ -match '^\d{1,3}(?:\.\d{1,3}){3}$' } | Select-Object -First 1
    $mac = $tokens | Where-Object { $_ -match '^(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}$' } | Select-Object -First 1
    if (-not $ip -or -not $mac) { return $null }
    $rest = @($tokens | Where-Object { $_ -ne $ip -and $_ -ne $mac })
    if ($rest.Count -gt 0) { return ("{0} {1} {2}" -f $ip,$mac,($rest -join ' ')).Trim() }
    return ("{0} {1}" -f $ip,$mac)
}

function Parse-DhcpLeaseDisplayLine {
    param([string]$Line,[string]$Source='dynamic')
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $tokens = ($Line.Trim() -split '\s+') | Where-Object { $_ }
    $ip = $tokens | Where-Object { $_ -match '^\d{1,3}(?:\.\d{1,3}){3}$' } | Select-Object -First 1
    $mac = $tokens | Where-Object { $_ -match '^(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}$' } | Select-Object -First 1
    if (-not $ip -or -not $mac) { return $null }
    $leaseHost = ($tokens | Where-Object { $_ -ne $ip -and $_ -ne $mac } | Select-Object -Last 1)
    if (-not $leaseHost) { $leaseHost = "host_$($ip -replace '\.','_')" }
    return [pscustomobject]@{ IP=$ip; MAC=$mac; Host=$leaseHost; RawLine=$Line; Source=$Source }
}

function Get-DhcpLeaseLines {
    $text = Get-DhcpLeaseRawText
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $items = New-Object System.Collections.ArrayList
    foreach ($line in ($text -split "`r?`n")) {
        $trim = $line.Trim()
        if (-not $trim) { continue }
        if ($trim -match '^(?i)(ip address|mac address|expiration|binding|pool|lease|client-id|hostname|---|=+)') { continue }
        $display = Convert-LeaseLineToDisplay -Line $trim
        if ($display) { [void]$items.Add($display) }
    }
    return @($items | Sort-Object -Unique)
}

function Get-DhcpStaticMappings {
    $map = @{}
    $pattern = '^set service dhcp-server shared-network-name\s+((?:"[^"]+")|(?:''[^'']+'')|\S+)\s+subnet\s+(\S+)\s+static-mapping\s+((?:"[^"]+")|(?:''[^'']+'')|\S+)\s+(ip-address|mac-address)\s+(\S+)$'
    foreach ($line in (Get-EdgeConfigLines -ForceRefresh)) {
        if ($line -notmatch $pattern) { continue }
        $pool = Unquote-EdgeToken $matches[1]
        $subnet = $matches[2]
        $name = Unquote-EdgeToken $matches[3]
        $field = $matches[4]
        $value = $matches[5]
        $key = "$pool|$subnet|$name"
        if (-not $map.ContainsKey($key)) {
            $map[$key] = [ordered]@{ Pool=$pool; Subnet=$subnet; Name=$name; IP=''; MAC=''; Source='reserved' }
        }
                if ($field -eq 'ip-address') {
            $map[$key]['IP'] = $value
        } else {
            $map[$key]['MAC'] = $value
        }
    }
    $items = foreach ($entry in $map.GetEnumerator()) {
        [pscustomobject]@{
            Pool = [string]$entry.Value.Pool
            Subnet = [string]$entry.Value.Subnet
            Name = [string]$entry.Value.Name
            IP = [string]$entry.Value.IP
            MAC = [string]$entry.Value.MAC
            Source = [string]$entry.Value.Source
        }
    }
    return @($items | Sort-Object Pool, Subnet, Name)
}

function Get-LoadBalanceContext {
    $lines = Get-EdgeConfigLines -ForceRefresh
    if (-not $lines -or $lines.Count -eq 0) { return @() }
    $pppoeSources = @{}
    $ifaceModes = @{}
    $modifyNames = New-Object System.Collections.ArrayList
    $assignedModifyNames = New-Object System.Collections.ArrayList
    foreach ($line in $lines) {
        if ($line -match '^set interfaces pppoe (\S+) source-interface (\S+)$') {
            $pppoeSources[$matches[1]] = $matches[2]
            $ifaceModes[$matches[1]] = 'pppoe'
            continue
        }
        if ($line -match '^set interfaces ethernet (\S+) pppoe (\d+)\b') {
            $pppoeName = 'pppoe' + $matches[2]
            if (-not $pppoeSources.ContainsKey($pppoeName)) { $pppoeSources[$pppoeName] = $matches[1] }
            $ifaceModes[$pppoeName] = 'pppoe'
            continue
        }
        if ($line -match '^set interfaces ethernet (\S+) address dhcp$') { $ifaceModes[$matches[1]] = 'dhcp'; continue }
        if ($line -match '^set interfaces ethernet (\S+) address [0-9]{1,3}(?:\.[0-9]{1,3}){3}/\d+$') { if (-not $ifaceModes.ContainsKey($matches[1])) { $ifaceModes[$matches[1]] = 'static' }; continue }
        if ($line -match '^set firewall modify (\S+)\s') { if (-not ($modifyNames -contains $matches[1])) { [void]$modifyNames.Add($matches[1]) }; continue }
        if ($line -match '^set interfaces \S+ \S+ firewall \S+ modify (\S+)$') { if (-not ($assignedModifyNames -contains $matches[1])) { [void]$assignedModifyNames.Add($matches[1]) }; continue }
    }
    $groups = New-Object System.Collections.ArrayList
    $groupIndex = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^set load-balance group (\S+) interface (\S+)(?:\s+(.*))?$') { continue }
        $groupName = $matches[1]
        $ifaceName = $matches[2]
        $rest = [string]$matches[3]
        if (-not $groupIndex.ContainsKey($groupName)) {
            $obj = [pscustomobject]@{ Name=$groupName; Interfaces=New-Object System.Collections.ArrayList; ModifyChain=if ($assignedModifyNames.Count -gt 0) { [string]$assignedModifyNames[0] } elseif ($modifyNames.Count -gt 0) { [string]$modifyNames[0] } else { 'balance' } }
            $groupIndex[$groupName] = $obj
            [void]$groups.Add($obj)
        }
        $groupObj = $groupIndex[$groupName]
        $ifaceObj = $groupObj.Interfaces | Where-Object { $_.Name -eq $ifaceName } | Select-Object -First 1
        if (-not $ifaceObj) {
            $ifaceObj = [pscustomobject]@{ Name=$ifaceName; Weight='100'; FailoverOnly=$false; SourceInterface=''; Mode=''; Notes='' }
            [void]$groupObj.Interfaces.Add($ifaceObj)
        }
        if ($rest -match '^weight (\d+)$') { $ifaceObj.Weight = [string]$matches[1] }
        elseif ($rest -match '^failover-only$') { $ifaceObj.FailoverOnly = $true }
    }
    foreach ($groupObj in $groups) {
        foreach ($ifaceObj in $groupObj.Interfaces) {
            if ($pppoeSources.ContainsKey($ifaceObj.Name)) {
                $ifaceObj.SourceInterface = $pppoeSources[$ifaceObj.Name]
                $ifaceObj.Mode = 'pppoe'
                $ifaceObj.Notes = "PPPoE sobre $($ifaceObj.SourceInterface)"
            } elseif ($ifaceModes.ContainsKey($ifaceObj.Name)) {
                $ifaceObj.Mode = $ifaceModes[$ifaceObj.Name]
                switch ($ifaceObj.Mode) {
                    'dhcp' { $ifaceObj.Notes = "DHCP em $($ifaceObj.Name)" }
                    'static' { $ifaceObj.Notes = "IP estático em $($ifaceObj.Name)" }
                    default { $ifaceObj.Notes = $ifaceObj.Mode }
                }
            } else {
                $ifaceObj.Notes = 'Interface detectada no grupo'
            }
        }
    }
    return @($groups)
}

function Format-LoadBalanceSummary {
    param($GroupObj)
    if (-not $GroupObj) { return '' }
    $lines = @("Grupo: $($GroupObj.Name) | Firewall modify: $($GroupObj.ModifyChain)")
    $i = 1
    foreach ($iface in @($GroupObj.Interfaces)) {
        $role = if ($iface.FailoverOnly) { 'backup/failover' } else { 'ativo' }
        $lines += ("WAN{0}: {1} | peso {2} | {3} | {4}" -f $i, $iface.Name, $iface.Weight, $role, $iface.Notes)
        $i++
    }
    return ($lines -join "`r`n")
}

function Get-DnsBlockedDomains {
    $lines = Get-EdgeConfigLines -ForceRefresh
    $found = New-Object System.Collections.ArrayList
    foreach ($line in $lines) {
        if ($line -match '^set service dns forwarding options address=/([^/]+)/') {
            $domain = $matches[1].Trim().ToLower()
            if ($domain -and -not ($found -contains $domain)) { [void]$found.Add($domain) }
        }
    }
    return @($found | Sort-Object)
}

function Get-DnsRulesOverview {
    $lines = Get-EdgeConfigLines
    $filtered = foreach ($line in $lines) {
        if ($line -match '^set service nat rule \d+ ' -or $line -match '^set firewall group address-group DOH_IPS ' -or $line -match '^set service dns forwarding options address=') {
            $line
        }
    }
    if (-not $filtered -or $filtered.Count -eq 0) { return 'Nenhuma regra DNS/DoH encontrada na configuração.' }
    return ($filtered -join "`r`n")
}


function Get-QosOverview {
    $lines = Get-EdgeConfigLines
    $filtered = foreach ($line in $lines) {
        if ($line -match '^set traffic-control smart-queue ' -or
            $line -match '^set traffic-policy shaper ' -or
            $line -match '^set interfaces .+ traffic-policy ') {
            $line
        }
    }
    $runtime = ''
    try { $runtime = Invoke-EdgeRouterCommand -Command "/opt/vyatta/bin/vyatta-op-cmd-wrapper show queueing smart-queue" } catch {}
    if ((-not $filtered -or $filtered.Count -eq 0) -and [string]::IsNullOrWhiteSpace($runtime)) {
        return 'Nenhuma configuração QoS / Smart Queue encontrada.'
    }
    $parts = @()
    if ($filtered -and $filtered.Count -gt 0) {
        $parts += '=== CONFIGURAÇÃO ==='
        $parts += ($filtered -join "`r`n")
    }
    if (-not [string]::IsNullOrWhiteSpace($runtime)) {
        if ($parts.Count -gt 0) { $parts += '' }
        $parts += '=== STATUS / FILAS ==='
        $parts += $runtime
    }
    return ($parts -join "`r`n")
}

function Refresh-QosStatus {
    $overview = Get-QosOverview
    Set-OutputText -Target $txtQosOut -Content $overview -Title 'QoS / Smart Queue'
    $lines = Get-EdgeConfigLines
    $policy = $null
    $iface = $null
    $down = $null
    $up = $null
    foreach ($line in $lines) {
        if (-not $policy -and $line -match '^set traffic-control smart-queue ([^\s]+) ') { $policy = $matches[1] }
        if (-not $iface -and $line -match '^set traffic-control smart-queue ([^\s]+) wan-interface ([^\s]+)$') { $iface = $matches[2] }
        if (-not $down -and $line -match '^set traffic-control smart-queue ([^\s]+) download rate ([^\s]+)$') { $down = $matches[2] }
        if (-not $up -and $line -match '^set traffic-control smart-queue ([^\s]+) upload rate ([^\s]+)$') { $up = $matches[2] }
    }
    if ($policy) { $txtQosPolicy.Text = $policy }
    if ($iface) { $txtQosIface.Text = $iface }
    if ($down) { $txtQosDown.Text = ($down -replace 'mbit$','' -replace 'kbit$','') }
    if ($up) { $txtQosUp.Text = ($up -replace 'mbit$','' -replace 'kbit$','') }
    Sync-QosFriendlyFromTechnical
    Write-AppLog 'Leitura de QoS / Smart Queue executada.'
}

function Set-QosQuickProfile {
    param([string]$Profile)
    switch ($Profile) {
        'DEFAULT' {
            $txtQosPolicy.Text = 'SQ-WAN'
            $message = 'Perfil padrão carregado. Use os valores reais do seu link e aplique o Smart Queue.'
        }
        'CALLS' {
            $txtQosPolicy.Text = 'SQ-VOZ'
            $message = 'Perfil Voz / WhatsApp carregado. Este modo deixa o Smart Queue pronto para reduzir latência e bufferbloat em chamadas. Para amarrar um telefone, ATA ou PBX a uma WAN específica, use os atalhos de PBR.'
        }
        'MEET' {
            $txtQosPolicy.Text = 'SQ-REUNIOES'
            $message = 'Perfil Reuniões carregado. Ideal para Teams, Meet, Zoom e chamadas gerais, sempre usando os valores reais do link.'
        }
        'GAMES' {
            $txtQosPolicy.Text = 'SQ-JOGOS'
            $message = 'Perfil Jogos carregado. A ideia é a mesma: controlar latência com Smart Queue e depois, se quiser, prender um console ou PC a uma WAN via PBR.'
        }
        default {
            $message = 'Perfil rápido carregado.'
        }
    }
    Set-OutputText -Target $txtQosOut -Content $message -Title 'Perfil rápido QoS'
    Write-AppLog "Perfil rápido QoS carregado: $Profile"
}


function Get-QosFriendlyGoalKey {
    param([object]$SelectedItem)
    if ($null -eq $SelectedItem) { return 'BALANCED' }
    $txt = if ($SelectedItem -is [string]) { [string]$SelectedItem } else { [string]$SelectedItem.Content }
    switch ($txt) {
        'Internet equilibrada' { 'BALANCED' }
        'Balanced internet' { 'BALANCED' }
        'Chamadas / WhatsApp' { 'CALLS' }
        'Calls / WhatsApp' { 'CALLS' }
        'Reuniões' { 'MEET' }
        'Meetings' { 'MEET' }
        'Jogos' { 'GAMES' }
        'Games' { 'GAMES' }
        default { 'BALANCED' }
    }
}

function Get-QosFriendlyLevelFactor {
    param([object]$SelectedItem)
    if ($null -eq $SelectedItem) { return 0.94 }
    $txt = if ($SelectedItem -is [string]) { [string]$SelectedItem } else { [string]$SelectedItem.Content }
    switch ($txt) {
        'Leve' { 0.97 }
        'Light' { 0.97 }
        'Média' { 0.94 }
        'Medium' { 0.94 }
        'Forte' { 0.90 }
        'Strong' { 0.90 }
        default { 0.94 }
    }
}

function Get-QosFriendlyProfileInfo {
    param([string]$GoalKey)
    switch ($GoalKey) {
        'CALLS' { return @{ Policy='SQ-VOZ'; Title='Chamadas / WhatsApp'; Note='Pensado para chamadas e áudio em tempo real. Não identifica o aplicativo; apenas deixa a fila mais favorável para baixa latência.' } }
        'MEET' { return @{ Policy='SQ-REUNIOES'; Title='Reuniões'; Note='Bom para Teams, Meet, Zoom e uso de escritório, sempre com foco em estabilidade antes da velocidade máxima.' } }
        'GAMES' { return @{ Policy='SQ-JOGOS'; Title='Jogos'; Note='Busca reduzir variação de latência. Em console/PC, combine com PBR se quiser manter o dispositivo em uma WAN específica.' } }
        default { return @{ Policy='SQ-WAN'; Title='Internet equilibrada'; Note='Perfil geral para deixar o link mais estável sem complicar a configuração.' } }
    }
}

function Sync-QosFriendlyFromTechnical {
    try {
        if ($null -eq $cmbQosFriendlyGoal) { return }
        if ($txtQosIface -and $txtQosIface.Text) { $txtQosFriendlyIface.Text = $txtQosIface.Text }
        if ($txtQosDown -and $txtQosDown.Text) {
            $txtQosFriendlyDownReal.Text = $txtQosDown.Text
            $txtQosFriendlyDownApply.Text = $txtQosDown.Text
        }
        if ($txtQosUp -and $txtQosUp.Text) {
            $txtQosFriendlyUpReal.Text = $txtQosUp.Text
            $txtQosFriendlyUpApply.Text = $txtQosUp.Text
        }
        if ($txtQosPolicy -and $txtQosPolicy.Text) {
            $policy = $txtQosPolicy.Text.Trim().ToUpperInvariant()
            switch -Regex ($policy) {
                'VOZ|CALL' { $cmbQosFriendlyGoal.SelectedIndex = 1; break }
                'REUN' { $cmbQosFriendlyGoal.SelectedIndex = 2; break }
                'JOGO|GAME' { $cmbQosFriendlyGoal.SelectedIndex = 3; break }
                default { $cmbQosFriendlyGoal.SelectedIndex = 0; break }
            }
            $txtQosFriendlyPolicy.Text = $txtQosPolicy.Text.Trim()
        }
        Update-QosFriendlyPreview
    } catch {}
}

function Update-QosFriendlyPreview {
    try {
        if ($null -eq $txtQosFriendlyExplain) { return }
        $goalKey = Get-QosFriendlyGoalKey $cmbQosFriendlyGoal.SelectedItem
        $profile = Get-QosFriendlyProfileInfo $goalKey
        $factor = Get-QosFriendlyLevelFactor $cmbQosFriendlyLevel.SelectedItem
        $txtQosFriendlyPolicy.Text = $profile.Policy

        $downRaw = ($txtQosFriendlyDownReal.Text.Trim() -replace ',','.')
        $upRaw = ($txtQosFriendlyUpReal.Text.Trim() -replace ',','.')
        $downNum = 0.0
        $upNum = 0.0
        [double]::TryParse($downRaw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$downNum) | Out-Null
        [double]::TryParse($upRaw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$upNum) | Out-Null
        if ($downNum -gt 0) { $txtQosFriendlyDownApply.Text = [string][math]::Round($downNum * $factor, 0) } else { $txtQosFriendlyDownApply.Text = '' }
        if ($upNum -gt 0) { $txtQosFriendlyUpApply.Text = [string][math]::Round($upNum * $factor, 0) } else { $txtQosFriendlyUpApply.Text = '' }

        $levelTxt = if ($cmbQosFriendlyLevel.SelectedItem) { [string]$cmbQosFriendlyLevel.SelectedItem.Content } else { 'Média' }
        $ifaceTxt = $txtQosFriendlyIface.Text.Trim()
        $explain = @()
        $explain += "Perfil: $($profile.Title)"
        if ($ifaceTxt) { $explain += "WAN: $ifaceTxt" }
        if ($txtQosFriendlyDownApply.Text) { $explain += "Download a aplicar: $($txtQosFriendlyDownApply.Text) Mbit" }
        if ($txtQosFriendlyUpApply.Text) { $explain += "Upload a aplicar: $($txtQosFriendlyUpApply.Text) Mbit" }
        $explain += "Intensidade: $levelTxt"
        $explain += ''
        $explain += $profile.Note
        $explain += 'Regra simples: use a velocidade real do link e deixe o app aplicar um pouco abaixo. Isso ajuda o roteador a organizar a fila.'
        $txtQosFriendlyExplain.Text = ($explain -join "`r`n")
    } catch {}
}

function Invoke-QosFriendlyApply {
    Update-QosFriendlyPreview
    $iface = $txtQosFriendlyIface.Text.Trim()
    $policy = $txtQosFriendlyPolicy.Text.Trim()
    $down = $txtQosFriendlyDownApply.Text.Trim()
    $up = $txtQosFriendlyUpApply.Text.Trim()
    if (-not $iface -or -not $policy -or -not $down -or -not $up) { throw 'Preencha WAN e velocidades reais para calcular os valores do QoS.' }
    $txtQosPolicy.Text = $policy
    $txtQosIface.Text = $iface
    $txtQosDown.Text = $down
    $txtQosUp.Text = $up
    if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 }
    $btnQosApply.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
}

function Invoke-QosFriendlyRemove {
    $policy = $txtQosFriendlyPolicy.Text.Trim()
    if (-not $policy) { $policy = $txtQosPolicy.Text.Trim() }
    if (-not $policy) { throw 'Não há política QoS informada para remover.' }
    $txtQosPolicy.Text = $policy
    if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 }
    $btnQosRemove.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
}


function Get-InterfacePathParts {
    param([string]$Interface)
    if ([string]::IsNullOrWhiteSpace($Interface)) { throw 'Interface vazia.' }
    $name = $Interface.Trim()
    if ($name -match '^eth') { return @('ethernet', $name) }
    if ($name -match '^switch') { return @('switch', $name) }
    if ($name -match '^pppoe') { return @('pppoe', $name) }
    return @('ethernet', $name)
}

function Get-QosDevicePolicyToken {
    param([string]$IpAddress)
    return (($IpAddress.Trim() -replace '[^0-9A-Za-z]+','-').ToUpperInvariant())
}

function Test-MbitValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return ($Value.Trim() -match '^\d+(\.\d+)?$')
}

function Get-QosAdvancedDescription {
    param(
        [string]$Direction,
        [string]$IpAddress,
        [string]$Note
    )
    $noteNorm = Normalize-EdgeName -Value $Note -Default 'device_limit'
    return "DEVAQ $Direction $IpAddress $noteNorm"
}

function Get-QosDeviceQueueTypeNames {
    param([string]$IpAddress)
    $token = Get-QosDevicePolicyToken -IpAddress $IpAddress
    return @{
        Down = "DEVAQ-D-$token"
        Up = "DEVAQ-U-$token"
    }
}

function Get-QosDeviceAdvancedState {
    $cfg = Get-EdgeConfigCommandsText
    $state = [ordered]@{
        RootBandwidth = ''
        TotalDown = ''
        TotalUp = ''
        UsedLeafIds = @()
        UsedFilterIds = @()
        Entries = @{}
        ForeignLines = (New-Object System.Collections.ArrayList)
        HasAdvanced = $false
        HasForeignAdvanced = $false
    }

    $queueMeta = @{}
    $queueBandwidth = @{}
    $filterMeta = @{}
    $filterTarget = @{}
    $advLines = @()

    $queueTypeRates = @{}
    foreach ($line in ($cfg -split "`r?`n")) {
        if ($line -match '^set traffic-control advanced-queue ') {
            $state.HasAdvanced = $true
            $advLines += $line
        }
        if ($line -match '^set traffic-control advanced-queue root queue 1 bandwidth (\S+)$') {
            $state.RootBandwidth = ($matches[1] -replace 'mbit$','')
            continue
        }
        if ($line -match '^set traffic-control advanced-queue branch queue 10 bandwidth (\S+)$') {
            $state.TotalDown = ($matches[1] -replace 'mbit$','')
            continue
        }
        if ($line -match '^set traffic-control advanced-queue branch queue 20 bandwidth (\S+)$') {
            $state.TotalUp = ($matches[1] -replace 'mbit$','')
            continue
        }
        if ($line -match '^set traffic-control advanced-queue leaf queue (\d+) ') {
            $state.UsedLeafIds += [int]$matches[1]
        }
        if ($line -match '^set traffic-control advanced-queue filters match (\d+) ') {
            $state.UsedFilterIds += [int]$matches[1]
        }
        if ($line -match "^set traffic-control advanced-queue leaf queue (\d+) description '?DEVAQ (DOWN|UP) ([0-9.]+)(?: ([A-Za-z0-9._-]+))?'?$") {
            $queueMeta[[int]$matches[1]] = [ordered]@{ Direction = $matches[2]; IP = $matches[3]; Note = $matches[4] }
            continue
        }
        if ($line -match '^set traffic-control advanced-queue leaf queue (\d+) bandwidth (\S+)$') {
            $queueBandwidth[[int]$matches[1]] = ($matches[2] -replace 'mbit$','')
            continue
        }
        if ($line -match "^set traffic-control advanced-queue filters match (\d+) description '?DEVAQ (DOWN|UP) ([0-9.]+)(?: ([A-Za-z0-9._-]+))?'?$") {
            $filterMeta[[int]$matches[1]] = [ordered]@{ Direction = $matches[2]; IP = $matches[3]; Note = $matches[4] }
            continue
        }
        if ($line -match "^set traffic-control advanced-queue filters match (\d+) description '?DEVAQ ROOT (DOWN|UP) ([0-9.]+)(?: ([A-Za-z0-9._-]+))?'?$") {
            $filterMeta[[int]$matches[1]] = [ordered]@{ Direction = ('ROOT_' + $matches[2]); IP = $matches[3]; Note = $matches[4] }
            continue
        }
        if ($line -match '^set traffic-control advanced-queue filters match (\d+) target (\d+)$') {
            $filterTarget[[int]$matches[1]] = [int]$matches[2]
            continue
        }
        if ($line -match '^set traffic-control advanced-queue queue-type hfq (DEVAQ-[DU]-[A-Z0-9\-]+) max-rate (\S+)$') {
            $queueTypeRates[$matches[1]] = ($matches[2] -replace 'mbit$','')
            continue
        }
    }

    foreach ($line in $advLines) {
        if ($line -match '^set traffic-control advanced-queue (root|branch|leaf|filters|queue-type)$') { continue }
        if ($line -match '^set traffic-control advanced-queue root queue 1 attach-to global$') { continue }
        if ($line -match '^set traffic-control advanced-queue root queue 1 bandwidth \S+$') { continue }
        if ($line -match '^set traffic-control advanced-queue root queue 1 description DEVAQ_ROOT$') { continue }
        if ($line -match '^set traffic-control advanced-queue root queue 1 default queue \d+$') { continue }
        if ($line -match '^set traffic-control advanced-queue branch queue 10 (bandwidth \S+|description DEVAQ_DOWNLOAD|parent 1|default queue \d+)$') { continue }
        if ($line -match '^set traffic-control advanced-queue branch queue 20 (bandwidth \S+|description DEVAQ_UPLOAD|parent 1|default queue \d+)$') { continue }
        if ($line -match "^set traffic-control advanced-queue leaf queue \d+ (bandwidth \S+|description '?DEVAQ (DOWN|UP) [0-9.]+(?: [A-Za-z0-9._-]+)?'?|parent (10|20)|queue-type DEVAQ-[DU]-[A-Z0-9\-]+)$") { continue }
        if ($line -match '^set traffic-control advanced-queue queue-type hfq DEVAQ-[DU]-[A-Z0-9\-]+ (host-identifier (dip|sip)|max-rate \S+|subnet \S+)$') { continue }
        if ($line -match "^set traffic-control advanced-queue filters match \d+ (attach-to (1|10|20)|description '?DEVAQ( ROOT)? (DOWN|UP) [0-9.]+(?: [A-Za-z0-9._-]+)?'?|ip (source|destination) address \S+|target \d+)$") { continue }
        $state.HasForeignAdvanced = $true
        [void]$state.ForeignLines.Add($line)
    }

    foreach ($qid in ($queueMeta.Keys | Sort-Object)) {
        $meta = $queueMeta[$qid]
        $ip = $meta.IP
        if (-not $state.Entries.ContainsKey($ip)) {
            $state.Entries[$ip] = [ordered]@{
                IP = $ip
                Download = ''
                Upload = ''
                TotalDown = $state.TotalDown
                TotalUp = $state.TotalUp
                DownQueue = ''
                UpQueue = ''
                DownFilter = ''
                UpFilter = ''
                DownRootFilter = ''
                UpRootFilter = ''
                Note = ''
            }
        }
        $qtNames = Get-QosDeviceQueueTypeNames -IpAddress $ip
        if ($meta.Direction -eq 'DOWN') {
            $state.Entries[$ip].DownQueue = $qid
            if ($queueTypeRates.ContainsKey($qtNames.Down)) { $state.Entries[$ip].Download = $queueTypeRates[$qtNames.Down] }
            elseif ($queueBandwidth.ContainsKey($qid)) { $state.Entries[$ip].Download = $queueBandwidth[$qid] }
        } else {
            $state.Entries[$ip].UpQueue = $qid
            if ($queueTypeRates.ContainsKey($qtNames.Up)) { $state.Entries[$ip].Upload = $queueTypeRates[$qtNames.Up] }
            elseif ($queueBandwidth.ContainsKey($qid)) { $state.Entries[$ip].Upload = $queueBandwidth[$qid] }
        }
        if (-not [string]::IsNullOrWhiteSpace($meta.Note)) { $state.Entries[$ip].Note = $meta.Note }
    }

    foreach ($fid in ($filterMeta.Keys | Sort-Object)) {
        $meta = $filterMeta[$fid]
        $ip = $meta.IP
        if (-not $state.Entries.ContainsKey($ip)) {
            $state.Entries[$ip] = [ordered]@{
                IP = $ip
                Download = ''
                Upload = ''
                TotalDown = $state.TotalDown
                TotalUp = $state.TotalUp
                DownQueue = ''
                UpQueue = ''
                DownFilter = ''
                UpFilter = ''
                DownRootFilter = ''
                UpRootFilter = ''
                Note = ''
            }
        }
        switch ($meta.Direction) {
            'DOWN' { $state.Entries[$ip].DownFilter = $fid }
            'UP' { $state.Entries[$ip].UpFilter = $fid }
            'ROOT_DOWN' { $state.Entries[$ip].DownRootFilter = $fid }
            'ROOT_UP' { $state.Entries[$ip].UpRootFilter = $fid }
        }
        if (-not [string]::IsNullOrWhiteSpace($meta.Note)) { $state.Entries[$ip].Note = $meta.Note }
        if ($filterTarget.ContainsKey($fid)) {
            if ($meta.Direction -eq 'DOWN' -and -not $state.Entries[$ip].DownQueue) { $state.Entries[$ip].DownQueue = $filterTarget[$fid] }
            if ($meta.Direction -eq 'UP' -and -not $state.Entries[$ip].UpQueue) { $state.Entries[$ip].UpQueue = $filterTarget[$fid] }
        }
    }

    return $state
}

function Get-QosDevicePolicies {
    $state = Get-QosDeviceAdvancedState
    $items = New-Object System.Collections.ArrayList
    foreach ($key in ($state.Entries.Keys | Sort-Object)) {
        [void]$items.Add([pscustomobject]$state.Entries[$key])
    }
    return @($items)
}

function Refresh-QosDevicePolicies {
    $state = Get-QosDeviceAdvancedState
    $items = @(Get-QosDevicePolicies)
    $dgQosDevicePolicies.ItemsSource = $items
    if ($items.Count -eq 0) {
        $summary = "Nenhum limite por dispositivo encontrado.`r`n`r`nEste modo usa Advanced Queue global para limitar upload e download por IP."
        if ($state.HasForeignAdvanced -and $state.ForeignLines.Count -gt 0) {
            $summary += "`r`n`r`nLinhas Advanced Queue não reconhecidas pelo app:`r`n" + (($state.ForeignLines | Select-Object -First 8) -join "`r`n")
        }
        Set-OutputText -Target $txtQosOut -Content $summary -Title 'QoS por dispositivo'
        Write-AppLog 'Nenhum limite por dispositivo encontrado.'
    } else {
        $summary = @(
            "Modo: Advanced Queue global por IP",
            "Políticas encontradas: $($items.Count)",
            "Banda total download: $($state.TotalDown)",
            "Banda total upload: $($state.TotalUp)"
        ) -join "`r`n"
        Set-OutputText -Target $txtQosOut -Content $summary -Title 'QoS por dispositivo'
        Write-AppLog "Limites por dispositivo carregados: $($items.Count)"
    }
}

function Get-OnlineClientsSnapshot {
    $leaseByIp = @{}
    $leaseByMac = @{}
    foreach ($line in (Get-DhcpLeaseLines)) {
        $lease = Parse-DhcpLeaseDisplayLine -Line $line -Source 'dynamic'
        if (-not $lease) { continue }
        if ($lease.IP) { $leaseByIp[$lease.IP] = $lease }
        if ($lease.MAC) { $leaseByMac[$lease.MAC.ToLowerInvariant()] = $lease }
    }

    foreach ($map in (Get-DhcpStaticMappings)) {
        if ($map.IP -and -not $leaseByIp.ContainsKey($map.IP)) {
            $leaseByIp[$map.IP] = [pscustomobject]@{ IP=$map.IP; MAC=$map.MAC; Host=$map.Name; RawLine=''; Source='reserved' }
        }
        if ($map.MAC) {
            $macKey = $map.MAC.ToLowerInvariant()
            if (-not $leaseByMac.ContainsKey($macKey)) {
                $leaseByMac[$macKey] = [pscustomobject]@{ IP=$map.IP; MAC=$map.MAC; Host=$map.Name; RawLine=''; Source='reserved' }
            }
        }
    }

    $candidateIps = New-Object System.Collections.ArrayList
    foreach ($ipAddr in $leaseByIp.Keys) {
        if ((Test-IPv4Address $ipAddr) -and -not ($candidateIps -contains $ipAddr)) { [void]$candidateIps.Add($ipAddr) }
    }

    $commands = New-Object System.Collections.ArrayList
    if ($candidateIps.Count -gt 0) {
        $ipList = ($candidateIps | ForEach-Object { [string]$_ }) -join ' '
        if (-not [string]::IsNullOrWhiteSpace($ipList)) {
            [void]$commands.Add("for ip in $ipList; do ping -c 1 -W 1 `$ip >/dev/null 2>&1 & done; wait")
        }
    }
    [void]$commands.Add('ip neigh')
    [void]$commands.Add('/opt/vyatta/bin/vyatta-op-cmd-wrapper show arp')
    $raw = Invoke-EdgeRouterCommand -Command ($commands -join '; ')

    $items = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($line in ($raw -split "`r?`n")) {
        $trim = $line.Trim()
        if (-not $trim) { continue }

        $ipAddr = $null
        $macAddr = $null
        $state = ''
        $ifaceName = ''

        if ($trim -match '^(?<ip>\d{1,3}(?:\.\d{1,3}){3})\s+dev\s+(?<iface>\S+)\s+lladdr\s+(?<mac>(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2})(?:\s+\S+)*\s+(?<state>[A-Z]+)$') {
            $ipAddr = $matches['ip']
            $ifaceName = $matches['iface']
            $macAddr = $matches['mac'].ToLowerInvariant()
            $state = $matches['state']
        }
        elseif ($trim -match '^(?<ip>\d{1,3}(?:\.\d{1,3}){3})\s+\S+\s+(?<mac>(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2})\s+\S+\s+\S+\s+(?<iface>\S+)$') {
            $ipAddr = $matches['ip']
            $ifaceName = $matches['iface']
            $macAddr = $matches['mac'].ToLowerInvariant()
            $state = 'ARP'
        }

        if (-not $ipAddr -or -not $macAddr) { continue }
        if ($trim -match '(?i)\bFAILED\b|\bINCOMPLETE\b') { continue }

        $name = ''
        if ($leaseByIp.ContainsKey($ipAddr)) { $name = [string]$leaseByIp[$ipAddr].Host }
        if ([string]::IsNullOrWhiteSpace($name) -and $leaseByMac.ContainsKey($macAddr)) { $name = [string]$leaseByMac[$macAddr].Host }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '-' }

        $key = "$ipAddr|$macAddr"
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        [void]$items.Add([pscustomobject]@{
            IP = $ipAddr
            MAC = $macAddr
            Nome = $name
            Estado = $state
            Interface = $ifaceName
        })
    }

    return @($items | Sort-Object @{Expression={ try { [version]$_.IP } catch { [version]'0.0.0.0' } }}, Interface)
}

function Show-QosOnlineClients {
    $items = @(Get-OnlineClientsSnapshot)
    if (-not $items -or $items.Count -eq 0) {
        $msg = "Nenhum cliente online foi encontrado na tabela ARP/neigh neste momento.`r`n`r`nDica: gere tráfego dos dispositivos e tente novamente."
        Set-OutputText -Target $txtQosOut -Content $msg -Title 'Clientes online agora'
        Write-AppLog 'Nenhum cliente online encontrado para a aba QoS.'
        return
    }

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(("{0,-15}  {1,-17}  {2,-28}  {3,-10}  {4}" -f 'IP','MAC','NOME','ESTADO','IFACE'))
    [void]$lines.Add(("{0,-15}  {1,-17}  {2,-28}  {3,-10}  {4}" -f ('-'*15),('-'*17),('-'*28),('-'*10),('-'*8)))
    foreach ($item in $items) {
        [void]$lines.Add(("{0,-15}  {1,-17}  {2,-28}  {3,-10}  {4}" -f $item.IP,$item.MAC,$item.Nome,$item.Estado,$item.Interface))
    }
    Set-OutputText -Target $txtQosOut -Content ($lines -join "`r`n") -Title 'Clientes online agora'
    Write-AppLog "Clientes online listados na aba QoS: $($items.Count)"
}


function Convert-IPv4ToUInt32 {
    param([string]$IPAddress)
    if (-not (Test-IPv4Address $IPAddress)) { throw "IP inválido: $IPAddress" }
    $bytes = [System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()
    [array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Test-IPv4InCidr {
    param(
        [string]$IPAddress,
        [string]$Cidr
    )
    if (-not (Test-IPv4Address $IPAddress)) { return $false }
    if ($Cidr -notmatch '^(\d{1,3}(?:\.\d{1,3}){3})\/(\d{1,2})$') { return $false }
    $network = $matches[1]
    $prefix = [int]$matches[2]
    if ($prefix -lt 0 -or $prefix -gt 32) { return $false }
    $ipUint = Convert-IPv4ToUInt32 -IPAddress $IPAddress
    $netUint = Convert-IPv4ToUInt32 -IPAddress $network
    if ($prefix -eq 0) { return $true }
    if ($prefix -eq 32) {
        $mask = [uint32]4294967295
    } else {
        $maskCalc = ([uint64][math]::Pow(2, $prefix) - 1) * [uint64][math]::Pow(2, (32 - $prefix))
        $mask = [uint32]$maskCalc
    }
    return (($ipUint -band $mask) -eq ($netUint -band $mask))
}

function Get-LanInterfaceForCurrentRouter {
    $cfgLines = Get-EdgeConfigLines
    $routerIp = $txtIp.Text.Trim()
    $candidates = New-Object System.Collections.ArrayList
    foreach ($line in $cfgLines) {
        if ($line -match '^set interfaces (switch|ethernet) (\S+) address (\d{1,3}(?:\.\d{1,3}){3}\/\d{1,2})$') {
            $ifaceName = $matches[2]
            $cidr = $matches[3]
            if ($routerIp -and (Test-IPv4InCidr -IPAddress $routerIp -Cidr $cidr)) { return $ifaceName }
            if ($ifaceName -eq 'switch0') {
                if ($candidates -notcontains $ifaceName) { [void]$candidates.Add($ifaceName) }
                continue
            }
            if ($cidr -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)') {
                if ($candidates -notcontains $ifaceName) { [void]$candidates.Add($ifaceName) }
            }
        }
    }
    if ($candidates.Count -gt 0) { return [string]$candidates[0] }
    return 'switch0'
}

function Get-LanInboundFirewallRuleset {
    param([string]$Interface)
    $cfgLines = Get-EdgeConfigLines
    $esc = [regex]::Escape($Interface)
    foreach ($line in $cfgLines) {
        if ($line -match "^set interfaces (switch|ethernet) $esc firewall in name (\S+)$") { return $matches[2] }
    }
    return ''
}

function Get-NextFirewallRuleId {
    param(
        [string]$Ruleset,
        [int]$Start = 5000,
        [int]$End = 5999
    )
    $cfgLines = Get-EdgeConfigLines
    $ids = New-Object System.Collections.ArrayList
    $esc = [regex]::Escape($Ruleset)
    foreach ($line in $cfgLines) {
        if ($line -match "^set firewall name $esc rule (\d+) ") {
            [void]$ids.Add([int]$matches[1])
        }
    }
    return Get-NextFreeNumericId -UsedIds @($ids) -Start $Start -End $End
}

function Get-P2PBlockEntries {
    $cfgLines = Get-EdgeConfigLines
    $map = @{}
    foreach ($line in $cfgLines) {
        if ($line -match "^set firewall name (\S+) rule (\d+) description '?APP_P2P_BLOCK_(\d{1,3}(?:\.\d{1,3}){3})'?$") {
            $key = "$($matches[1])|$($matches[2])"
            if (-not $map.ContainsKey($key)) {
                $map[$key] = [ordered]@{
                    Ruleset = $matches[1]
                    Rule    = [int]$matches[2]
                    IP      = $matches[3]
                    Source  = ''
                    Action  = ''
                    Category= ''
                    Description = "APP_P2P_BLOCK_$($matches[3])"
                }
            }
            continue
        }
        if ($line -match '^set firewall name (\S+) rule (\d+) source address (\d{1,3}(?:\.\d{1,3}){3})$') {
            $key = "$($matches[1])|$($matches[2])"
            if ($map.ContainsKey($key)) { $map[$key].Source = $matches[3] }
            continue
        }
        if ($line -match '^set firewall name (\S+) rule (\d+) action (\S+)$') {
            $key = "$($matches[1])|$($matches[2])"
            if ($map.ContainsKey($key)) { $map[$key].Action = $matches[3] }
            continue
        }
        if ($line -match '^set firewall name (\S+) rule (\d+) application category (\S+)$') {
            $key = "$($matches[1])|$($matches[2])"
            if ($map.ContainsKey($key)) { $map[$key].Category = $matches[3] }
            continue
        }
    }
    $items = New-Object System.Collections.ArrayList
    foreach ($key in ($map.Keys | Sort-Object)) {
        $obj = [pscustomobject]$map[$key]
        if (-not $obj.IP -and $obj.Source) { $obj.IP = $obj.Source }
        [void]$items.Add($obj)
    }
    return @($items)
}

function Get-P2PBlocksOverview {
    $items = @(Get-P2PBlockEntries)
    if ($items.Count -eq 0) { return 'Nenhum bloqueio P2P/Torrent encontrado.' }
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(('Total de bloqueios: {0}' -f $items.Count))
    [void]$lines.Add('')
    [void]$lines.Add(('{0,-18}  {1,-8}  {2,-12}  {3}' -f 'IP','REGRA','RULESET','CATEGORIA'))
    [void]$lines.Add(('{0,-18}  {1,-8}  {2,-12}  {3}' -f ('-'*18),('-'*8),('-'*12),('-'*9)))
    foreach ($item in $items) {
        [void]$lines.Add(('{0,-18}  {1,-8}  {2,-12}  {3}' -f $item.IP,$item.Rule,$item.Ruleset,$item.Category))
    }
    return ($lines -join "`r`n")
}

function Refresh-P2PBlocks {
    $content = Get-P2PBlocksOverview
    Set-OutputText -Target $txtQosOut -Content $content -Title 'Bloqueios P2P/Torrent'
    $count = @(Get-P2PBlockEntries).Count
    Write-AppLog "Bloqueios P2P/Torrent lidos: $count"
}

function Apply-P2PBlockForDevice {
    $ipDev = $txtQosDevIp.Text.Trim()
    if (-not (Test-IPv4Address $ipDev)) { throw 'Informe um IP interno válido para bloquear P2P/Torrent.' }
    $lanIf = Get-LanInterfaceForCurrentRouter
    if ([string]::IsNullOrWhiteSpace($lanIf)) { throw 'Não foi possível detectar a interface LAN para aplicar o bloqueio DPI.' }
    $attachedRuleset = Get-LanInboundFirewallRuleset -Interface $lanIf
    $ruleset = if ([string]::IsNullOrWhiteSpace($attachedRuleset)) { 'DPI_P2P_APP' } else { $attachedRuleset }
    $existing = @(Get-P2PBlockEntries | Where-Object { $_.IP -eq $ipDev })
    $ruleId = if ($existing.Count -gt 0) { [int]$existing[0].Rule } else { Get-NextFirewallRuleId -Ruleset $ruleset -Start 5000 -End 5999 }
    $desc = "APP_P2P_BLOCK_$ipDev"
    $parts = Get-InterfacePathParts -Interface $lanIf
    $ifaceType = $parts[0]
    $ifaceName = $parts[1]

    $cmds = @(
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system traffic-analysis dpi enable',
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system traffic-analysis export enable'
    )
    foreach ($entry in $existing) {
        $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall name $($entry.Ruleset) rule $($entry.Rule)"
    }
    if ([string]::IsNullOrWhiteSpace($attachedRuleset)) {
        $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset default-action accept"
        $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set interfaces $ifaceType $ifaceName firewall in name $ruleset"
    }
    $cmds += @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset rule $ruleId description '$desc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset rule $ruleId action drop",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset rule $ruleId source address $ipDev",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset rule $ruleId application category P2P",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall name $ruleset rule $ruleId log enable"
    )
    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "P2P_BLOCK_${ipDev}"
    $script:ConfigCommandsCache = $null
    $summary = @(
        "Interface LAN: $lanIf",
        "Ruleset: $ruleset",
        "Regra: $ruleId",
        "IP bloqueado: $ipDev",
        "Categoria DPI: P2P",
        '',
        'Saída do roteador:',
        $out,
        '',
        'Bloqueios atuais:',
        (Get-P2PBlocksOverview)
    ) -join "`r`n"
    Set-OutputText -Target $txtQosOut -Content $summary -Title 'Bloqueio P2P/Torrent por IP (DPI)'
    Write-AppLog "Bloqueio P2P/Torrent aplicado para ${ipDev} no ruleset ${ruleset}, regra $ruleId"
}

function Remove-P2PBlockForDevice {
    $ipDev = $txtQosDevIp.Text.Trim()
    if (-not (Test-IPv4Address $ipDev)) { throw 'Informe o IP interno para remover o bloqueio P2P/Torrent.' }
    $entries = @(Get-P2PBlockEntries | Where-Object { $_.IP -eq $ipDev })
    if ($entries.Count -eq 0) { throw 'Não há bloqueio P2P/Torrent criado pelo app para este IP.' }
    $cmds = @()
    foreach ($entry in $entries) {
        $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall name $($entry.Ruleset) rule $($entry.Rule)"
    }
    $lanIf = Get-LanInterfaceForCurrentRouter
    $parts = Get-InterfacePathParts -Interface $lanIf
    $ifaceType = $parts[0]
    $ifaceName = $parts[1]
    $cfgLines = Get-EdgeConfigLines
    $hasOtherAppRules = @($cfgLines | Where-Object { $_ -match '^set firewall name DPI_P2P_APP rule \d+ ' -and $_ -notmatch [regex]::Escape($ipDev) }).Count -gt 0
    $hasAppRuleset = @($cfgLines | Where-Object { $_ -match '^set firewall name DPI_P2P_APP ' -or $_ -match '^set interfaces (switch|ethernet) \S+ firewall in name DPI_P2P_APP$' }).Count -gt 0
    if ((-not $hasOtherAppRules) -and $hasAppRuleset) {
        $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete interfaces $ifaceType $ifaceName firewall in name DPI_P2P_APP"
        $cmds += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall name DPI_P2P_APP'
    }
    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "P2P_UNBLOCK_${ipDev}"
    $script:ConfigCommandsCache = $null
    $summary = @(
        $out,
        '',
        'Bloqueios atuais:',
        (Get-P2PBlocksOverview)
    ) -join "`r`n"
    Set-OutputText -Target $txtQosOut -Content $summary -Title 'Bloqueio P2P/Torrent removido'
    Write-AppLog "Bloqueio P2P/Torrent removido para ${ipDev}"
}

function Get-NextFreeNumericId {
    param(
        [int[]]$UsedIds,
        [int]$Start,
        [int]$End
    )
    $used = @($UsedIds | Sort-Object -Unique)
    for ($i = $Start; $i -le $End; $i++) {
        if ($used -notcontains $i) { return $i }
    }
    throw "Não há IDs livres entre $Start e $End para criar a política."
}

function Clear-QosDeviceAppAdvancedInfrastructure {
    $cfgLines = Get-EdgeConfigLines
    $cmds = @()

    foreach ($line in $cfgLines) {
        if ($line -match '^set traffic-control advanced-queue filters match (\d+) description ''?DEVAQ') {
            $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue filters match $($matches[1])"
        }
        elseif ($line -match '^set traffic-control advanced-queue leaf queue (\d+) description ''?DEVAQ') {
            $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue leaf queue $($matches[1])"
        }
        elseif ($line -match '^set traffic-control advanced-queue queue-type hfq (DEVAQ-[DU]-[A-Z0-9\-]+) ') {
            $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue queue-type hfq $($matches[1])"
        }
    }

    $cmds += @(
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue branch queue 10',
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue branch queue 20',
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue root queue 1'
    )

    $cmds = @($cmds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($cmds.Count -gt 0) {
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason 'QOS_DEVICE_AQ_CLEAN_INFRA'
        Write-AppLog 'Infraestrutura Advanced Queue do app foi limpa para reaplicar o limite por dispositivo.'
        return $out
    }
    return ''
}

function Invoke-QosDeviceLimitApply {
    $ipDev = $txtQosDevIp.Text.Trim()
    $downLimit = $txtQosDevDown.Text.Trim()
    $upLimit = $txtQosDevUp.Text.Trim()
    $totalDown = $txtQosDevTotalDown.Text.Trim()
    $totalUp = $txtQosDevTotalUp.Text.Trim()
    $note = Normalize-EdgeName -Value $txtQosDevNote.Text.Trim() -Default 'device_limit'

    if (-not (Test-IPv4Address $ipDev)) { throw 'IP interno inválido.' }
    foreach ($v in @($downLimit,$upLimit,$totalDown,$totalUp)) {
        if (-not (Test-MbitValue $v)) { throw 'Preencha limites e banda total com números válidos.' }
    }
    if ([double]$downLimit -gt [double]$totalDown) { throw 'O limite de download não pode ser maior que a banda total de download.' }
    if ([double]$upLimit -gt [double]$totalUp) { throw 'O limite de upload não pode ser maior que a banda total de upload.' }

    $cfgLines = Get-EdgeConfigLines
    if ($cfgLines | Where-Object { $_ -match '^set traffic-control smart-queue ' }) { throw 'Remova o Smart Queue antes de usar limite por dispositivo.' }

    $state = Get-QosDeviceAdvancedState
    if ($state.HasForeignAdvanced) {
        $foreignOnlyInfrastructure = ($state.Entries.Count -eq 0 -and $state.ForeignLines.Count -gt 0 -and @($state.ForeignLines | Where-Object { $_ -notmatch '^set traffic-control advanced-queue ((root|branch|leaf|filters|queue-type)|root queue 1 default queue \d+|branch queue (10|20) default queue \d+)$' }).Count -eq 0)
        $looksLikeOrphanAppState = ($state.Entries.Count -eq 0 -and (@(Get-EdgeConfigLines) | Where-Object { $_ -match 'DEVAQ' }).Count -gt 0)
        if ($foreignOnlyInfrastructure -or $looksLikeOrphanAppState) {
            $cleanupOut = Clear-QosDeviceAppAdvancedInfrastructure
            if (-not [string]::IsNullOrWhiteSpace($cleanupOut)) {
                Set-OutputText -Target $txtQosOut -Content $cleanupOut -Title 'Infraestrutura QoS limpa'
            }
            $script:ConfigCommandsCache = $null
            $state = Get-QosDeviceAdvancedState
        }
    }
    if ($state.HasForeignAdvanced) {
        $details = if ($state.ForeignLines.Count -gt 0) { "`r`n`r`nLinhas detectadas:`r`n" + (($state.ForeignLines | Select-Object -First 8) -join "`r`n") } else { '' }
        throw ('Já existe um Advanced Queue que não foi criado por este app. Remova-o antes de usar este modo.' + $details)
    }

    $existing = $null
    if ($state.Entries.ContainsKey($ipDev)) { $existing = [pscustomobject]$state.Entries[$ipDev] }

    $usedLeaf = @($state.UsedLeafIds | Sort-Object -Unique)
    $usedFilter = @($state.UsedFilterIds | Sort-Object -Unique)

    foreach ($id in @($existing.DownQueue,$existing.UpQueue)) {
        if ($id) { $usedLeaf = @($usedLeaf | Where-Object { $_ -ne [int]$id }) }
    }
    foreach ($id in @($existing.DownFilter,$existing.UpFilter,$existing.DownRootFilter,$existing.UpRootFilter)) {
        if ($id) { $usedFilter = @($usedFilter | Where-Object { $_ -ne [int]$id }) }
    }

    $downQueue = if ($existing -and $existing.DownQueue) { [int]$existing.DownQueue } else { Get-NextFreeNumericId -UsedIds $usedLeaf -Start 300 -End 499 }
    $upQueue = if ($existing -and $existing.UpQueue) { [int]$existing.UpQueue } else { Get-NextFreeNumericId -UsedIds (@($usedLeaf + $downQueue)) -Start 500 -End 699 }
    $downRootFilter = if ($existing -and $existing.DownRootFilter) { [int]$existing.DownRootFilter } else { Get-NextFreeNumericId -UsedIds $usedFilter -Start 100 -End 199 }
    $upRootFilter = if ($existing -and $existing.UpRootFilter) { [int]$existing.UpRootFilter } else { Get-NextFreeNumericId -UsedIds (@($usedFilter + $downRootFilter)) -Start 200 -End 299 }
    $downFilter = if ($existing -and $existing.DownFilter) { [int]$existing.DownFilter } else { Get-NextFreeNumericId -UsedIds (@($usedFilter + $downRootFilter + $upRootFilter)) -Start 300 -End 499 }
    $upFilter = if ($existing -and $existing.UpFilter) { [int]$existing.UpFilter } else { Get-NextFreeNumericId -UsedIds (@($usedFilter + $downRootFilter + $upRootFilter + $downFilter)) -Start 500 -End 699 }

    $rootBandwidth = [math]::Ceiling(([double]$totalDown) + ([double]$totalUp))
    $ipParts = $ipDev.Split('.')
    $subnet24 = if ($ipParts.Count -eq 4) { '{0}.{1}.{2}.0/24' -f $ipParts[0],$ipParts[1],$ipParts[2] } else { $ipDev + '/32' }
    $downDesc = Get-QosAdvancedDescription -Direction 'DOWN' -IpAddress $ipDev -Note $note
    $upDesc = Get-QosAdvancedDescription -Direction 'UP' -IpAddress $ipDev -Note $note
    $queueTypes = Get-QosDeviceQueueTypeNames -IpAddress $ipDev

    $cmds = @()
    if ($existing) {
        foreach ($id in @($existing.DownFilter,$existing.UpFilter,$existing.DownRootFilter,$existing.UpRootFilter)) {
            if ($id) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue filters match $id" }
        }
        foreach ($id in @($existing.DownQueue,$existing.UpQueue)) {
            if ($id) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue leaf queue $id" }
        }
    }

    $cmds += @(
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue root queue 1 attach-to global',
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue root queue 1 bandwidth ${rootBandwidth}mbit",
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue root queue 1 description DEVAQ_ROOT',
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 10 bandwidth ${totalDown}mbit",
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 10 description DEVAQ_DOWNLOAD',
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 10 parent 1',
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 20 bandwidth ${totalUp}mbit",
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 20 description DEVAQ_UPLOAD',
        '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue branch queue 20 parent 1',
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downRootFilter attach-to 1",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downRootFilter description 'DEVAQ ROOT DOWN $ipDev $note'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downRootFilter ip destination address $subnet24",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downRootFilter target 10",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upRootFilter attach-to 1",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upRootFilter description 'DEVAQ ROOT UP $ipDev $note'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upRootFilter ip source address $subnet24",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upRootFilter target 20",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Down) host-identifier dip",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Down) max-rate ${downLimit}mbit",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Down) subnet ${ipDev}/32",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Up) host-identifier sip",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Up) max-rate ${upLimit}mbit",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue queue-type hfq $($queueTypes.Up) subnet ${ipDev}/32",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $downQueue bandwidth ${downLimit}mbit",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $downQueue description '$downDesc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $downQueue parent 10",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $downQueue queue-type $($queueTypes.Down)",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $upQueue bandwidth ${upLimit}mbit",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $upQueue description '$upDesc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $upQueue parent 20",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue leaf queue $upQueue queue-type $($queueTypes.Up)",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downFilter attach-to 10",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downFilter description '$downDesc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downFilter ip destination address ${ipDev}/32",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $downFilter target $downQueue",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upFilter attach-to 20",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upFilter description '$upDesc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upFilter ip source address ${ipDev}/32",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control advanced-queue filters match $upFilter target $upQueue"
    )

    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "QOS_DEVICE_AQ_${ipDev}"
    Set-OutputText -Target $txtQosOut -Content $out -Title 'Limite por dispositivo aplicado'
    $script:ConfigCommandsCache = $null
    Refresh-QosDevicePolicies
    Write-AppLog "Limite por dispositivo via Advanced Queue aplicado para ${ipDev}: down ${downLimit} / up ${upLimit}"
}

function Remove-QosDeviceLimit {
    $item = $dgQosDevicePolicies.SelectedItem
    if ($null -eq $item) { throw 'Selecione um limite por dispositivo para remover.' }
    $currentItems = @(Get-QosDevicePolicies)
    $cmds = @()
    foreach ($id in @($item.DownFilter,$item.UpFilter,$item.DownRootFilter,$item.UpRootFilter)) {
        if ($id) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue filters match $id" }
    }
    foreach ($id in @($item.DownQueue,$item.UpQueue)) {
        if ($id) { $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue leaf queue $id" }
    }
    $queueTypes = Get-QosDeviceQueueTypeNames -IpAddress $item.IP
    $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue queue-type hfq $($queueTypes.Down)"
    $cmds += "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue queue-type hfq $($queueTypes.Up)"
    if ($currentItems.Count -le 1) {
        $cmds += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue branch queue 10'
        $cmds += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue branch queue 20'
        $cmds += '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control advanced-queue root queue 1'
    }
    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "QOS_DEVICE_REMOVE_$($item.IP)"
    Set-OutputText -Target $txtQosOut -Content $out -Title 'Limite por dispositivo removido'
    $script:ConfigCommandsCache = $null
    Refresh-QosDevicePolicies
    Write-AppLog "Limite por dispositivo removido: $($item.IP)"
}

function Get-WanDefaultRouteHints {
    $raw = Invoke-EdgeRouterCommand -Command 'ip route show default' -Silent
    $items = New-Object System.Collections.ArrayList
    foreach ($line in @($raw -split "`r?`n")) {
        $line = [string]$line
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $line = $line.Trim()
        if ($line -match '^default via (\d{1,3}(?:\.\d{1,3}){3}) dev (\S+)') {
            [void]$items.Add([pscustomobject]@{ Interface=$matches[2]; Gateway=$matches[1]; Raw=$line; PointToPoint=$false })
            continue
        }
        if ($line -match '^default dev (\S+)') {
            [void]$items.Add([pscustomobject]@{ Interface=$matches[1]; Gateway=''; Raw=$line; PointToPoint=$true })
            continue
        }
    }
    return @($items)
}

function Get-WanRouteHint {
    param([string]$Interface)
    $hints = @(Get-WanDefaultRouteHints)
    if (-not $hints -or $hints.Count -eq 0) { return $null }
    $exact = $hints | Where-Object { $_.Interface -eq $Interface } | Select-Object -First 1
    if ($exact) { return $exact }
    return $null
}

function Get-PbrTableDefaultCommands {
    param(
        [string]$Table,
        [string]$Interface,
        [int]$Distance = 1
    )
    if ([string]::IsNullOrWhiteSpace($Table) -or [string]::IsNullOrWhiteSpace($Interface)) {
        throw 'Tabela e interface são obrigatórias para montar a rota padrão do PBR.'
    }
    $hint = Get-WanRouteHint -Interface $Interface
    if ($hint -and -not [string]::IsNullOrWhiteSpace($hint.Gateway)) {
        return [pscustomobject]@{
            Commands = @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols static table $Table route 0.0.0.0/0 next-hop $($hint.Gateway) distance $Distance")
            Warning = ''
            Raw = $hint.Raw
        }
    }
    if ($Distance -le 1) {
        return [pscustomobject]@{
            Commands = @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols static table $Table interface-route 0.0.0.0/0 next-hop-interface $Interface")
            Warning = if ($hint) { '' } else { "Não detectei gateway da interface $Interface; usando interface-route direto." }
            Raw = if ($hint) { $hint.Raw } else { '' }
        }
    }
    return [pscustomobject]@{
        Commands = @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols static table $Table route 0.0.0.0/0 next-hop-interface $Interface distance $Distance")
        Warning = "A WAN de backup $Interface foi montada com next-hop-interface e distância $Distance. Se o EdgeOS do seu modelo reclamar da sintaxe, use kill switch ou ajuste manualmente o fallback."
        Raw = if ($hint) { $hint.Raw } else { '' }
    }
}

function Invoke-PbrPreferredPolicyInternal {
    param(
        [string]$Rule,
        [string]$IpAddress,
        [string]$PreferredWan,
        [string]$BackupWan,
        [string]$Table,
        [string]$Modify,
        [bool]$KillSwitch = $false,
        [string]$Reason = 'PBR_Prefer',
        [string]$ConfirmLabel = $null
    )
    if (-not $Rule -or -not $IpAddress -or -not $PreferredWan -or -not $Table -or -not $Modify) { throw 'Preencha Rule ID, IP, WAN preferida, tabela e firewall modify.' }
    if (-not (Test-IPv4Address $IpAddress)) { throw 'IP da máquina inválido.' }
    if (-not $KillSwitch -and [string]::IsNullOrWhiteSpace($BackupWan)) { throw 'Informe também a WAN de backup ou marque Kill switch.' }
    if ($PreferredWan -eq $BackupWan -and -not $KillSwitch) { throw 'A WAN preferida e a WAN de backup não podem ser iguais.' }
    if ([string]::IsNullOrWhiteSpace($ConfirmLabel)) {
        $ConfirmLabel = if ($KillSwitch) {
            "Aplicar política preferindo $PreferredWan com kill switch para $IpAddress?"
        } else {
            "Aplicar política preferindo $PreferredWan com fallback para $BackupWan no IP $IpAddress?"
        }
    }
    if (-not (Confirm-UiAction $ConfirmLabel)) { return }

    $cmds = @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall modify $Modify rule $Rule",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $Table route 0.0.0.0/0",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $Table interface-route 0.0.0.0/0"
    )

    $primary = Get-PbrTableDefaultCommands -Table $Table -Interface $PreferredWan -Distance 1
    $cmds += @($primary.Commands)

    $backup = $null
    if (-not $KillSwitch) {
        $backup = Get-PbrTableDefaultCommands -Table $Table -Interface $BackupWan -Distance 200
        $cmds += @($backup.Commands)
    }

    $descMode = if ($KillSwitch) { 'KillSwitch' } else { 'Fallback' }
    $desc = Normalize-EdgeName -Value ("Preferir_${PreferredWan}_${descMode}_${IpAddress}") -Default 'PBR_Preferred'
    $cmds += @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule description '$desc'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule source address $IpAddress",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule modify table $Table"
    )

    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason $Reason
    $notes = New-Object System.Collections.ArrayList
    if ($primary -and $primary.Warning) { [void]$notes.Add("Primária: $($primary.Warning)") }
    if ($backup -and $backup.Warning) { [void]$notes.Add("Backup: $($backup.Warning)") }
    if ($notes.Count -gt 0) {
        $out = $out + "`r`n`r`nObservações:`r`n- " + (($notes.ToArray()) -join "`r`n- ")
    }
    Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado da política preferencial'
    $script:ConfigCommandsCache = $null
    Refresh-PbrPolicies
    if ($txtPbrRule.Text -eq $Rule) { $txtPbrRule.Text = Get-NextAvailablePbrRule -Modify $Modify }
    $logMsg = if ($KillSwitch) { "Política preferencial com kill switch aplicada para $IpAddress em $PreferredWan" } else { "Política preferencial aplicada para ${IpAddress}: $PreferredWan com fallback em $BackupWan" }
    Write-AppLog $logMsg
}

function Invoke-PbrCreateInternal {
    param(
        [string]$Rule,
        [string]$IpAddress,
        [string]$WanInterface,
        [string]$Table,
        [string]$Modify,
        [string]$Reason = 'PBR',
        [string]$ConfirmLabel = $null
    )
    if (-not $Rule -or -not $IpAddress -or -not $WanInterface -or -not $Table -or -not $Modify) { throw 'Preencha Rule ID, IP, interface WAN, tabela e firewall modify.' }
    if (-not (Test-IPv4Address $IpAddress)) { throw 'IP da máquina inválido.' }
    if ([string]::IsNullOrWhiteSpace($ConfirmLabel)) { $ConfirmLabel = "Criar PBR para $IpAddress via $WanInterface?" }
    if (-not (Confirm-UiAction $ConfirmLabel)) { return }

    $primary = Get-PbrTableDefaultCommands -Table $Table -Interface $WanInterface -Distance 1
    $cmds = @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall modify $Modify rule $Rule",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $Table route 0.0.0.0/0",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $Table interface-route 0.0.0.0/0"
    )
    $cmds += @($primary.Commands)
    $cmds += @(
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule description 'Forcar_Rota_$IpAddress'",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule source address $IpAddress",
        "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall modify $Modify rule $Rule modify table $Table"
    )
    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason $Reason
    if ($primary -and $primary.Warning) {
        $out = $out + "`r`n`r`nObservação:`r`n- " + $primary.Warning
    }
    Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado do PBR'
    $script:ConfigCommandsCache = $null
    Refresh-PbrPolicies
    if ($txtPbrRule.Text -eq $Rule) { $txtPbrRule.Text = Get-NextAvailablePbrRule -Modify $Modify }
    Write-AppLog "PBR criado para $IpAddress via $WanInterface"
}

function Refresh-DashboardSummary {
    Set-OutputText -Target $txtDashOut -Content (Get-RouterSummary) -Title 'Resumo do roteador'
}

function Refresh-DashboardInterfaces {
    Set-OutputText -Target $txtDashOut -Content (Get-EdgeInterfacesOverview) -Title 'Interfaces / Rotas / ARP'
}

function Refresh-DashboardDhcp {
    Set-OutputText -Target $txtDashOut -Content (Get-DhcpLeaseRawText) -Title 'Clientes DHCP'
}

function Refresh-DhcpLeases {
    $leases = foreach ($line in (Get-DhcpLeaseLines)) { Parse-DhcpLeaseDisplayLine -Line $line -Source 'dynamic' }
    $script:PbrLeaseCandidates = @($leases | Where-Object { $_ })
    $dgDhcpLeases.ItemsSource = $script:PbrLeaseCandidates
    $txtDhcpOut.Text = (Get-DhcpLeaseRawText)
    Write-AppLog "Leases DHCP carregados: $($script:PbrLeaseCandidates.Count)"
}

function Refresh-DhcpReservations {
    $script:DhcpStaticMappings = @(Get-DhcpStaticMappings)
    $dgDhcpReservations.ItemsSource = $script:DhcpStaticMappings
    $txtDhcpOut.Text = (($script:DhcpStaticMappings | ForEach-Object { "Pool=$($_.Pool) | Sub-rede=$($_.Subnet) | Nome=$($_.Name) | IP=$($_.IP) | MAC=$($_.MAC)" }) -join "`r`n")
    Write-AppLog "Reservas DHCP carregadas: $($script:DhcpStaticMappings.Count)"
}

function Apply-SelectedLeaseToDhcpFields {
    $item = $dgDhcpLeases.SelectedItem
    if (-not $item) { return }
    $txtPool.Text = if ($txtPool.Text) { $txtPool.Text } else { 'LAN' }
    if (-not $txtSubnet.Text) { $txtSubnet.Text = '192.168.1.0/24' }
    $txtHost.Text = Normalize-EdgeName -Value $item.Host -Default 'host_reservado'
    $txtMac.Text = $item.MAC
    $txtIpFix.Text = $item.IP
}

function Apply-SelectedReservationToDhcpFields {
    $item = $dgDhcpReservations.SelectedItem
    if (-not $item) { return }
    $txtPool.Text = $item.Pool
    $txtSubnet.Text = $item.Subnet
    $txtHost.Text = $item.Name
    $txtMac.Text = $item.MAC
    $txtIpFix.Text = $item.IP
}

function Refresh-LoadBalanceStatus {
    $groups = @(Get-LoadBalanceContext)
    if ($groups.Count -eq 0) {
        Set-OutputText -Target $txtLbOut -Content 'Nenhum grupo de load-balance detectado.' -Title 'Status do balanceamento'
        return
    }
    $groupObj = $groups[0]
    $txtLbGroup.Text = $groupObj.Name
    $txtPbrModify.Text = $groupObj.ModifyChain
    $ifaces = @($groupObj.Interfaces)
    if ($ifaces.Count -ge 1) {
        $txtLbWan1.Text = $ifaces[0].Name
        $txtLbWeight1.Text = $ifaces[0].Weight
        if (-not $txtPbrWan.Text) { $txtPbrWan.Text = $ifaces[0].Name }
    }
    if ($ifaces.Count -ge 2) {
        $txtLbWan2.Text = $ifaces[1].Name
        $txtLbWeight2.Text = $ifaces[1].Weight
    }
    $summary = Format-LoadBalanceSummary -GroupObj $groupObj
    try {
        Refresh-PbrPolicies
        if (-not $txtPbrRule.Text -or $txtPbrRule.Text -eq '10') { $txtPbrRule.Text = Get-NextAvailablePbrRule -Modify $txtPbrModify.Text.Trim() }
    } catch {}
    $cmd = "echo '--- WATCHDOG ---'; /opt/vyatta/bin/vyatta-op-cmd-wrapper show load-balance watchdog; echo ''; echo '--- STATUS GERAL ---'; /opt/vyatta/bin/vyatta-op-cmd-wrapper show load-balance status"
    $diag = Invoke-EdgeRouterCommand -Command $cmd
    $combined = $summary + "`r`n`r`n" + (Convert-OutputToText $diag)
    Set-OutputText -Target $txtLbOut -Content $combined -Title 'Status do balanceamento'
}

function Refresh-PbrLeaseCandidates {
    $list = New-Object System.Collections.ArrayList
    foreach ($lease in $script:PbrLeaseCandidates) { [void]$list.Add([pscustomobject]@{ Tipo='DIN'; IP=$lease.IP; MAC=$lease.MAC; Nome=$lease.Host }) }
    foreach ($mapping in $script:DhcpStaticMappings) { [void]$list.Add([pscustomobject]@{ Tipo='RES'; IP=$mapping.IP; MAC=$mapping.MAC; Nome=$mapping.Name }) }
    $dgPbrLeases.ItemsSource = @($list)
}


function Get-PbrPolicyRules {
    param([string]$Modify = 'balance')
    if ([string]::IsNullOrWhiteSpace($Modify)) { $Modify = 'balance' }
    $cfg = Get-EdgeConfigCommandsText
    $map = @{}
    foreach ($line in ($cfg -split "`r?`n")) {
        if ($line -match "^set firewall modify\s+$([regex]::Escape($Modify))\s+rule\s+(\d+)\s+description\s+'?(.+?)'?$") {
            $rule = $matches[1]
            if (-not $map.ContainsKey($rule)) { $map[$rule] = [ordered]@{ Rule=$rule; Modify=$Modify; Description=''; Source=''; Table=''; Wan=''; Kind='' } }
            $map[$rule].Description = $matches[2].Trim("'")
            continue
        }
        if ($line -match "^set firewall modify\s+$([regex]::Escape($Modify))\s+rule\s+(\d+)\s+source address\s+(\S+)$") {
            $rule = $matches[1]
            if (-not $map.ContainsKey($rule)) { $map[$rule] = [ordered]@{ Rule=$rule; Modify=$Modify; Description=''; Source=''; Table=''; Wan=''; Kind='' } }
            $map[$rule].Source = $matches[2]
            continue
        }
        if ($line -match "^set firewall modify\s+$([regex]::Escape($Modify))\s+rule\s+(\d+)\s+modify table\s+(\d+)$") {
            $rule = $matches[1]
            if (-not $map.ContainsKey($rule)) { $map[$rule] = [ordered]@{ Rule=$rule; Modify=$Modify; Description=''; Source=''; Table=''; Wan=''; Kind='' } }
            $map[$rule].Table = $matches[2]
            continue
        }
    }

    $tableWan = @{}
    foreach ($line in ($cfg -split "`r?`n")) {
        if ($line -match '^set protocols static table (\d+) interface-route 0\.0\.0\.0/0 next-hop-interface (\S+)$') {
            $tableWan[$matches[1]] = $matches[2]
            continue
        }
        if ($line -match '^set protocols static table (\d+) route 0\.0\.0\.0/0 next-hop-interface (\S+)(?: distance \d+)?$') {
            if (-not $tableWan.ContainsKey($matches[1])) { $tableWan[$matches[1]] = $matches[2] }
            continue
        }
        if ($line -match '^set protocols static table (\d+) route 0\.0\.0\.0/0 next-hop (\S+)(?: distance \d+)?$') {
            if (-not $tableWan.ContainsKey($matches[1])) { $tableWan[$matches[1]] = 'gateway:' + $matches[2] }
            continue
        }
    }

    $items = New-Object System.Collections.ArrayList
    foreach ($entry in ($map.GetEnumerator() | Sort-Object {[int]$_.Key})) {
        $obj = [pscustomobject]$entry.Value
        if (-not $obj.Source -or -not $obj.Table) { continue }
        if ($tableWan.ContainsKey($obj.Table)) { $obj.Wan = $tableWan[$obj.Table] }
        $desc = [string]$obj.Description
        if ($desc -like 'Forcar_Rota_*') { $obj.Kind = 'FIXA' }
        elseif ($desc -like 'Preferir_*') { $obj.Kind = 'PREFER' }
        else { $obj.Kind = 'PBR' }
        [void]$items.Add($obj)
    }
    return @($items)
}

function Get-NextAvailablePbrRule {
    param([string]$Modify = 'balance')
    $rules = @(Get-PbrPolicyRules -Modify $Modify | ForEach-Object { [int]$_.Rule })
    for ($i = 100; $i -le 199; $i++) {
        if ($rules -notcontains $i) { return [string]$i }
    }
    return [string](([int](($rules | Measure-Object -Maximum).Maximum)) + 1)
}

function Refresh-PbrPolicies {
    $modify = $txtPbrModify.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($modify)) { $modify = 'balance'; $txtPbrModify.Text = $modify }
    $items = @(Get-PbrPolicyRules -Modify $modify)
    $dgPbrPolicies.ItemsSource = $items
    if (-not $txtPbrRule.Text -or $txtPbrRule.Text -eq '10') {
        $txtPbrRule.Text = Get-NextAvailablePbrRule -Modify $modify
    }
    if ($items.Count -eq 0) {
        Write-AppLog "Nenhuma política PBR encontrada na chain $modify"
    } else {
        Write-AppLog "Políticas PBR carregadas na chain ${modify}: $($items.Count)"
    }
}

function Remove-PbrPolicyInternal {
    param([psobject]$Policy)
    if ($null -eq $Policy) { throw 'Selecione uma política PBR para remover.' }
    $rule = [string]$Policy.Rule
    $modify = [string]$Policy.Modify
    $table = [string]$Policy.Table
    $ip = [string]$Policy.Source
    if (-not (Confirm-UiAction "Remover a política PBR da regra $rule para o IP $ip?")) { return }

    $cmds = @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall modify $modify rule $rule")
    $others = @(Get-PbrPolicyRules -Modify $modify | Where-Object { $_.Rule -ne $rule -and $_.Table -eq $table })
    if ($table -and $others.Count -eq 0) {
        $cmds += @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $table route 0.0.0.0/0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete protocols static table $table interface-route 0.0.0.0/0"
        )
    }
    $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "PBR_DELETE_$rule"
    Set-OutputText -Target $txtLbOut -Content $out -Title 'Remoção de política PBR'
    $script:ConfigCommandsCache = $null
    Refresh-PbrPolicies
    if ($txtPbrRule.Text -eq $rule) { $txtPbrRule.Text = Get-NextAvailablePbrRule -Modify $modify }
    Write-AppLog "Política PBR removida: regra $rule / IP $ip / chain $modify"
}


function Refresh-DnsBlockedDomains {
    $lstDnsDomains.ItemsSource = @(Get-DnsBlockedDomains)
    $txtDnsOut.Text = (($lstDnsDomains.ItemsSource | ForEach-Object { $_ }) -join "`r`n")
}

function Set-WpfToolTipSafe {
    param(
        $Control,
        [string]$Text
    )
    try {
        if ($null -eq $Control) { return }
        if (-not ($Control -is [System.Windows.DependencyObject])) { return }
        [System.Windows.FrameworkElement]::ToolTipProperty | Out-Null
        $Control.SetValue([System.Windows.FrameworkElement]::ToolTipProperty, $Text)
    } catch {}
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="EdgeRouter Suite Friendly - WPF Preview v20 DPI / Offload"
        Width="1320" Height="920" MinWidth="1180" MinHeight="760"
        WindowStartupLocation="CenterScreen" Background="#FFF4F6F8">
    <DockPanel LastChildFill="True" Margin="10">
        <StatusBar DockPanel.Dock="Bottom" Height="28">
            <TextBlock Text="Status:" FontWeight="SemiBold" />
            <TextBlock x:Name="txtStatus" Margin="6,0,12,0" Text="Pronto" />
            <Separator />
            <TextBlock Text="Base:" FontWeight="SemiBold" Margin="8,0,0,0" />
            <TextBlock Margin="6,0,12,0" Text="Protótipo WPF paralelo ao fix16" />
        </StatusBar>

        <Border DockPanel.Dock="Top" BorderBrush="#D0D7DE" BorderThickness="1" CornerRadius="8" Background="White" Padding="12" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="170"/>
                    <ColumnDefinition Width="18"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="170"/>
                    <ColumnDefinition Width="18"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="170"/>
                    <ColumnDefinition Width="20"/>
                    <ColumnDefinition Width="140"/>
                    <ColumnDefinition Width="12"/>
                    <ColumnDefinition Width="200"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="8" Text="Conexão do Roteador" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10" />
                <TextBlock Grid.Row="1" Grid.Column="0" VerticalAlignment="Center" Text="IP:" />
                <TextBox x:Name="txtIp" Grid.Row="1" Grid.Column="1" Height="30" Margin="6,0,0,0" />
                <TextBlock Grid.Row="1" Grid.Column="3" VerticalAlignment="Center" Text="Usuário:" />
                <TextBox x:Name="txtUser" Grid.Row="1" Grid.Column="4" Height="30" Margin="6,0,0,0" />
                <TextBlock Grid.Row="1" Grid.Column="6" VerticalAlignment="Center" Text="Senha:" />
                <PasswordBox x:Name="txtPass" Grid.Row="1" Grid.Column="7" Height="30" Margin="6,0,0,0" />
                <Button x:Name="btnTestConn" Grid.Row="1" Grid.Column="9" Height="34" Content="Testar SSH" Background="#8FD3FF" BorderBrush="#4E6E81" />
                <Button x:Name="btnAbout" Grid.Row="1" Grid.Column="11" Height="34" Content="O que este app faz?" Background="#F6F8FA" BorderBrush="#4E6E81" />
                <Button x:Name="btnLangToggle" Grid.Row="1" Grid.Column="12" Width="64" Height="34" Content="EN" HorizontalAlignment="Left" Background="#F6F8FA" BorderBrush="#4E6E81" />
            </Grid>
        </Border>

        <TabControl x:Name="tabMain" Background="White">
            <TabItem Header="Dashboard">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnDashResumo" Content="Resumo do Roteador" Width="180" Height="36" Margin="0,0,10,0" Background="#8FD3FF"/>
                        <Button x:Name="btnDashRede" Content="Interfaces / Rotas / ARP" Width="220" Height="36" Margin="0,0,10,0" Background="#8FD3FF"/>
                        <Button x:Name="btnDashLeases" Content="Clientes DHCP" Width="180" Height="36" Background="#94E28F"/>
                    </StackPanel>
                    <TextBox x:Name="txtDashOut" Grid.Row="1" FontFamily="Consolas" FontSize="14" AcceptsReturn="True" AcceptsTab="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                </Grid>
            </TabItem>

            <TabItem Header="DHCP">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="2*"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="1.3*"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="2*"/>
                        <ColumnDefinition Width="14"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Row="0" Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="8" VerticalAlignment="Top">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                <Button x:Name="btnDhcpLer" Content="Ler Leases DHCP" Width="160" Height="34" Background="#8FD3FF" Margin="0,0,8,0"/>
                                <Button x:Name="btnDhcpLerReservas" Content="Listar Reservas" Width="140" Height="34" Background="#A8F0A1" />
                            </StackPanel>
                            <DataGrid x:Name="dgDhcpLeases" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" HeadersVisibility="Column" FontFamily="Consolas" FontSize="13">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="120"/>
                                    <DataGridTextColumn Header="MAC" Binding="{Binding MAC}" Width="160"/>
                                    <DataGridTextColumn Header="Nome" Binding="{Binding Host}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </Grid>
                    </Border>

                    <Border Grid.Row="0" Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10" VerticalAlignment="Top">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="90"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Text="Reserva de IP" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                            <TextBlock Grid.Row="1" Text="Pool:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPool" Grid.Row="1" Grid.Column="1" Height="28" Text="LAN"/>
                            <TextBlock Grid.Row="2" Text="Sub-rede:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtSubnet" Grid.Row="2" Grid.Column="1" Height="28" Text="192.168.1.0/24"/>
                            <TextBlock Grid.Row="3" Text="Nome:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtHost" Grid.Row="3" Grid.Column="1" Height="28"/>
                            <TextBlock Grid.Row="4" Text="MAC:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtMac" Grid.Row="4" Grid.Column="1" Height="28"/>
                            <TextBlock Grid.Row="5" Text="IP fixo:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtIpFix" Grid.Row="5" Grid.Column="1" Height="28"/>
                            <WrapPanel Grid.Row="6" Grid.ColumnSpan="2" Margin="0,12,0,0">
                                <Button x:Name="btnUsarLease" Content="Usar Lease Selecionado" Width="170" Height="34" Margin="0,0,8,8" Background="#F3E58A"/>
                                <Button x:Name="btnCriarReserva" Content="Criar Reserva DHCP" Width="170" Height="34" Margin="0,0,8,8" Background="#47C37C"/>
                                <Button x:Name="btnRemoverReserva" Content="Remover Reserva" Width="140" Height="34" Margin="0,0,8,8" Background="#F28585"/>
                                <Button x:Name="btnLimparDhcp" Content="Limpar Campos" Width="130" Height="34" Background="#F6F8FA"/>
                            </WrapPanel>
                        </Grid>
                    </Border>

                    <Grid Grid.Row="3" Grid.ColumnSpan="3">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="1.2*"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="1.2*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Text="Reservas DHCP existentes" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <DataGrid x:Name="dgDhcpReservations" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" FontFamily="Consolas" FontSize="13">
                                    <DataGrid.Columns>
                                        <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="120"/>
                                        <DataGridTextColumn Header="MAC" Binding="{Binding MAC}" Width="160"/>
                                        <DataGridTextColumn Header="Pool" Binding="{Binding Pool}" Width="80"/>
                                        <DataGridTextColumn Header="Nome" Binding="{Binding Name}" Width="*"/>
                                        <DataGridTextColumn Header="Sub-rede" Binding="{Binding Subnet}" Width="120"/>
                                    </DataGrid.Columns>
                                </DataGrid>
                            </Grid>
                        </Border>
                        <Border Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Text="Saída / diagnóstico DHCP" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <TextBox x:Name="txtDhcpOut" Grid.Row="1" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>
            </TabItem>

            
            <TabItem Header="Firewall / NAT">
                <Grid Margin="10">
                    <TabControl x:Name="tabFwSub" Background="White">
                        <TabItem Header="Regras">
                            <Grid Margin="10">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="8"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="8"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="8"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1*"/>
                                    <ColumnDefinition Width="12"/>
                                    <ColumnDefinition Width="1*"/>
                                </Grid.ColumnDefinitions>

                                <Border Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="3" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="120"/>
                                            <ColumnDefinition Width="250"/>
                                            <ColumnDefinition Width="20"/>
                                            <ColumnDefinition Width="140"/>
                                            <ColumnDefinition Width="260"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>

                                        <TextBlock Grid.Row="0" Grid.ColumnSpan="5" Text="Regras de firewall" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Ruleset / chain:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwName" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="LAN_IN"/>
                                        <TextBlock Grid.Row="1" Grid.Column="3" Text="Rule ID:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwRule" Grid.Row="1" Grid.Column="4" Height="28" Margin="6,0,0,8" Text="100"/>

                                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Ação:" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cmbFwAction" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,0,8" SelectedIndex="1">
                                            <ComboBoxItem Content="accept"/>
                                            <ComboBoxItem Content="drop"/>
                                            <ComboBoxItem Content="reject"/>
                                        </ComboBox>
                                        <TextBlock Grid.Row="2" Grid.Column="3" Text="IP interno (origem):" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwSource" Grid.Row="2" Grid.Column="4" Height="28" Margin="6,0,0,8"/>

                                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Destino:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwDest" Grid.Row="3" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                                        <TextBlock Grid.Row="3" Grid.Column="3" Text="Protocolo:" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cmbFwProto" Grid.Row="3" Grid.Column="4" Height="28" Margin="6,0,0,8" SelectedIndex="0">
                                            <ComboBoxItem Content="any"/>
                                            <ComboBoxItem Content="tcp"/>
                                            <ComboBoxItem Content="udp"/>
                                            <ComboBoxItem Content="tcp_udp"/>
                                            <ComboBoxItem Content="icmp"/>
                                        </ComboBox>

                                        <TextBlock Grid.Row="4" Grid.Column="0" Text="Porta dest.:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwPort" Grid.Row="4" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                                        <TextBlock Grid.Row="4" Grid.Column="3" Text="Descrição:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtFwDesc" Grid.Row="4" Grid.Column="4" Height="28" Margin="6,0,0,8"/>
                                    </Grid>
                                </Border>

                                <TextBlock Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Text="Use LAN_IN para clientes internos. Use WAN_IN/WAN_LOCAL para tráfego vindo das WANs para a LAN ou para o próprio roteador." Foreground="#666666" Margin="0,2,0,6" TextWrapping="Wrap"/>

                                <WrapPanel Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,0,0,8">
                                    <Button x:Name="btnFwListar" Content="Listar Regras" Width="130" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                    <Button x:Name="btnFwCriar" Content="Criar Regra" Width="130" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                                    <Button x:Name="btnFwBlockInternet" Content="Bloquear Internet do IP" Width="170" Height="34" Margin="0,0,8,0" Background="#F28B82"/>
                                    <Button x:Name="btnFwAllowWebDns" Content="Permitir Só Web/DNS" Width="170" Height="34" Margin="0,0,8,0" Background="#A8E6A1"/>
                                    <Button x:Name="btnFwBlockPort" Content="Bloquear Porta/Proto" Width="160" Height="34" Margin="0,0,8,0" Background="#F6D58E"/>
                                    <Button x:Name="btnFwReadManaged" Content="Ler Regras do App" Width="160" Height="34" Margin="0,0,8,0" Background="#E6F0FF"/>
                                    <Button x:Name="btnFwRemoveManaged" Content="Remover Regra Selecionada" Width="200" Height="34" Background="#F28B82"/>
                                </WrapPanel>

                                <Grid Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="3">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="1.2*"/>
                                        <ColumnDefinition Width="12"/>
                                        <ColumnDefinition Width="1.0*"/>
                                    </Grid.ColumnDefinitions>
                                    <DataGrid x:Name="dgFwManaged" Grid.Column="0" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" IsReadOnly="True" HeadersVisibility="Column" Margin="0" MinHeight="260">
                                        <DataGrid.Columns>
                                            <DataGridTextColumn Header="Firewall" Binding="{Binding Firewall}" Width="90"/>
                                            <DataGridTextColumn Header="Regra" Binding="{Binding Rule}" Width="60"/>
                                            <DataGridTextColumn Header="Ação" Binding="{Binding Action}" Width="70"/>
                                            <DataGridTextColumn Header="Origem" Binding="{Binding Source}" Width="120"/>
                                            <DataGridTextColumn Header="Destino" Binding="{Binding Destination}" Width="120"/>
                                            <DataGridTextColumn Header="Proto" Binding="{Binding Protocol}" Width="70"/>
                                            <DataGridTextColumn Header="Porta" Binding="{Binding Port}" Width="70"/>
                                            <DataGridTextColumn Header="Descrição" Binding="{Binding Description}" Width="*"/>
                                        </DataGrid.Columns>
                                    </DataGrid>
                                    <TextBox x:Name="txtFwInline" Grid.Column="2" Margin="0" MinHeight="260" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                                </Grid>
                            </Grid>
                        </TabItem>

                        <TabItem Header="Conexões / Captura">
                            <Grid Margin="10">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="8"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="8"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Border Grid.Row="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="100"/>
                                            <ColumnDefinition Width="180"/>
                                            <ColumnDefinition Width="14"/>
                                            <ColumnDefinition Width="70"/>
                                            <ColumnDefinition Width="90"/>
                                            <ColumnDefinition Width="14"/>
                                            <ColumnDefinition Width="80"/>
                                            <ColumnDefinition Width="140"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Grid.ColumnSpan="8" Text="Conexões ativas e captura rápida" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                        <TextBlock Grid.Row="1" Grid.Column="0" Text="IP alvo:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtTraceIp" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                                        <TextBlock Grid.Row="1" Grid.Column="3" Text="Segs:" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtTraceSeconds" Grid.Row="1" Grid.Column="4" Height="28" Margin="6,0,0,8" Text="12"/>
                                        <TextBlock Grid.Row="1" Grid.Column="6" Text="Interface:" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cmbTraceIface" Grid.Row="1" Grid.Column="7" Height="28" Margin="6,0,0,8" SelectedIndex="0">
                                            <ComboBoxItem Content="any"/>
                                            <ComboBoxItem Content="switch0"/>
                                            <ComboBoxItem Content="eth0"/>
                                            <ComboBoxItem Content="eth1"/>
                                            <ComboBoxItem Content="eth2"/>
                                            <ComboBoxItem Content="eth3"/>
                                            <ComboBoxItem Content="eth4"/>
                                            <ComboBoxItem Content="pppoe0"/>
                                        </ComboBox>
                                        <WrapPanel Grid.Row="2" Grid.ColumnSpan="8">
                                            <Button x:Name="btnTraceConntrack" Content="Ver Conexões Ativas" Width="150" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                            <Button x:Name="btnTraceTcpdump" Content="Captura Rápida" Width="130" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                                            <TextBox x:Name="txtTraceSearch" Width="220" Height="28" Margin="0,3,8,0"/>
                                            <Button x:Name="btnTraceSearch" Content="Pesquisar no Navegador" Width="170" Height="34" Background="#E6F0FF"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>
                                <TextBlock Grid.Row="2" Text="Dica: use o IP interno suspeito. O relatório mostra conntrack e uma captura rápida para ajudar a identificar destinos, portas e padrão de tráfego." Foreground="#666666" Margin="0,4,0,6" TextWrapping="Wrap"/>
                                <TextBox x:Name="txtTraceOut" Grid.Row="4" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                            </Grid>
                        </TabItem>

                        <TabItem Header="NAT / Port Forward">
<Grid Margin="10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.15*"/>
                        <ColumnDefinition Width="12"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="110"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Text="Port Forward / NAT" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                            <TextBlock Grid.Row="1" Text="Rule ID:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtRuleNat" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                            <TextBlock Grid.Row="2" Text="WAN:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtInIf" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="eth0"/>
                            <TextBlock Grid.Row="3" Text="Porta ext.:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPortExt" Grid.Row="3" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                            <TextBlock Grid.Row="4" Text="IP Interno:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtIPInt" Grid.Row="4" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                            <TextBlock Grid.Row="5" Text="Porta int.:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPortInt" Grid.Row="5" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                            <TextBlock Grid.Row="6" Text="Protocolo:" VerticalAlignment="Center"/>
                            <ComboBox x:Name="cmbNatProto" Grid.Row="6" Grid.Column="1" Height="28" Margin="6,0,0,8" SelectedIndex="0">
                                <ComboBoxItem Content="tcp"/>
                                <ComboBoxItem Content="udp"/>
                                <ComboBoxItem Content="tcp_udp"/>
                            </ComboBox>
                            <TextBlock Grid.Row="7" Text="Descrição:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtDescNat" Grid.Row="7" Grid.Column="1" Height="28" Margin="6,0,0,8"/>
                            <WrapPanel Grid.Row="8" Grid.ColumnSpan="2" Margin="0,12,0,0">
                                <Button x:Name="btnNatListar" Content="Listar Port Forward" Width="170" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                <Button x:Name="btnNatCriar" Content="Criar Port Forward" Width="170" Height="34" Background="#47C37C"/>
                            </WrapPanel>
                        </Grid>
                    </Border>
                    <Border Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="Saída / diagnóstico NAT" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                            <TextBox x:Name="txtNatOut" Grid.Row="1" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                        </Grid>
                    </Border>
                </Grid>
                        </TabItem>
                        
                        <TabItem Header="QoS">
                            <Grid Margin="10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1.2*"/>
                                    <ColumnDefinition Width="12"/>
                                    <ColumnDefinition Width="1*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                                    <TabControl x:Name="tabQosSub">
                                        <TabItem Header="Facilitado">
                                            <Grid Margin="8">
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="160"/>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="160"/>
                                                    <ColumnDefinition Width="*"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Row="0" Grid.ColumnSpan="4" Text="QoS explicado em linguagem humana" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <TextBlock Grid.Row="1" Grid.Column="0" Text="Objetivo:" VerticalAlignment="Center"/>
                                                <ComboBox x:Name="cmbQosFriendlyGoal" Grid.Row="1" Grid.Column="1" Height="30" Margin="6,0,12,8">
                                                    <ComboBoxItem Content="Internet equilibrada"/>
                                                    <ComboBoxItem Content="Chamadas / WhatsApp"/>
                                                    <ComboBoxItem Content="Reuniões"/>
                                                    <ComboBoxItem Content="Jogos"/>
                                                </ComboBox>
                                                <TextBlock Grid.Row="1" Grid.Column="2" Text="Intensidade:" VerticalAlignment="Center"/>
                                                <ComboBox x:Name="cmbQosFriendlyLevel" Grid.Row="1" Grid.Column="3" Height="30" Margin="6,0,0,8">
                                                    <ComboBoxItem Content="Leve"/>
                                                    <ComboBoxItem Content="Média"/>
                                                    <ComboBoxItem Content="Forte"/>
                                                </ComboBox>

                                                <TextBlock Grid.Row="2" Grid.Column="0" Text="WAN do link:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyIface" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,12,8" Text="eth4"/>
                                                <TextBlock Grid.Row="2" Grid.Column="2" Text="Nome da política:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyPolicy" Grid.Row="2" Grid.Column="3" Height="28" Margin="6,0,0,8" IsReadOnly="True" Background="#F6F8FA"/>

                                                <TextBlock Grid.Row="3" Grid.Column="0" Text="Velocidade real download:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyDownReal" Grid.Row="3" Grid.Column="1" Height="28" Margin="6,0,12,8" Text="325"/>
                                                <TextBlock Grid.Row="3" Grid.Column="2" Text="Aplicar download:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyDownApply" Grid.Row="3" Grid.Column="3" Height="28" Margin="6,0,0,8" IsReadOnly="True" Background="#F6F8FA"/>

                                                <TextBlock Grid.Row="4" Grid.Column="0" Text="Velocidade real upload:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyUpReal" Grid.Row="4" Grid.Column="1" Height="28" Margin="6,0,12,8" Text="325"/>
                                                <TextBlock Grid.Row="4" Grid.Column="2" Text="Aplicar upload:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosFriendlyUpApply" Grid.Row="4" Grid.Column="3" Height="28" Margin="6,0,0,8" IsReadOnly="True" Background="#F6F8FA"/>

                                                <TextBlock Grid.Row="5" Grid.ColumnSpan="4" Text="O app calcula uma margem abaixo da velocidade real para o roteador conseguir organizar melhor a fila. Leve mantém mais banda; Forte prioriza mais estabilidade." Foreground="#666666" TextWrapping="Wrap" Margin="0,4,0,10"/>

                                                <WrapPanel Grid.Row="6" Grid.ColumnSpan="4" Margin="0,0,0,10">
                                                    <Button x:Name="btnQosFriendlyPreview" Content="Calcular" Width="110" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                                    <Button x:Name="btnQosFriendlyRead" Content="Ler QoS Atual" Width="130" Height="34" Margin="0,0,8,0" Background="#DDEEFF"/>
                                                    <Button x:Name="btnQosFriendlyApply" Content="Aplicar QoS Facilitado" Width="180" Height="34" Margin="0,0,8,0" Background="#47C37C"/>
                                                    <Button x:Name="btnQosFriendlyRemove" Content="Remover QoS" Width="130" Height="34" Background="#F28585"/>
                                                </WrapPanel>

                                                <TextBlock Grid.Row="7" Grid.ColumnSpan="4" Text="Resumo" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                                <TextBox x:Name="txtQosFriendlyExplain" Grid.Row="8" Grid.ColumnSpan="4" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Visible" IsReadOnly="True"/>
                                            </Grid>
                                        </TabItem>
                                        <TabItem Header="Por dispositivo">
                                            <Grid Margin="8">
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="170"/>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="170"/>
                                                    <ColumnDefinition Width="*"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Row="0" Grid.ColumnSpan="4" Text="Limites por dispositivo (Advanced Queue)" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <TextBlock Grid.Row="1" Grid.Column="0" Text="IP Interno:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevIp" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,12,8"/>
                                                <TextBlock Grid.Row="1" Grid.Column="2" Text="Nota:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevNote" Grid.Row="1" Grid.Column="3" Height="28" Margin="6,0,0,8" Text="device_limit"/>

                                                <TextBlock Grid.Row="2" Grid.Column="0" Text="Limite download (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevDown" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,12,8" Text="50"/>
                                                <TextBlock Grid.Row="2" Grid.Column="2" Text="Limite upload (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevUp" Grid.Row="2" Grid.Column="3" Height="28" Margin="6,0,0,8" Text="20"/>

                                                <TextBlock Grid.Row="3" Grid.Column="0" Text="Banda total down (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevTotalDown" Grid.Row="3" Grid.Column="1" Height="28" Margin="6,0,12,8" Text="325"/>
                                                <TextBlock Grid.Row="3" Grid.Column="2" Text="Banda total up (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDevTotalUp" Grid.Row="3" Grid.Column="3" Height="28" Margin="6,0,0,8" Text="325"/>

                                                <TextBlock Grid.Row="4" Grid.ColumnSpan="4" Text="Este modo usa Advanced Queue global para limitar o IP em download e upload. Remova Smart Queue antes de usar." Foreground="#666666" TextWrapping="Wrap" Margin="0,4,0,10"/>
                                                <WrapPanel Grid.Row="5" Grid.ColumnSpan="4" Margin="0,0,0,8">
                                                    <Button x:Name="btnQosDevUseLease" Content="Listar online agora" Width="150" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                                                    <Button x:Name="btnQosDevRead" Content="Ler limites" Width="120" Height="34" Margin="0,0,8,0" Background="#DDEEFF"/>
                                                    <Button x:Name="btnQosDevApply" Content="Aplicar limite" Width="140" Height="34" Margin="0,0,8,0" Background="#47C37C"/>
                                                    <Button x:Name="btnQosDevRemove" Content="Remover limite selecionado" Width="200" Height="34" Background="#F28585"/>
                                                </WrapPanel>
                                                <WrapPanel Grid.Row="6" Grid.ColumnSpan="4" Margin="0,0,0,10">
                                                    <Button x:Name="btnP2PRead" Content="Ler Bloqueios P2P" Width="150" Height="34" Margin="0,0,8,0" Background="#DDEEFF"/>
                                                    <Button x:Name="btnP2PBlock" Content="Bloquear P2P/Torrent" Width="180" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                                                    <Button x:Name="btnP2PRemove" Content="Remover Bloqueio P2P" Width="180" Height="34" Background="#F28585"/>
                                                </WrapPanel>
                                                <DataGrid x:Name="dgQosDevicePolicies" Grid.Row="7" Grid.ColumnSpan="4" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" FontFamily="Consolas" FontSize="13">
                                                    <DataGrid.Columns>
                                                        <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="120"/>
                                                        <DataGridTextColumn Header="Download" Binding="{Binding Download}" Width="90"/>
                                                        <DataGridTextColumn Header="Upload" Binding="{Binding Upload}" Width="90"/>
                                                        <DataGridTextColumn Header="Fila Down" Binding="{Binding DownQueue}" Width="90"/>
                                                        <DataGridTextColumn Header="Fila Up" Binding="{Binding UpQueue}" Width="90"/>
                                                        <DataGridTextColumn Header="Nota" Binding="{Binding Note}" Width="*"/>
                                                    </DataGrid.Columns>
                                                </DataGrid>
                                            </Grid>
                                        </TabItem>
                                        <TabItem Header="Técnico">
                                            <Grid Margin="8">
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="120"/>
                                                    <ColumnDefinition Width="*"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Text="QoS técnico (Smart Queue + perfis rápidos)" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <TextBlock Grid.Row="1" Text="Política:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosPolicy" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="SQ-WAN"/>
                                                <TextBlock Grid.Row="2" Text="Interface WAN:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosIface" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="eth4"/>
                                                <TextBlock Grid.Row="3" Text="Download (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosDown" Grid.Row="3" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="100"/>
                                                <TextBlock Grid.Row="4" Text="Upload (Mbit):" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtQosUp" Grid.Row="4" Grid.Column="1" Height="28" Margin="6,0,0,8" Text="20"/>
                                                <TextBlock Grid.Row="5" Grid.ColumnSpan="2" Text="Perfis rápidos" FontSize="15" FontWeight="SemiBold" Margin="0,4,0,8"/>
                                                <WrapPanel Grid.Row="6" Grid.ColumnSpan="2" Margin="0,0,0,10">
                                                    <Button x:Name="btnQosPresetDefault" Content="Padrão" Width="100" Height="32" Margin="0,0,8,8" Background="#8FD3FF"/>
                                                    <Button x:Name="btnQosPresetCalls" Content="Voz / WhatsApp" Width="150" Height="32" Margin="0,0,8,8" Background="#F3E58A"/>
                                                    <Button x:Name="btnQosPresetMeet" Content="Reuniões" Width="120" Height="32" Margin="0,0,8,8" Background="#DDEEFF"/>
                                                    <Button x:Name="btnQosPresetGames" Content="Jogos" Width="100" Height="32" Margin="0,0,8,8" Background="#D9F5D1"/>
                                                </WrapPanel>
                                                <TextBlock Grid.Row="7" Grid.ColumnSpan="2" Text="Use esta aba se você quiser ver ou ajustar os valores técnicos diretamente." Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                                <WrapPanel Grid.Row="8" Grid.ColumnSpan="2">
                                                    <Button x:Name="btnQosRead" Content="Ler QoS" Width="120" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                                    <Button x:Name="btnQosApply" Content="Aplicar Smart Queue" Width="170" Height="34" Margin="0,0,8,0" Background="#47C37C"/>
                                                    <Button x:Name="btnQosRemove" Content="Remover QoS" Width="130" Height="34" Background="#F28585"/>
                                                </WrapPanel>
                                            </Grid>
                                        </TabItem>
                                    </TabControl>
                                </Border>
                                <Border Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Text="Saída / diagnóstico QoS" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                        <TextBox x:Name="txtQosOut" Grid.Row="1" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                                    </Grid>
                                </Border>
                            </Grid>
                        </TabItem>

                        <TabItem Header="Saída / Diagnóstico">
                            <Grid Margin="10">
                                <TextBox x:Name="txtFwOut" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                            </Grid>
                        </TabItem>
                    </TabControl>
                </Grid>
            </TabItem>

            <TabItem Header="Balanceamento / PBR">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="0.78*"/>
                        <ColumnDefinition Width="12"/>
                        <ColumnDefinition Width="1.22*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Row="0" Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="Sticky Sessions" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                            <WrapPanel Grid.Row="1" Margin="0,0,0,6">
                                <TextBlock Text="Grupo Load-Balance:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <TextBox x:Name="txtLbGroup" Width="120" Height="28" Margin="0,0,10,0" Text="G"/>
                                <Button x:Name="btnLbStatus" Content="Ver Status" Width="120" Height="32" Margin="0,0,0,0" Background="#8FD3FF"/>
                            </WrapPanel>
                            <WrapPanel Grid.Row="2">
                                <Button x:Name="btnStickyOn" Content="Ativar Sticky" Width="130" Height="32" Margin="0,0,8,0" Background="#47C37C"/>
                                <Button x:Name="btnStickyOff" Content="Remover Sticky" Width="130" Height="32" Background="#F28585"/>
                            </WrapPanel>
                        </Grid>
                    </Border>

                    <Border Grid.Row="0" Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="110"/>
                                <ColumnDefinition Width="130"/>
                                <ColumnDefinition Width="110"/>
                                <ColumnDefinition Width="170"/>
                                <ColumnDefinition Width="110"/>
                                <ColumnDefinition Width="110"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Row="0" Grid.ColumnSpan="6" Text="Forçar rota por IP (PBR)" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>
                            <TextBlock Grid.Row="1" Grid.Column="0" Text="Rule ID:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPbrRule" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,10,8" Text="100"/>
                            <TextBlock Grid.Row="1" Grid.Column="2" Text="IP da máquina:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPbrIP" Grid.Row="1" Grid.Column="3" Height="28" Margin="6,0,10,8"/>
                            <TextBlock Grid.Row="1" Grid.Column="4" Text="Tabela:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPbrTable" Grid.Row="1" Grid.Column="5" Height="28" Margin="6,0,0,8" Text="11"/>
                            <TextBlock Grid.Row="2" Grid.Column="0" Text="WAN fixa:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPbrWan" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,10,8" Text="eth0"/>
                            <TextBlock Grid.Row="2" Grid.Column="2" Text="Firewall Modify:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtPbrModify" Grid.Row="2" Grid.Column="3" Height="28" Margin="6,0,10,8" Text="balance"/>
                            <TextBlock Grid.Row="2" Grid.Column="4" Text="Modo:" VerticalAlignment="Center"/>
                            <ComboBox x:Name="cmbPbrMode" Grid.Row="2" Grid.Column="5" Height="28" Margin="6,0,0,8" SelectedIndex="0">
                                <ComboBoxItem Content="Saída fixa"/>
                                <ComboBoxItem Content="Preferir WAN1"/>
                                <ComboBoxItem Content="Preferir WAN2"/>
                            </ComboBox>
                            <CheckBox x:Name="chkPbrKillSwitch" Grid.Row="3" Grid.ColumnSpan="4" Content="Kill switch: se a WAN preferida cair, este IP não usa a WAN de backup" Margin="0,2,0,8" ToolTip="Marcado = o IP fica sem saída se a WAN preferida cair. Desmarcado = tenta usar a outra WAN como backup na mesma tabela do PBR."/>
                            <Button x:Name="btnPbrApply" Grid.Row="3" Grid.Column="4" Grid.ColumnSpan="2" Width="170" Height="34" Content="Aplicar política" Background="#F7D900" HorizontalAlignment="Left" Margin="6,0,0,8"/>
                            <TextBlock Grid.Row="4" Grid.ColumnSpan="6" Text="Modo Saída fixa = prende o IP na WAN informada. Preferir WAN1/WAN2 = tenta usar a WAN escolhida e, sem kill switch, usa a outra como backup." Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,6"/>
                            <TextBlock Grid.Row="5" Grid.ColumnSpan="6" Text="Dica: use 'Usar Selecionado no PBR' para preencher o IP a partir da lista de leases abaixo." Foreground="#666666" TextWrapping="Wrap"/>
                        </Grid>
                    </Border>

                    <Border Grid.Row="2" Grid.ColumnSpan="3" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <WrapPanel Margin="0">
                            <TextBlock Text="WAN 1:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="txtLbWan1" Width="100" Height="28" Margin="0,0,12,0" Text="eth0"/>
                            <TextBlock Text="WAN 2:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="txtLbWan2" Width="100" Height="28" Margin="0,0,12,0" Text="eth1"/>
                            <TextBlock Text="Peso WAN1:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="txtLbWeight1" Width="70" Height="28" Margin="0,0,12,0" Text="50"/>
                            <TextBlock Text="Peso WAN2:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="txtLbWeight2" Width="70" Height="28" Margin="0,0,12,0" Text="50"/>
                            <Button x:Name="btnLbPreset5050" Content="50/50" Width="80" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                            <Button x:Name="btnLbApplyWeights" Content="Aplicar Pesos" Width="140" Height="34" Margin="0,0,8,0" Background="#47C37C"/>
                            <Button x:Name="btnLbFailoverWan1" Content="WAN1 Principal" Width="150" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                            <Button x:Name="btnLbFailoverWan2" Content="WAN2 Principal" Width="150" Height="34" Background="#8FD3FF"/>
                        </WrapPanel>
                    </Border>

                    <Grid Grid.Row="4" Grid.ColumnSpan="3">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="1*"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="1*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                            <TabControl>
                                <TabItem Header="Leases para usar no PBR">
                                    <Grid Margin="6">
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                        </Grid.RowDefinitions>
                                        <WrapPanel Margin="0,0,0,8">
                                            <Button x:Name="btnPbrLoadLeases" Content="Ler Leases do PBR" Width="160" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                            <Button x:Name="btnPbrUseLease" Content="Usar Selecionado no PBR" Width="190" Height="34" Margin="0,0,8,0" Background="#F3E58A"/>
                                        </WrapPanel>
                                        <DataGrid x:Name="dgPbrLeases" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" FontFamily="Consolas" FontSize="13">
                                            <DataGrid.Columns>
                                                <DataGridTextColumn Header="Tipo" Binding="{Binding Tipo}" Width="60"/>
                                                <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="120"/>
                                                <DataGridTextColumn Header="MAC" Binding="{Binding MAC}" Width="160"/>
                                                <DataGridTextColumn Header="Nome" Binding="{Binding Nome}" Width="*"/>
                                            </DataGrid.Columns>
                                        </DataGrid>
                                    </Grid>
                                </TabItem>
                                <TabItem Header="Políticas PBR">
                                    <Grid Margin="6">
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                        </Grid.RowDefinitions>
                                        <WrapPanel Margin="0,0,0,8">
                                            <Button x:Name="btnPbrReadPolicies" Content="Ler Políticas PBR" Width="160" Height="34" Margin="0,0,8,0" Background="#8FD3FF"/>
                                            <Button x:Name="btnPbrRemovePolicy" Content="Remover Política Selecionada" Width="210" Height="34" Margin="0,0,8,0" Background="#F28585"/>
                                        </WrapPanel>
                                        <DataGrid x:Name="dgPbrPolicies" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" FontFamily="Consolas" FontSize="13">
                                            <DataGrid.Columns>
                                                <DataGridTextColumn Header="Regra" Binding="{Binding Rule}" Width="70"/>
                                                <DataGridTextColumn Header="IP" Binding="{Binding Source}" Width="120"/>
                                                <DataGridTextColumn Header="Tabela" Binding="{Binding Table}" Width="70"/>
                                                <DataGridTextColumn Header="WAN" Binding="{Binding Wan}" Width="110"/>
                                                <DataGridTextColumn Header="Tipo" Binding="{Binding Kind}" Width="70"/>
                                                <DataGridTextColumn Header="Descrição" Binding="{Binding Description}" Width="*"/>
                                            </DataGrid.Columns>
                                        </DataGrid>
                                    </Grid>
                                </TabItem>
                            </TabControl>
                        </Border>
                        <Border Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Text="Saída / diagnóstico do balanceamento" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <TextBox x:Name="txtLbOut" Grid.Row="1" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>
            </TabItem>

            <TabItem Header="DNS / Bloqueios">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="1.2*"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.05*"/>
                        <ColumnDefinition Width="12"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Row="0" Grid.ColumnSpan="3" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <WrapPanel>
                            <TextBlock Text="Domínio:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="txtDnsDomain" Width="280" Height="28" Margin="0,0,8,8"/>
                            <Button x:Name="btnDnsReadBlocked" Content="Ler Sites Bloqueados" Width="170" Height="34" Margin="0,0,8,8" Background="#8FD3FF"/>
                            <Button x:Name="btnBlockSite" Content="Bloquear Site" Width="140" Height="34" Margin="0,0,8,8" Background="#47C37C"/>
                            <Button x:Name="btnUnblockSite" Content="Desbloquear Site" Width="160" Height="34" Margin="0,0,8,8" Background="#F28585"/>
                            <Button x:Name="btnDnsRulesList" Content="Listar Regras DNS / DoH" Width="190" Height="34" Background="#F6F8FA"/>
                        </WrapPanel>
                    </Border>

                    <Border Grid.Row="2" Grid.Column="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="Sites bloqueados" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                            <ListBox x:Name="lstDnsDomains" Grid.Row="1" FontFamily="Consolas" FontSize="13"/>
                        </Grid>
                    </Border>

                    <Border Grid.Row="2" Grid.Column="2" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="Saída / diagnóstico DNS" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
                            <TextBox x:Name="txtDnsOut" Grid.Row="1" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                        </Grid>
                    </Border>

                    <Border Grid.Row="4" Grid.ColumnSpan="3" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="160"/>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="160"/>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <TextBlock Grid.Row="0" Grid.ColumnSpan="9" Text="Interceptação DNS e bloqueio básico de DoH" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10"/>

                            <TextBlock Grid.Row="1" Grid.Column="0" Text="Interface LAN:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtDnsLan" Grid.Row="1" Grid.Column="1" Height="28" Margin="6,0,10,8" Text="switch0"/>
                            <TextBlock Grid.Row="1" Grid.Column="2" Text="IP do roteador:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtDnsRouterIp" Grid.Row="1" Grid.Column="3" Height="28" Margin="6,0,10,8" Text="192.168.1.1"/>
                            <TextBlock Grid.Row="1" Grid.Column="4" Text="Regra NAT DNS:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtDnsHijackRule" Grid.Row="1" Grid.Column="5" Height="28" Margin="6,0,10,8" Text="53"/>
                            <Button x:Name="btnDnsHijackOn" Grid.Row="1" Grid.Column="6" Width="150" Height="34" Content="Ativar Interceptação" Background="#47C37C" Margin="10,0,8,8"/>
                            <Button x:Name="btnDnsHijackOff" Grid.Row="1" Grid.Column="7" Width="150" Height="34" Content="Remover Interceptação" Background="#F28585" Margin="10,0,0,8"/>

                            <TextBlock Grid.Row="2" Grid.Column="0" Text="Regra NAT DoH:" VerticalAlignment="Center"/>
                            <TextBox x:Name="txtDohRule" Grid.Row="2" Grid.Column="1" Height="28" Margin="6,0,10,0" Text="443"/>
                            <Button x:Name="btnDohOn" Grid.Row="2" Grid.Column="6" Width="150" Height="34" Content="Ativar Bloqueio DoH" Background="#F3E58A" Margin="10,0,8,0"/>
                            <Button x:Name="btnDohOff" Grid.Row="2" Grid.Column="7" Width="160" Height="34" Content="Remover Bloqueio DoH" Background="#F6F8FA" Margin="10,0,0,0"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

<TabItem Header="Ferramentas / Log">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="12"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" BorderThickness="1" BorderBrush="#D0D7DE" Background="White" Padding="10">
                        <StackPanel>
                            <WrapPanel>
                                <TextBlock Text="Host/IP:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <TextBox x:Name="txtToolHost" Width="220" Height="28" Margin="0,0,8,8"/>
                                <Button x:Name="btnPing" Content="Ping" Width="100" Height="34" Margin="0,0,8,8" Background="#8FD3FF"/>
                                <Button x:Name="btnDnsLookup" Content="DNS Test" Width="120" Height="34" Margin="0,0,8,8" Background="#8FD3FF"/>
                                <Button x:Name="btnBackup" Content="Backup da Config" Width="150" Height="34" Margin="0,0,8,8" Background="#47C37C"/>
                                <Button x:Name="btnOpenLogs" Content="Abrir Pasta Logs" Width="150" Height="34" Margin="0,0,8,8" Background="#F6F8FA"/>
                            </WrapPanel>
                            <Separator Margin="0,4,0,8"/>
                            <WrapPanel>
                                <Button x:Name="btnPerfRead" Content="Ler Status DPI/Offload" Width="180" Height="34" Margin="0,0,8,8" Background="#8FD3FF"/>
                                <Button x:Name="btnPerfAnalysis" Content="Modo análise de tráfego" Width="190" Height="34" Margin="0,0,8,8" Background="#F3E58A"/>
                                <Button x:Name="btnPerfPerformance" Content="Modo desempenho" Width="160" Height="34" Margin="0,0,8,8" Background="#47C37C"/>
                            </WrapPanel>
                            <TextBlock x:Name="txtPerfExplain" TextWrapping="Wrap" Foreground="#44546A" Margin="0,2,0,0" Text="DPI ligado = melhor para investigar consumo por aplicação. Pode reduzir desempenho. Modo desempenho = desliga DPI/export e tenta religar offload para o dia a dia."/>
                        </StackPanel>
                    </Border>
                    <TextBox x:Name="txtLog" Grid.Row="2" FontFamily="Consolas" FontSize="13" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Visible" IsReadOnly="True"/>
                </Grid>
            </TabItem>
        </TabControl>
    </DockPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'txtIp','txtUser','txtPass','btnTestConn','btnAbout','btnLangToggle','txtStatus',
    'btnDashResumo','btnDashRede','btnDashLeases','txtDashOut',
    'btnDhcpLer','btnDhcpLerReservas','dgDhcpLeases','dgDhcpReservations','txtDhcpOut','txtPool','txtSubnet','txtHost','txtMac','txtIpFix','btnUsarLease','btnCriarReserva','btnRemoverReserva','btnLimparDhcp',
    'txtRuleNat','txtInIf','txtPortExt','txtIPInt','txtPortInt','cmbNatProto','txtDescNat','btnNatListar','btnNatCriar','txtNatOut',
    'tabFwSub','txtFwName','txtFwRule','cmbFwAction','txtFwSource','txtFwDest','cmbFwProto','txtFwPort','txtFwDesc','btnFwListar','btnFwCriar','btnFwBlockInternet','btnFwAllowWebDns','btnFwBlockPort','btnFwReadManaged','btnFwRemoveManaged','dgFwManaged','txtFwInline','txtFwOut','txtTraceIp','txtTraceSeconds','cmbTraceIface','btnTraceConntrack','btnTraceTcpdump','txtTraceSearch','btnTraceSearch','txtTraceOut','tabQosSub','cmbQosFriendlyGoal','cmbQosFriendlyLevel','txtQosFriendlyIface','txtQosFriendlyPolicy','txtQosFriendlyDownReal','txtQosFriendlyUpReal','txtQosFriendlyDownApply','txtQosFriendlyUpApply','txtQosFriendlyExplain','btnQosFriendlyPreview','btnQosFriendlyRead','btnQosFriendlyApply','btnQosFriendlyRemove','txtQosDevIp','txtQosDevDown','txtQosDevUp','txtQosDevTotalDown','txtQosDevTotalUp','txtQosDevNote','btnQosDevUseLease','btnQosDevRead','btnQosDevApply','btnQosDevRemove','dgQosDevicePolicies','txtQosPolicy','txtQosIface','txtQosDown','txtQosUp','btnQosPresetDefault','btnQosPresetCalls','btnQosPresetMeet','btnQosPresetGames','btnQosRead','btnQosApply','btnQosRemove','txtQosOut','btnP2PRead','btnP2PBlock','btnP2PRemove',
    'txtLbGroup','btnLbStatus','btnStickyOn','btnStickyOff','txtPbrRule','txtPbrIP','txtPbrWan','txtPbrTable','txtPbrModify','cmbPbrMode','btnPbrApply','chkPbrKillSwitch','txtLbWan1','txtLbWan2','txtLbWeight1','txtLbWeight2','btnLbPreset5050','btnLbApplyWeights','btnLbFailoverWan1','btnLbFailoverWan2','btnPbrLoadLeases','btnPbrUseLease','btnPbrReadPolicies','btnPbrRemovePolicy','dgPbrLeases','dgPbrPolicies','txtLbOut',
    'txtDnsDomain','btnDnsReadBlocked','btnBlockSite','btnUnblockSite','btnDnsRulesList','lstDnsDomains','txtDnsOut','txtDnsLan','txtDnsRouterIp','txtDnsHijackRule','btnDnsHijackOn','btnDnsHijackOff','txtDohRule','btnDohOn','btnDohOff',
    'txtToolHost','btnPing','btnDnsLookup','btnBackup','btnOpenLogs','btnPerfRead','btnPerfAnalysis','btnPerfPerformance','txtPerfExplain','txtLog'
)
foreach ($n in $names) { Set-Variable -Name $n -Value $window.FindName($n) -Scope Script }

if ($ip) { $txtIp.Text = $ip }
if ($user) { $txtUser.Text = $user }
if ($pass) { $txtPass.Password = $pass }
if ($cmbQosFriendlyGoal -and $cmbQosFriendlyGoal.Items.Count -gt 0 -and $cmbQosFriendlyGoal.SelectedIndex -lt 0) { $cmbQosFriendlyGoal.SelectedIndex = 0 }
if ($cmbTraceIface -and $cmbTraceIface.Items.Count -gt 0 -and $cmbTraceIface.SelectedIndex -lt 0) { $cmbTraceIface.SelectedIndex = 0 }
if ($cmbQosFriendlyLevel -and $cmbQosFriendlyLevel.Items.Count -gt 0 -and $cmbQosFriendlyLevel.SelectedIndex -lt 0) { $cmbQosFriendlyLevel.SelectedIndex = 1 }
Update-QosFriendlyPreview

$window.Add_ContentRendered({
    try {
        $wa = [System.Windows.SystemParameters]::WorkArea
        $left = [Math]::Round($wa.Left + [Math]::Max(0, (($wa.Width - $window.ActualWidth) / 2)))
        $top = [Math]::Round($wa.Top + [Math]::Max(24, (($wa.Height - $window.ActualHeight) / 2)))
        $window.Left = $left
        $window.Top = $top
        if ($window.Top -lt ($wa.Top + 24)) { $window.Top = $wa.Top + 24 }
    } catch {}
})

if ($btnLangToggle) { $btnLangToggle.Add_Click({ Toggle-UiLanguage }) }

$btnAbout.Add_Click({
    Show-UiMessage -Title (Get-UiText 'Sobre a versão WPF') -Message (Get-UiText "Isto é um protótipo WPF paralelo ao fix16.`r`n`r`nObjetivo:`r`n- comparar aproveitamento de espaço`r`n- testar grids, rolagem e layout`r`n- preservar a lógica PowerShell/SSH que já funcionou no fix16`r`n- testar perfis rápidos de QoS, PBR por WAN e o modo WAN preferida com kill switch")
})

$btnTestConn.Add_Click({
    try {
        $btnTestConn.Content = (Get-UiText 'Testando...')
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        $out = Invoke-EdgeRouterCommand -Command 'show version | head -n 3'
        Show-UiMessage -Title (Get-UiText 'Conexão OK') -Message ((Get-UiText 'Conexão SSH bem-sucedida.') + "`r`n`r`n" + $out)
        Write-AppLog 'Teste SSH executado com sucesso.'
    } catch {
        Show-UiMessage -Title (Get-UiText 'Erro de conexão') -Message $_.Exception.Message -Icon 'Error'
        Write-AppLog "Falha no teste SSH: $($_.Exception.Message)" 'ERROR'
    } finally {
        $btnTestConn.Content = (Get-UiText 'Testar SSH')
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

$btnDashResumo.Add_Click({ try { Refresh-DashboardSummary } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnDashRede.Add_Click({ try { Refresh-DashboardInterfaces } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnDashLeases.Add_Click({ try { Refresh-DashboardDhcp } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })

$btnDhcpLer.Add_Click({ try { Refresh-DhcpLeases; Refresh-PbrLeaseCandidates } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnDhcpLerReservas.Add_Click({ try { Refresh-DhcpReservations; Refresh-PbrLeaseCandidates } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$dgDhcpLeases.Add_SelectionChanged({ if ($dgDhcpLeases.SelectedItem) { Apply-SelectedLeaseToDhcpFields } })
$dgDhcpReservations.Add_SelectionChanged({ if ($dgDhcpReservations.SelectedItem) { Apply-SelectedReservationToDhcpFields } })
$btnUsarLease.Add_Click({ Apply-SelectedLeaseToDhcpFields })
$btnLimparDhcp.Add_Click({ $txtPool.Text='LAN'; $txtSubnet.Text='192.168.1.0/24'; $txtHost.Text=''; $txtMac.Text=''; $txtIpFix.Text='' })

$btnCriarReserva.Add_Click({
    try {
        $pool = $txtPool.Text.Trim()
        $sub = $txtSubnet.Text.Trim()
        $name = Normalize-EdgeName -Value $txtHost.Text.Trim() -Default 'host_reservado'
        $mac = $txtMac.Text.Trim()
        $ipfix = $txtIpFix.Text.Trim()
        if (-not $pool -or -not $sub -or -not $mac -or -not $ipfix) { throw 'Preencha pool, sub-rede, MAC e IP.' }
        if (-not (Test-IPv4Address $ipfix)) { throw 'IP fixo inválido.' }
        if (-not (Test-MacAddress $mac)) { throw 'MAC inválido.' }
        if (-not (Confirm-UiAction "Criar reserva DHCP para $name ($ipfix)?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dhcp-server shared-network-name $pool subnet $sub static-mapping $name ip-address $ipfix",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dhcp-server shared-network-name $pool subnet $sub static-mapping $name mac-address $mac"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Reserva_DHCP_$name"
        Set-OutputText -Target $txtDhcpOut -Content $out -Title 'Resultado da reserva DHCP'
        Write-AppLog "Reserva DHCP criada: $name / $ipfix / $mac"
        Refresh-DhcpReservations
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnRemoverReserva.Add_Click({
    try {
        $pool = $txtPool.Text.Trim(); $sub = $txtSubnet.Text.Trim(); $name = Normalize-EdgeName -Value $txtHost.Text.Trim() -Default ''
        if (-not $pool -or -not $sub -or -not $name) { throw 'Informe pool, sub-rede e nome da reserva.' }
        if (-not (Confirm-UiAction "Remover a reserva DHCP do host $name?")) { return }
        $out = Invoke-EdgeConfigCommand -Commands @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dhcp-server shared-network-name $pool subnet $sub static-mapping $name") -Reason "Remove_Reserva_DHCP_$name"
        Set-OutputText -Target $txtDhcpOut -Content $out -Title 'Resultado da remoção'
        Write-AppLog "Reserva DHCP removida: $name"
        Refresh-DhcpReservations
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnLbStatus.Add_Click({ try { Refresh-LoadBalanceStatus } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnLbPreset5050.Add_Click({ $txtLbWeight1.Text='50'; $txtLbWeight2.Text='50' })

$btnLbApplyWeights.Add_Click({
    try {
        $g = $txtLbGroup.Text.Trim(); $wan1 = $txtLbWan1.Text.Trim(); $wan2 = $txtLbWan2.Text.Trim()
        $n1 = 0; $n2 = 0
        if (-not $g -or -not $wan1 -or -not $wan2 -or -not [int]::TryParse($txtLbWeight1.Text.Trim(), [ref]$n1) -or -not [int]::TryParse($txtLbWeight2.Text.Trim(), [ref]$n2)) { throw 'Informe grupo, WANs e pesos válidos.' }
        if (-not (Confirm-UiAction "Aplicar pesos $n1/$n2 no grupo $g?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete load-balance group $g interface $wan1 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete load-balance group $g interface $wan2 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan1 weight $n1",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan2 weight $n2"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "LB_Pesos_$g"
        Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado do balanceamento por peso'
        Refresh-LoadBalanceStatus
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnLbFailoverWan1.Add_Click({
    try {
        $g = $txtLbGroup.Text.Trim(); $wan1 = $txtLbWan1.Text.Trim(); $wan2 = $txtLbWan2.Text.Trim()
        if (-not (Confirm-UiAction "Deixar $wan1 como principal e $wan2 como backup?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete load-balance group $g interface $wan1 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan2 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan1 weight 100",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan2 weight 100"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "LB_Failover_WAN1"
        Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado do failover'
        Refresh-LoadBalanceStatus
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnLbFailoverWan2.Add_Click({
    try {
        $g = $txtLbGroup.Text.Trim(); $wan1 = $txtLbWan1.Text.Trim(); $wan2 = $txtLbWan2.Text.Trim()
        if (-not (Confirm-UiAction "Deixar $wan2 como principal e $wan1 como backup?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan1 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete load-balance group $g interface $wan2 failover-only",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan1 weight 100",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g interface $wan2 weight 100"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "LB_Failover_WAN2"
        Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado do failover'
        Refresh-LoadBalanceStatus
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnStickyOn.Add_Click({
    try {
        $g = $txtLbGroup.Text.Trim(); if (-not $g) { throw 'Informe o grupo de load-balance.' }
        if (-not (Confirm-UiAction "Ativar sticky sessions no grupo $g?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g sticky source-addr enable",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g sticky dest-addr enable",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set load-balance group $g sticky dest-port enable"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Sticky_$g"
        Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado do sticky'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnStickyOff.Add_Click({
    try {
        $g = $txtLbGroup.Text.Trim(); if (-not $g) { throw 'Informe o grupo de load-balance.' }
        if (-not (Confirm-UiAction "Remover sticky sessions do grupo $g?")) { return }
        $out = Invoke-EdgeConfigCommand -Commands @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete load-balance group $g sticky") -Reason "Remove_Sticky_$g"
        Set-OutputText -Target $txtLbOut -Content $out -Title 'Resultado da remoção do sticky'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnPbrLoadLeases.Add_Click({ try { Refresh-DhcpLeases; Refresh-DhcpReservations; Refresh-PbrLeaseCandidates } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnPbrUseLease.Add_Click({ if ($dgPbrLeases.SelectedItem) { $txtPbrIP.Text = [string]$dgPbrLeases.SelectedItem.IP } })
$btnPbrReadPolicies.Add_Click({ try { Refresh-PbrPolicies } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnPbrRemovePolicy.Add_Click({ try { if ($dgPbrPolicies.SelectedItem) { Remove-PbrPolicyInternal -Policy $dgPbrPolicies.SelectedItem } else { throw 'Selecione uma política PBR para remover.' } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$dgPbrPolicies.Add_SelectionChanged({
    try {
        $item = $dgPbrPolicies.SelectedItem
        if ($item) {
            $txtPbrRule.Text = [string]$item.Rule
            $txtPbrIP.Text = [string]$item.Source
            $txtPbrTable.Text = [string]$item.Table
            $txtPbrModify.Text = [string]$item.Modify
            if ($item.Wan -and ($item.Wan -notlike 'gateway:*')) { $txtPbrWan.Text = [string]$item.Wan }
        }
    } catch {}
})

$cmbPbrMode.Add_SelectionChanged({
    try {
        if (-not $cmbPbrMode.SelectedItem) { return }
        $modeKey = Get-PbrModeKey $cmbPbrMode.SelectedItem
        switch ($modeKey) {
            'prefer1' { $txtPbrWan.Text = $txtLbWan1.Text.Trim() }
            'prefer2' { $txtPbrWan.Text = $txtLbWan2.Text.Trim() }
            default { }
        }
    } catch {}
})

$btnPbrApply.Add_Click({
    try {
        if (-not $cmbPbrMode.SelectedItem) { throw (Get-UiText 'Selecione um modo para a política de PBR.') }
        $modeKey = Get-PbrModeKey $cmbPbrMode.SelectedItem
        switch ($modeKey) {
            'fixed' {
                Invoke-PbrCreateInternal -Rule $txtPbrRule.Text.Trim() -IpAddress $txtPbrIP.Text.Trim() -WanInterface $txtPbrWan.Text.Trim() -Table $txtPbrTable.Text.Trim() -Modify $txtPbrModify.Text.Trim() -Reason "PBR_$($txtPbrIP.Text.Trim())"
            }
            'prefer1' {
                $txtPbrWan.Text = $txtLbWan1.Text.Trim()
                Invoke-PbrPreferredPolicyInternal -Rule $txtPbrRule.Text.Trim() -IpAddress $txtPbrIP.Text.Trim() -PreferredWan $txtLbWan1.Text.Trim() -BackupWan $txtLbWan2.Text.Trim() -Table $txtPbrTable.Text.Trim() -Modify $txtPbrModify.Text.Trim() -KillSwitch ([bool]$chkPbrKillSwitch.IsChecked) -Reason "PBR_PREFER_WAN1_$($txtPbrIP.Text.Trim())" -ConfirmLabel "Aplicar política preferindo $($txtLbWan1.Text.Trim()) para $($txtPbrIP.Text.Trim())?"
            }
            'prefer2' {
                $txtPbrWan.Text = $txtLbWan2.Text.Trim()
                Invoke-PbrPreferredPolicyInternal -Rule $txtPbrRule.Text.Trim() -IpAddress $txtPbrIP.Text.Trim() -PreferredWan $txtLbWan2.Text.Trim() -BackupWan $txtLbWan1.Text.Trim() -Table $txtPbrTable.Text.Trim() -Modify $txtPbrModify.Text.Trim() -KillSwitch ([bool]$chkPbrKillSwitch.IsChecked) -Reason "PBR_PREFER_WAN2_$($txtPbrIP.Text.Trim())" -ConfirmLabel "Aplicar política preferindo $($txtLbWan2.Text.Trim()) para $($txtPbrIP.Text.Trim())?"
            }
            default { throw (Get-UiText 'Modo de PBR não reconhecido.') }
        }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDnsReadBlocked.Add_Click({ try { Refresh-DnsBlockedDomains } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$lstDnsDomains.Add_SelectionChanged({ if ($lstDnsDomains.SelectedItem) { $txtDnsDomain.Text = [string]$lstDnsDomains.SelectedItem } })

$btnBlockSite.Add_Click({
    try {
        $domain = $txtDnsDomain.Text.Trim().ToLower()
        if (-not $domain) { throw 'Informe um domínio.' }
        if (-not (Confirm-UiAction "Bloquear o domínio $domain?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/$domain/0.0.0.0"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Block_DNS_$domain"
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Resultado do bloqueio DNS'
        Refresh-DnsBlockedDomains
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnUnblockSite.Add_Click({
    try {
        $domain = $txtDnsDomain.Text.Trim().ToLower()
        if (-not $domain) { throw 'Informe um domínio.' }
        if (-not (Confirm-UiAction "Desbloquear o domínio $domain?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/$domain/0.0.0.0"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Unblock_DNS_$domain"
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Resultado do desbloqueio DNS'
        Refresh-DnsBlockedDomains
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})


$btnNatListar.Add_Click({
    try {
        $out = Invoke-EdgeRouterCommand -Command '/opt/vyatta/bin/vyatta-op-cmd-wrapper show port-forward'
        Set-OutputText -Target $txtNatOut -Content $out -Title 'Port Forward atual'
        Write-AppLog 'Leitura de port forward executada.'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnNatCriar.Add_Click({
    try {
        $ruleId = $txtRuleNat.Text.Trim()
        $inIf = $txtInIf.Text.Trim()
        $pExt = $txtPortExt.Text.Trim()
        $ipInt = $txtIPInt.Text.Trim()
        $pInt = $txtPortInt.Text.Trim()
        $proto = if ($cmbNatProto.SelectedItem) { $cmbNatProto.SelectedItem.Content.ToString() } else { 'tcp' }
        $desc = $txtDescNat.Text.Trim()
        if (-not $inIf -or -not $pExt -or -not $ipInt -or -not $pInt) { throw 'Preencha interface WAN, porta externa, IP interno e porta interna.' }
        if (-not (Test-PortNumber $pExt) -or -not (Test-PortNumber $pInt)) { throw 'As portas devem estar entre 1 e 65535.' }
        if (-not (Test-IPv4Address $ipInt)) { throw 'IP interno inválido.' }
        if (-not $ruleId) { $ruleId = Get-Random -Minimum 100 -Maximum 9999 }
        if (-not $desc) { $desc = "App_PortForward_$ruleId" }
        if (-not (Confirm-UiAction "Criar port forward $pExt -> ${ipInt}:$pInt ?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward auto-firewall enable",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward hairpin-nat enable",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward wan-interface $inIf",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward rule $ruleId description '$desc'",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward rule $ruleId original-port $pExt",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward rule $ruleId protocol $proto",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward rule $ruleId forward-to address $ipInt",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set port-forward rule $ruleId forward-to port $pInt"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "PortForward_$ruleId"
        Set-OutputText -Target $txtNatOut -Content $out -Title 'Resultado do port forward'
        Write-AppLog "Port forward criado: regra $ruleId / $pExt -> ${ipInt}:$pInt / $proto"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})



function Get-TraceFriendlySummary {
    param(
        [string]$RawText,
        [string]$IpTarget,
        [ValidateSet('conntrack','tcpdump')][string]$Mode
    )
    if ([string]::IsNullOrWhiteSpace($RawText)) { return $RawText }
    $peerStats = @{}
    $protoStats = @{}
    $lineCount = 0
    $totalBytes = 0

    foreach ($line in ($RawText -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $lineCount++
        $proto = ''
        $peerKey = ''
        $extra = ''

        if ($Mode -eq 'tcpdump') {
            $m = [regex]::Match($line, 'IP\s+(?<src>(?:\d{1,3}\.){3}\d{1,3})\.(?<sport>\d+)\s+>\s+(?<dst>(?:\d{1,3}\.){3}\d{1,3})\.(?<dport>\d+):\s+(?<proto>[A-Z]+).*?(?:length\s+(?<len>\d+))?')
            if (-not $m.Success) { continue }
            $src = $m.Groups['src'].Value
            $dst = $m.Groups['dst'].Value
            $sport = $m.Groups['sport'].Value
            $dport = $m.Groups['dport'].Value
            $proto = $m.Groups['proto'].Value.ToUpperInvariant()
            $len = 0
            if ($m.Groups['len'].Success) { [void][int]::TryParse($m.Groups['len'].Value, [ref]$len) }
            $totalBytes += $len
            if ($src -eq $IpTarget) {
                $peerKey = "${dst}:$dport"
                $extra = 'saindo'
            } elseif ($dst -eq $IpTarget) {
                $peerKey = "${src}:$sport"
                $extra = 'entrando'
            } else {
                $peerKey = "${src}:$sport"
            }
        } else {
            $m = [regex]::Match($line, '^(?<proto>tcp|udp|icmp)\s+\d+\s+\d+\s+(?<state>\S+)?\s*src=(?<src>(?:\d{1,3}\.){3}\d{1,3})\s+dst=(?<dst>(?:\d{1,3}\.){3}\d{1,3}).*?sport=(?<sport>\d+)\s+dport=(?<dport>\d+)')
            if (-not $m.Success) { continue }
            $src = $m.Groups['src'].Value
            $dst = $m.Groups['dst'].Value
            $sport = $m.Groups['sport'].Value
            $dport = $m.Groups['dport'].Value
            $proto = $m.Groups['proto'].Value.ToUpperInvariant()
            $state = $m.Groups['state'].Value
            if ($src -eq $IpTarget) {
                $peerKey = "${dst}:$dport"
                $extra = if ($state) { "saindo / $state" } else { 'saindo' }
            } elseif ($dst -eq $IpTarget) {
                $peerKey = "${src}:$sport"
                $extra = if ($state) { "entrando / $state" } else { 'entrando' }
            } else {
                $peerKey = "${src}:$sport"
            }
        }

        if (-not $protoStats.ContainsKey($proto)) { $protoStats[$proto] = 0 }
        $protoStats[$proto]++

        if (-not $peerStats.ContainsKey($peerKey)) {
            $peerStats[$peerKey] = [ordered]@{ Packets = 0; Proto = $proto; Extra = $extra }
        }
        $peerStats[$peerKey].Packets++
        if (-not $peerStats[$peerKey].Extra -and $extra) { $peerStats[$peerKey].Extra = $extra }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Resumo amigável para $IpTarget")
    [void]$sb.AppendLine(('=' * 32))
    [void]$sb.AppendLine("Modo: $Mode")
    [void]$sb.AppendLine("Linhas analisadas: $lineCount")
    if ($Mode -eq 'tcpdump' -and $totalBytes -gt 0) {
        [void]$sb.AppendLine("Bytes aproximados capturados: $totalBytes")
    }
    if ($protoStats.Count -gt 0) {
        [void]$sb.AppendLine('Protocolos mais vistos:')
        foreach ($kv in $protoStats.GetEnumerator() | Sort-Object Value -Descending) {
            [void]$sb.AppendLine(("- {0}: {1}" -f $kv.Key, $kv.Value))
        }
    }
    if ($peerStats.Count -gt 0) {
        [void]$sb.AppendLine('Destinos/pares mais frequentes:')
        foreach ($item in ($peerStats.GetEnumerator() | Sort-Object {$_.Value.Packets} -Descending | Select-Object -First 8)) {
            $peer = $item.Key
            $packets = $item.Value.Packets
            $proto = $item.Value.Proto
            $extra = $item.Value.Extra
            if ($extra) {
                [void]$sb.AppendLine(("- {0} | {1} | {2} pacotes | {3}" -f $peer, $proto, $packets, $extra))
            } else {
                [void]$sb.AppendLine(("- {0} | {1} | {2} pacotes" -f $peer, $proto, $packets))
            }
        }
        $topPeer = ($peerStats.GetEnumerator() | Sort-Object {$_.Value.Packets} -Descending | Select-Object -First 1).Key
        if ($topPeer) {
            $ipOnly = ($topPeer -split ':')[0]
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("Sugestão de pesquisa: $topPeer")
            [void]$sb.AppendLine("IP principal observado: $ipOnly")
        }
    } else {
        [void]$sb.AppendLine('Nenhum padrão útil foi reconhecido automaticamente no texto retornado.')
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Saída bruta:')
    [void]$sb.AppendLine(('=' * 12))
    [void]$sb.AppendLine($RawText)
    return $sb.ToString().TrimEnd()
}

function Show-FirewallTraceConntrack {
    $ipTarget = ''
    if ($script:txtTraceIp -and $script:txtTraceIp.Text) { $ipTarget = $script:txtTraceIp.Text.Trim() }
    if (-not $ipTarget -and $script:txtFwSource -and $script:txtFwSource.Text) { $ipTarget = $script:txtFwSource.Text.Trim() }
    if (-not (Test-IPv4Address $ipTarget)) { throw 'Informe um IP alvo válido.' }
    $script:txtTraceIp.Text = $ipTarget
    $out = $null
    $tryCommands = @(
        "sudo conntrack -L | grep $ipTarget",
        "conntrack -L | grep $ipTarget",
        "/opt/vyatta/bin/vyatta-op-cmd-wrapper show conntrack table ipv4 | grep $ipTarget"
    )
    foreach ($cmd in $tryCommands) {
        try {
            $out = Invoke-EdgeRouterCommand -Command $cmd -Silent
            if (-not [string]::IsNullOrWhiteSpace($out)) { break }
        } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($out)) { $out = 'Nenhuma conexão ativa encontrada para este IP.' }
    $friendly = Get-TraceFriendlySummary -RawText $out -IpTarget $ipTarget -Mode conntrack
    $m = [regex]::Match($friendly, 'Sugestão de pesquisa:\s+(?<q>.+)')
    if ($m.Success -and $script:txtTraceSearch) {
        $script:txtTraceSearch.Text = $m.Groups['q'].Value.Trim()
    }
    Set-OutputText -Target $txtTraceOut -Content $friendly -Title ('Conntrack de ' + $ipTarget)
    Write-AppLog "Conexões ativas consultadas para $ipTarget"
}

function Show-FirewallTraceTcpdump {
    $ipTarget = ''
    if ($script:txtTraceIp -and $script:txtTraceIp.Text) { $ipTarget = $script:txtTraceIp.Text.Trim() }
    if (-not $ipTarget -and $script:txtFwSource -and $script:txtFwSource.Text) { $ipTarget = $script:txtFwSource.Text.Trim() }
    if (-not (Test-IPv4Address $ipTarget)) { throw 'Informe um IP alvo válido.' }
    $secs = 12
    if ($script:txtTraceSeconds -and $script:txtTraceSeconds.Text) { [void][int]::TryParse($script:txtTraceSeconds.Text.Trim(), [ref]$secs) }
    if ($secs -lt 3) { $secs = 3 }
    if ($secs -gt 60) { $secs = 60 }
    $iface = 'any'
    if ($script:cmbTraceIface -and $script:cmbTraceIface.SelectedItem) { $iface = [string]$script:cmbTraceIface.SelectedItem.Content }
    $out = $null
    $tryCommands = @(
        "sudo tcpdump -n -i $iface host $ipTarget -c 80",
        "tcpdump -n -i $iface host $ipTarget -c 80"
    )
    foreach ($cmd in $tryCommands) {
        try {
            $out = Invoke-EdgeRouterCommand -Command $cmd -Silent
            if (-not [string]::IsNullOrWhiteSpace($out)) { break }
        } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($out)) { $out = 'Nenhum pacote capturado nesta janela. Tente durante o download/stream do IP alvo.' }
    $friendly = Get-TraceFriendlySummary -RawText $out -IpTarget $ipTarget -Mode tcpdump
    $m = [regex]::Match($friendly, 'Sugestão de pesquisa:\s+(?<q>.+)')
    if ($m.Success -and $script:txtTraceSearch) {
        $script:txtTraceSearch.Text = $m.Groups['q'].Value.Trim()
    }
    Set-OutputText -Target $txtTraceOut -Content $friendly -Title ('Tcpdump rápido de ' + $ipTarget + ' / iface ' + $iface)
    Write-AppLog "Captura rápida executada para $ipTarget em $iface"
}

function Invoke-FirewallTraceSearch {
    $query = ''
    if ($script:txtTraceSearch -and $script:txtTraceSearch.Text) { $query = $script:txtTraceSearch.Text.Trim() }
    if (-not $query -and $script:txtTraceIp -and $script:txtTraceIp.Text) { $query = $script:txtTraceIp.Text.Trim() }
    if (-not $query) { throw 'Informe ou selecione um destino/porta para pesquisar.' }
    $url = 'https://www.google.com/search?q=' + [uri]::EscapeDataString($query)
    Start-Process $url | Out-Null
    Write-AppLog "Pesquisa aberta no navegador: $query"
}

$btnFwListar.Add_Click({
    try {
        $fwName = $txtFwName.Text.Trim()
        if (-not $fwName) { $fwName = 'LAN_IN' }
        $out = Invoke-EdgeRouterCommand -Command "/opt/vyatta/bin/vyatta-op-cmd-wrapper show firewall name $fwName"
        Set-FirewallOutput -Content $out -Title "Firewall $fwName"
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
        Refresh-AppManagedFirewallRules | Out-Null
        Write-AppLog "Leitura do firewall $fwName executada."
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnFwCriar.Add_Click({
    try {
        $fwName = $txtFwName.Text.Trim()
        $rule = $txtFwRule.Text.Trim()
        $action = if ($cmbFwAction.SelectedItem) { $cmbFwAction.SelectedItem.Content.ToString() } else { 'accept' }
        $source = $txtFwSource.Text.Trim()
        $dest = $txtFwDest.Text.Trim()
        $proto = if ($cmbFwProto.SelectedItem) { $cmbFwProto.SelectedItem.Content.ToString() } else { 'any' }
        $port = $txtFwPort.Text.Trim()
        $desc = $txtFwDesc.Text.Trim()
        if (-not $fwName -or -not $rule -or -not $action -or -not $source) { throw 'Preencha firewall name, rule ID, ação e origem.' }
        if (-not $desc) { $desc = "APP_FW_$rule" }
        if (-not (Confirm-UiAction "Criar regra $rule no firewall $fwName para $source?")) { return }
        $cmds = New-AppFirewallRuleCommands -Firewall $fwName -Rule ([int]$rule) -Action $action -Source $source -Destination $dest -Protocol $proto -Port $port -Description $desc -EnableLog
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Firewall_${fwName}_$rule"
        Set-FirewallOutput -Content $out -Title 'Resultado da regra de firewall'
        Refresh-AppManagedFirewallRules | Out-Null
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
        Write-AppLog "Regra de firewall criada: $fwName / $rule / $action / $source"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})


$btnFwBlockInternet.Add_Click({
    try {
        $fwName = $txtFwName.Text.Trim(); if (-not $fwName) { $fwName = 'LAN_IN' }
        $rule = [int]($txtFwRule.Text.Trim())
        $source = $txtFwSource.Text.Trim()
        if (-not $source) { throw 'Informe o IP de origem.' }
        $desc = "APP_BLOCK_INET_" + ($source -replace '[^0-9A-Za-z_.-]','_')
        if (-not (Confirm-UiAction "Bloquear internet do IP $source no firewall $fwName?")) { return }
        $cmds = New-AppFirewallRuleCommands -Firewall $fwName -Rule $rule -Action 'drop' -Source $source -Destination '' -Protocol 'any' -Port '' -Description $desc -EnableLog
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "FwBlockInet_${fwName}_$rule"
        Set-FirewallOutput -Content $out -Title 'Resultado do bloqueio por IP'
        Refresh-AppManagedFirewallRules | Out-Null
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnFwAllowWebDns.Add_Click({
    try {
        $fwName = $txtFwName.Text.Trim(); if (-not $fwName) { $fwName = 'LAN_IN' }
        $baseRule = [int]($txtFwRule.Text.Trim())
        $source = $txtFwSource.Text.Trim()
        if (-not $source) { throw 'Informe o IP de origem.' }
        if (-not (Confirm-UiAction "Permitir só Web/DNS para $source no firewall $fwName?")) { return }
        $safe = ($source -replace '[^0-9A-Za-z_.-]','_')
        $cmds = @()
        $cmds += New-AppFirewallRuleCommands -Firewall $fwName -Rule $baseRule -Action 'accept' -Source $source -Destination '' -Protocol 'udp' -Port '53' -Description "APP_WEBDNS_${safe}_DNS_UDP"
        $cmds += New-AppFirewallRuleCommands -Firewall $fwName -Rule ($baseRule+1) -Action 'accept' -Source $source -Destination '' -Protocol 'tcp' -Port '53' -Description "APP_WEBDNS_${safe}_DNS_TCP"
        $cmds += New-AppFirewallRuleCommands -Firewall $fwName -Rule ($baseRule+2) -Action 'accept' -Source $source -Destination '' -Protocol 'tcp' -Port '80' -Description "APP_WEBDNS_${safe}_HTTP"
        $cmds += New-AppFirewallRuleCommands -Firewall $fwName -Rule ($baseRule+3) -Action 'accept' -Source $source -Destination '' -Protocol 'tcp' -Port '443' -Description "APP_WEBDNS_${safe}_HTTPS"
        $cmds += New-AppFirewallRuleCommands -Firewall $fwName -Rule ($baseRule+4) -Action 'drop' -Source $source -Destination '' -Protocol 'any' -Port '' -Description "APP_WEBDNS_${safe}_DROP" -EnableLog
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "FwWebDns_${fwName}_$baseRule"
        Set-FirewallOutput -Content $out -Title 'Resultado do preset Web/DNS'
        Refresh-AppManagedFirewallRules | Out-Null
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnFwBlockPort.Add_Click({
    try {
        $fwName = $txtFwName.Text.Trim(); if (-not $fwName) { $fwName = 'LAN_IN' }
        $rule = [int]($txtFwRule.Text.Trim())
        $source = $txtFwSource.Text.Trim()
        $proto = if ($cmbFwProto.SelectedItem) { $cmbFwProto.SelectedItem.Content.ToString() } else { 'tcp' }
        $port = $txtFwPort.Text.Trim()
        $dest = $txtFwDest.Text.Trim()
        if (-not $source -or -not $port) { throw 'Informe origem e porta de destino.' }
        $desc = "APP_BLOCK_PORT_" + (($source + '_' + $port) -replace '[^0-9A-Za-z_.-]','_')
        if (-not (Confirm-UiAction "Bloquear porta/protocolo para $source no firewall $fwName?")) { return }
        $cmds = New-AppFirewallRuleCommands -Firewall $fwName -Rule $rule -Action 'drop' -Source $source -Destination $dest -Protocol $proto -Port $port -Description $desc -EnableLog
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "FwBlockPort_${fwName}_$rule"
        Set-FirewallOutput -Content $out -Title 'Resultado do bloqueio de porta/protocolo'
        Refresh-AppManagedFirewallRules | Out-Null
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnFwReadManaged.Add_Click({
    try {
        $items = Refresh-AppManagedFirewallRules
        Set-FirewallOutput -Content (($items | Format-Table Firewall,Rule,Action,Source,Destination,Protocol,Port,Description -AutoSize | Out-String)) -Title 'Regras do app'
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnFwRemoveManaged.Add_Click({
    try {
        $row = $dgFwManaged.SelectedItem
        if ($null -eq $row) { throw 'Selecione uma regra na grade.' }
        $fwName = [string]$row.Firewall
        $rule = [string]$row.Rule
        if (-not (Confirm-UiAction "Remover a regra $rule do firewall $fwName?")) { return }
        $cmds = @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall name $fwName rule $rule")
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "FwDelete_${fwName}_$rule"
        Set-FirewallOutput -Content $out -Title 'Remoção de regra'
        Refresh-AppManagedFirewallRules | Out-Null
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

if ($dgFwManaged) {
    $dgFwManaged.Add_SelectionChanged({
        try {
            $sel = $dgFwManaged.SelectedItem
            if ($null -ne $sel) { Set-FirewallFieldsFromRule $sel }
        } catch {}
    })
}


if ($btnTraceConntrack) { $btnTraceConntrack.Add_Click({ try { Show-FirewallTraceConntrack } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }
if ($btnTraceTcpdump) { $btnTraceTcpdump.Add_Click({ try { Show-FirewallTraceTcpdump } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }
if ($btnTraceSearch) { $btnTraceSearch.Add_Click({ try { Invoke-FirewallTraceSearch } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }

$btnQosPresetDefault.Add_Click({ try { Set-QosQuickProfile 'DEFAULT'; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosPresetCalls.Add_Click({ try { Set-QosQuickProfile 'CALLS'; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosPresetMeet.Add_Click({ try { Set-QosQuickProfile 'MEET'; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosPresetGames.Add_Click({ try { Set-QosQuickProfile 'GAMES'; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })

$btnQosRead.Add_Click({
    try {
        Refresh-QosStatus
try { Refresh-AppManagedFirewallRules | Out-Null } catch {}
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnQosApply.Add_Click({
    try {
        $policy = $txtQosPolicy.Text.Trim()
        $iface = $txtQosIface.Text.Trim()
        $down = $txtQosDown.Text.Trim()
        $up = $txtQosUp.Text.Trim()
        if (-not $policy -or -not $iface -or -not $down -or -not $up) { throw 'Preencha política, interface, download e upload.' }
        if ($down -notmatch '^\d+([.,]\d+)?$' -or $up -notmatch '^\d+([.,]\d+)?$') { throw 'Download e upload devem ser numéricos.' }
        $downValue = ($down -replace ',','.')
        $upValue = ($up -replace ',','.')
        if (-not (Confirm-UiAction "Aplicar Smart Queue $policy em $iface com ${downValue}mbit / ${upValue}mbit?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control smart-queue $policy wan-interface $iface",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control smart-queue $policy download rate ${downValue}mbit",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set traffic-control smart-queue $policy upload rate ${upValue}mbit"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "QoS_${policy}"
        Set-OutputText -Target $txtQosOut -Content $out -Title 'Resultado do QoS / Smart Queue'
        Write-AppLog "QoS aplicado: $policy / $iface / down ${downValue}mbit / up ${upValue}mbit"
        Refresh-QosStatus
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnQosRemove.Add_Click({
    try {
        $policy = $txtQosPolicy.Text.Trim()
        if (-not $policy) { throw 'Informe a política QoS.' }
        if (-not (Confirm-UiAction "Remover a política Smart Queue $policy?")) { return }
        $out = Invoke-EdgeConfigCommand -Commands @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete traffic-control smart-queue $policy") -Reason "Remove_QoS_${policy}"
        Set-OutputText -Target $txtQosOut -Content $out -Title 'QoS removido'
        Write-AppLog "QoS removido: $policy"
        Refresh-QosStatus
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnQosFriendlyPreview.Add_Click({
    try { Update-QosFriendlyPreview } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})
$btnQosFriendlyRead.Add_Click({
    try {
        Refresh-QosStatus
        if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }
        if ($tabQosSub) { $tabQosSub.SelectedIndex = 0 }
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})
$btnQosFriendlyApply.Add_Click({
    try { Invoke-QosFriendlyApply } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})
$btnQosFriendlyRemove.Add_Click({
    try { Invoke-QosFriendlyRemove } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})
$btnQosDevUseLease.Add_Click({ try { Show-QosOnlineClients } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosDevRead.Add_Click({ try { Refresh-QosDevicePolicies; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosDevApply.Add_Click({ try { Invoke-QosDeviceLimitApply; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
$btnQosDevRemove.Add_Click({ try { Remove-QosDeviceLimit; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } })
if ($btnP2PRead) { $btnP2PRead.Add_Click({ try { Refresh-P2PBlocks; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }
if ($btnP2PBlock) { $btnP2PBlock.Add_Click({ try { Apply-P2PBlockForDevice; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }
if ($btnP2PRemove) { $btnP2PRemove.Add_Click({ try { Remove-P2PBlockForDevice; if ($tabFwSub) { $tabFwSub.SelectedIndex = 3 }; if ($tabQosSub) { $tabQosSub.SelectedIndex = 1 } } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' } }) }
$dgQosDevicePolicies.Add_SelectionChanged({
    if ($dgQosDevicePolicies.SelectedItem) {
        $item = $dgQosDevicePolicies.SelectedItem
        $txtQosDevIp.Text = [string]$item.IP
        $txtQosDevDown.Text = [string]$item.Download
        $txtQosDevUp.Text = [string]$item.Upload
        if ($item.TotalDown) { $txtQosDevTotalDown.Text = [string]$item.TotalDown }
        if ($item.TotalUp) { $txtQosDevTotalUp.Text = [string]$item.TotalUp }
        $txtQosDevNote.Text = [string]$item.Note
    }
})
if ($cmbQosFriendlyGoal) { $cmbQosFriendlyGoal.Add_SelectionChanged({ try { Update-QosFriendlyPreview } catch {} }) }
if ($cmbQosFriendlyLevel) { $cmbQosFriendlyLevel.Add_SelectionChanged({ try { Update-QosFriendlyPreview } catch {} }) }
if ($txtQosFriendlyIface) { $txtQosFriendlyIface.Add_TextChanged({ try { Update-QosFriendlyPreview } catch {} }) }
if ($txtQosFriendlyDownReal) { $txtQosFriendlyDownReal.Add_TextChanged({ try { Update-QosFriendlyPreview } catch {} }) }
if ($txtQosFriendlyUpReal) { $txtQosFriendlyUpReal.Add_TextChanged({ try { Update-QosFriendlyPreview } catch {} }) }

$btnDnsRulesList.Add_Click({
    try {
        Set-OutputText -Target $txtDnsOut -Content (Get-DnsRulesOverview) -Title 'Regras DNS / DoH'
        Write-AppLog 'Leitura de regras DNS / DoH executada.'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDnsHijackOn.Add_Click({
    try {
        $lanInt = $txtDnsLan.Text.Trim()
        $natIP = $txtDnsRouterIp.Text.Trim()
        $ruleId = $txtDnsHijackRule.Text.Trim()
        if (-not $lanInt -or -not $natIP -or -not $ruleId) { throw 'Preencha interface LAN, IP do roteador e regra NAT.' }
        if (-not (Test-IPv4Address $natIP)) { throw 'IP do roteador inválido.' }
        if (-not (Confirm-UiAction "Ativar a interceptação DNS na interface $lanInt?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId type destination",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId description 'Interceptar_DNS_Porta_53'",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId destination port 53",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId inbound-interface $lanInt",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId protocol tcp_udp",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId inside-address address $natIP",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId inside-address port 53"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason "Interceptar_DNS_53"
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Interceptação DNS ativada'
        Write-AppLog "Interceptação DNS ativada na interface $lanInt para o IP $natIP"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDnsHijackOff.Add_Click({
    try {
        $ruleId = $txtDnsHijackRule.Text.Trim()
        if (-not $ruleId) { throw 'Informe a regra NAT que deseja remover.' }
        if (-not (Confirm-UiAction "Remover a interceptação DNS da regra NAT $ruleId?")) { return }
        $out = Invoke-EdgeConfigCommand -Commands @("/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service nat rule $ruleId") -Reason "Remover_Interceptar_DNS_53"
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Interceptação DNS removida'
        Write-AppLog "Interceptação DNS removida da regra NAT $ruleId"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDohOn.Add_Click({
    try {
        $lanInt = $txtDnsLan.Text.Trim()
        $ruleId = $txtDohRule.Text.Trim()
        if (-not $lanInt -or -not $ruleId) { throw 'Preencha a interface LAN e a regra NAT do DoH.' }
        if (-not (Confirm-UiAction "Ativar o bloqueio básico de DoH na interface $lanInt?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 8.8.8.8",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 8.8.4.4",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 1.1.1.1",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 1.0.0.1",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 9.9.9.9",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group DOH_IPS address 149.112.112.112",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId type destination",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId description 'Bloqueio_DoH_App'",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId destination group address-group DOH_IPS",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId destination port 443",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId inbound-interface $lanInt",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId protocol tcp",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service nat rule $ruleId inside-address address 203.0.113.1",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/use-application-dns.net/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/dns.google/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/cloudflare-dns.com/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/mozilla.cloudflare-dns.com/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options address=/dns.quad9.net/0.0.0.0"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason 'Bloqueio_DoH'
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Bloqueio DoH aplicado'
        Write-AppLog "Bloqueio DoH aplicado na interface $lanInt (regra NAT $ruleId)"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDohOff.Add_Click({
    try {
        $ruleId = $txtDohRule.Text.Trim()
        if (-not $ruleId) { throw 'Informe a regra NAT do bloqueio DoH.' }
        if (-not (Confirm-UiAction "Remover o bloqueio básico de DoH da regra NAT $ruleId?")) { return }
        $cmds = @(
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service nat rule $ruleId",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall group address-group DOH_IPS",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/use-application-dns.net/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/dns.google/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/cloudflare-dns.com/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/mozilla.cloudflare-dns.com/0.0.0.0",
            "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding options address=/dns.quad9.net/0.0.0.0"
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason 'Remover_Bloqueio_DoH'
        Set-OutputText -Target $txtDnsOut -Content $out -Title 'Bloqueio DoH removido'
        Write-AppLog "Bloqueio DoH removido da regra NAT $ruleId"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

function Get-DpiOffloadStatusText {
    $cfgLines = Get-EdgeConfigLines -ForceRefresh
    $dpiEnabled = -not ($cfgLines | Where-Object { $_ -eq 'set system traffic-analysis dpi disable' })
    $exportEnabled = -not ($cfgLines | Where-Object { $_ -eq 'set system traffic-analysis export disable' })
    $hwnatEnabled = [bool]($cfgLines | Where-Object { $_ -eq 'set system offload hwnat enable' })
    $ipsecEnabled = [bool]($cfgLines | Where-Object { $_ -eq 'set system offload ipsec enable' })
    $offloadText = ''
    try { $offloadText = Invoke-EdgeRouterCommand -Command 'show ubnt offload' -Silent } catch { $offloadText = $_.Exception.Message }
    return @"
Status DPI / Offload
====================
DPI: $(if($dpiEnabled){'habilitado'}else{'desabilitado'})
Export: $(if($exportEnabled){'habilitado'}else{'desabilitado'})
HWNAT Offload: $(if($hwnatEnabled){'habilitado'}else{'desabilitado'})
IPsec Offload: $(if($ipsecEnabled){'habilitado'}else{'desabilitado'})

O que cada modo faz
===================
Modo análise de tráfego:
- habilita DPI
- habilita export
- melhor para investigar quem está consumindo banda

Modo desempenho:
- desabilita DPI
- desabilita export
- tenta reativar offload HWNAT/IPsec para o dia a dia

Saída show ubnt offload
=======================
$offloadText
"@
}

$btnPing.Add_Click({
    try {
        $targetHost = $txtToolHost.Text.Trim(); if (-not $targetHost) { throw 'Informe um host/IP.' }
        Set-OutputText -Target $txtLog -Content (Invoke-EdgeRouterCommand -Command ("ping -c 4 $targetHost")) -Title "Ping em $targetHost"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnDnsLookup.Add_Click({
    try {
        $targetHost = $txtToolHost.Text.Trim(); if (-not $targetHost) { throw 'Informe um host/domínio.' }
        Set-OutputText -Target $txtLog -Content (Invoke-EdgeRouterCommand -Command ("nslookup $targetHost")) -Title "DNS lookup de $targetHost"
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnBackup.Add_Click({
    try {
        $file = Save-EdgeBackup -Reason 'manual_wpf'
        Show-UiMessage -Title (Get-UiText 'Backup salvo') -Message ((Get-UiText 'Backup salvo em:') + "`r`n$file")
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnOpenLogs.Add_Click({
    Start-Process explorer.exe $script:LogRoot
})
$btnPerfRead.Add_Click({
    try {
        Set-OutputText -Target $txtLog -Content (Get-DpiOffloadStatusText)
        Write-AppLog 'Status DPI/Offload lido.'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnPerfAnalysis.Add_Click({
    try {
        if (-not (Confirm-UiAction 'Ativar DPI/export para investigação de tráfego? Isso pode reduzir desempenho.')) { return }
        $cmds = @(
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete system traffic-analysis dpi disable',
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete system traffic-analysis export disable'
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason 'dpi_analysis_mode'
        Set-OutputText -Target $txtLog -Content ((Get-DpiOffloadStatusText) + "`r`n`r`n" + (Convert-OutputToText $out))
        Write-AppLog 'Modo análise de tráfego ativado.'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})

$btnPerfPerformance.Add_Click({
    try {
        if (-not (Confirm-UiAction 'Ativar modo desempenho? Isso desliga DPI/export e tenta religar offload.')) { return }
        $cmds = @(
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system traffic-analysis dpi disable',
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system traffic-analysis export disable',
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system offload hwnat enable',
            '/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system offload ipsec enable'
        )
        $out = Invoke-EdgeConfigCommand -Commands $cmds -Reason 'dpi_performance_mode'
        Set-OutputText -Target $txtLog -Content ((Get-DpiOffloadStatusText) + "`r`n`r`n" + (Convert-OutputToText $out))
        Write-AppLog 'Modo desempenho ativado.'
    } catch { Show-UiMessage $_.Exception.Message 'Erro' 'Error' }
})


Set-WpfToolTipSafe -Control $txtIp -Text 'IP do EdgeRouter'
Set-WpfToolTipSafe -Control $txtUser -Text 'Usuário SSH'
Set-WpfToolTipSafe -Control $txtPass -Text 'Senha SSH'
Set-WpfToolTipSafe -Control $btnDhcpLer -Text 'Lê os leases DHCP dinâmicos.'
Set-WpfToolTipSafe -Control $btnDhcpLerReservas -Text 'Lê as reservas DHCP existentes na configuração.'
Set-WpfToolTipSafe -Control $btnLbPreset5050 -Text 'Preenche 50/50. Use Aplicar Pesos para colocar em balanceamento.'
Set-WpfToolTipSafe -Control $btnLbFailoverWan1 -Text 'Deixa a WAN1 como principal e a WAN2 como backup.'
Set-WpfToolTipSafe -Control $btnLbFailoverWan2 -Text 'Deixa a WAN2 como principal e a WAN1 como backup.'
Set-WpfToolTipSafe -Control $cmbPbrMode -Text 'Escolha entre saída fixa ou preferência por WAN1/WAN2 com fallback opcional.'
Set-WpfToolTipSafe -Control $btnPbrApply -Text 'Aplica a política escolhida para o IP informado.'
Set-WpfToolTipSafe -Control $btnPbrReadPolicies -Text 'Carrega as políticas de PBR da chain informada para conferência e remoção.'
Set-WpfToolTipSafe -Control $btnPbrRemovePolicy -Text 'Remove a política de PBR selecionada da chain e limpa a tabela se ela não estiver mais em uso.'
Set-WpfToolTipSafe -Control $btnNatListar -Text 'Lista o port-forward atual do roteador.'
Set-WpfToolTipSafe -Control $btnNatCriar -Text 'Cria uma regra de port-forward usando os campos preenchidos.'
Set-WpfToolTipSafe -Control $btnFwListar -Text 'Lista as regras da chain informada e abre a subaba de saída.'
Set-WpfToolTipSafe -Control $btnFwCriar -Text 'Cria uma nova regra simples de firewall na chain informada.'
Set-WpfToolTipSafe -Control $txtFwDest -Text 'Opcional: IP ou rede de destino para a regra.'
Set-WpfToolTipSafe -Control $cmbFwProto -Text 'Escolha o protocolo da regra. Em presets, o app preenche sozinho.'
Set-WpfToolTipSafe -Control $txtFwPort -Text 'Porta de destino para bloqueio ou permissão específica.'
Set-WpfToolTipSafe -Control $btnFwBlockInternet -Text 'Cria uma regra drop para cortar a internet deste IP.'
Set-WpfToolTipSafe -Control $btnFwAllowWebDns -Text 'Permite DNS e HTTP/HTTPS para o IP e bloqueia o restante.'
Set-WpfToolTipSafe -Control $btnFwBlockPort -Text 'Bloqueia uma porta/protocolo específica para o IP informado.'
Set-WpfToolTipSafe -Control $btnFwReadManaged -Text 'Lista as regras de firewall criadas pelo app.'
Set-WpfToolTipSafe -Control $btnFwRemoveManaged -Text 'Remove a regra selecionada na grade abaixo.'
Set-WpfToolTipSafe -Control $dgFwManaged -Text 'Regras de firewall criadas pelo app. Clique em uma linha para carregar nos campos.'
Set-WpfToolTipSafe -Control $txtFwName -Text 'Ruleset/chains: LAN_IN para clientes internos. WAN_IN/WAN_LOCAL para tráfego vindo da Internet.'
Set-WpfToolTipSafe -Control $txtFwSource -Text 'IP interno de origem. É aqui que você informa a máquina da rede local que quer controlar.'
Set-WpfToolTipSafe -Control $txtFwDest -Text 'IP ou rede de destino opcional. Use quando quiser bloquear só um destino específico.'
Set-WpfToolTipSafe -Control $btnFwBlockInternet -Text 'Cria uma regra drop para o IP interno informado na origem.'
Set-WpfToolTipSafe -Control $btnFwAllowWebDns -Text 'Permite DNS, HTTP e HTTPS para o IP de origem e bloqueia o restante.'
Set-WpfToolTipSafe -Control $btnFwBlockPort -Text 'Bloqueia uma porta/protocolo específica para o IP de origem.'
Set-WpfToolTipSafe -Control $btnTraceConntrack -Text 'Mostra as conexões ativas do IP alvo usando conntrack.'
Set-WpfToolTipSafe -Control $btnTraceTcpdump -Text 'Faz uma captura rápida por alguns segundos para o IP alvo.'
Set-WpfToolTipSafe -Control $btnPerfRead -Text 'Lê o estado atual do DPI, export e offload.'
Set-WpfToolTipSafe -Control $btnPerfAnalysis -Text 'Liga DPI e export para investigar consumo por aplicação. Pode pesar no desempenho.'
Set-WpfToolTipSafe -Control $btnPerfPerformance -Text 'Desliga DPI/export e tenta religar offload HWNAT/IPsec para melhorar o desempenho do dia a dia.'
Set-WpfToolTipSafe -Control $btnTraceSearch -Text 'Abre o navegador pesquisando o destino/porta informados no campo ao lado.'
Set-WpfToolTipSafe -Control $btnQosRead -Text 'Lê a configuração QoS/Smart Queue e o status atual das filas.'
Set-WpfToolTipSafe -Control $btnQosPresetDefault -Text 'Carrega um perfil neutro para Smart Queue.'
Set-WpfToolTipSafe -Control $btnQosPresetCalls -Text 'Prepara um perfil rápido para chamadas e WhatsApp, mantendo a lógica simples do Smart Queue.'
Set-WpfToolTipSafe -Control $btnQosPresetMeet -Text 'Prepara um perfil rápido para Teams, Meet e Zoom.'
Set-WpfToolTipSafe -Control $btnQosPresetGames -Text 'Prepara um perfil rápido pensando em baixa latência para jogos.'
Set-WpfToolTipSafe -Control $btnQosApply -Text 'Aplica um Smart Queue básico na interface WAN escolhida.'
Set-WpfToolTipSafe -Control $btnQosRemove -Text 'Remove a política Smart Queue informada.'
Set-WpfToolTipSafe -Control $btnQosFriendlyPreview -Text 'Calcula valores mais humanos para o QoS a partir da velocidade real do seu link.'
Set-WpfToolTipSafe -Control $btnQosFriendlyRead -Text 'Lê o QoS atual e preenche a visão facilitada.'
Set-WpfToolTipSafe -Control $btnQosFriendlyApply -Text 'Aplica o QoS usando a visão facilitada.'
Set-WpfToolTipSafe -Control $btnQosFriendlyRemove -Text 'Remove o QoS a partir da visão facilitada.'
Set-WpfToolTipSafe -Control $btnQosDevUseLease -Text 'Lista clientes online agora usando ARP/neigh e mostra IP, MAC e nome no diagnóstico do QoS.'
Set-WpfToolTipSafe -Control $btnQosDevRead -Text 'Lê os limites por dispositivo criados pelo app usando Advanced Queue.'
Set-WpfToolTipSafe -Control $btnQosDevApply -Text 'Aplica um limite por IP usando Advanced Queue global para download e upload.'
Set-WpfToolTipSafe -Control $btnQosDevRemove -Text 'Remove o limite por dispositivo selecionado.'
Set-WpfToolTipSafe -Control $btnP2PRead -Text 'Lê os bloqueios P2P/Torrent criados pelo app para IPs específicos.'
Set-WpfToolTipSafe -Control $btnP2PBlock -Text 'Cria um bloqueio por DPI categoria P2P para o IP informado, mantendo o resto da navegação liberado.'
Set-WpfToolTipSafe -Control $btnP2PRemove -Text 'Remove o bloqueio P2P/Torrent criado pelo app para o IP informado.'
Set-WpfToolTipSafe -Control $btnDnsRulesList -Text 'Lista regras relacionadas a DNS, interceptação e DoH.'
Set-WpfToolTipSafe -Control $btnDnsHijackOn -Text 'Cria NAT para interceptar DNS porta 53 na LAN.'
Set-WpfToolTipSafe -Control $btnDnsHijackOff -Text 'Remove a regra NAT usada na interceptação DNS.'
Set-WpfToolTipSafe -Control $btnDohOn -Text 'Ativa um bloqueio básico de DoH para endpoints comuns.'
Set-WpfToolTipSafe -Control $btnDohOff -Text 'Remove o bloqueio básico de DoH configurado pelo app.'

Update-UiLanguage 'pt'
Write-AppLog 'Protótipo WPF v16 fix5 carregado. Interface agora pode alternar entre Português e Inglês.'
$window.ShowDialog() | Out-Null
