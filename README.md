# EdgeRouterSuiteFriendly
EdgeRouter Suite Friendly (WPF) 🚀
EdgeRouter Suite Friendly é uma ferramenta de gestão gráfica baseada em Windows (PowerShell WPF) projetada para simplificar a configuração tática e o monitoramento de routers Ubiquiti EdgeMAX (como o EdgeRouter X).

Este projeto nasceu da necessidade de automatizar tarefas complexas de rede que a interface web padrão não facilita, como o roteamento baseado em políticas (PBR), perfis de QoS inteligentes e segurança de DNS.

🌟 Funcionalidades Principais / Key Features
🇧🇷 Português
Gestão de PBR (Policy-Based Routing): Automatiza a criação de tabelas de rotas e regras de firewall para direcionar dispositivos específicos para diferentes links WAN com facilidade.

Presets de QoS (Smart Queue): Perfis prontos para Jogos (baixa latência), Reuniões (Teams/Zoom) e Chamadas (WhatsApp/VoIP).

Segurança DNS: Ativação de interceptação de DNS (DNS Hijacking) para forçar o uso de servidores específicos e bloqueio de DoH (DNS-over-HTTPS).

Backups Automáticos: Extração automática do config.boot localmente antes de qualquer alteração crítica.

Interface Amigável: Painel WPF intuitivo que elimina a necessidade de memorizar comandos complexos da CLI Vyatta.

🇺🇸 English
PBR Management: Simplifies Policy-Based Routing by automating routing tables and firewall rules for multi-WAN setups.

QoS Presets: Quick-apply profiles for Gaming (Low Latency), Meetings (Teams/Zoom), and VoIP/Calls.

DNS Security: One-click DNS Hijacking (intercepting port 53) and DoH (DNS-over-HTTPS) blocking.

Automatic Backups: Local extraction of config.boot before applying any major changes.

WPF Interface: A native Windows UI that replaces complex CLI commands with intuitive buttons.

🛠️ Pré-requisitos / Requirements
OS: Windows 10/11

PowerShell: 5.1 ou superior.

Dependências: Módulo Posh-SSH.

O script verificará e solicitará a instalação automaticamente se necessário.

Hardware: Ubiquiti EdgeRouter (Testado no ER-X v1.10.11).

🚀 Como Usar / How to Use
Faça o download do ficheiro EdgeRouterSuiteFriendly_WPF.ps1.

Execute o PowerShell como Administrador.

Execute o script: .\EdgeRouterSuiteFriendly_WPF.ps1.

Introduza o IP do router, utilizador e senha para ligar via SSH.

Utilize as abas para navegar entre as configurações de Firewall, NAT, QoS e PBR.

🤖 Desenvolvimento e IA / AI Assisted Project
Este projeto foi desenvolvido com o auxílio de Inteligência Artificial para traduzir necessidades complexas de administração de redes em código PowerShell funcional. O objetivo é democratizar o acesso às configurações avançadas do EdgeOS para utilizadores que preferem uma interface visual em vez da linha de comandos pura.

⚠️ Aviso Legal / Disclaimer
Uso por sua conta e risco. Este software altera configurações críticas de firewall e roteamento. Recomenda-se testar as alterações num ambiente controlado. O autor não se responsabiliza por perdas de conectividade ou danos ao hardware.

📜 Licença / License
Distribuído sob a licença MIT. Veja o ficheiro LICENSE para mais detalhes.
