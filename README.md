# TechNova — Infraestrutura Distribuída

![Ubuntu](https://img.shields.io/badge/Ubuntu_Server-24.04-E95420?style=flat&logo=ubuntu&logoColor=white)
![Azure](https://img.shields.io/badge/Microsoft_Azure-IaaS-0089D6?style=flat&logo=microsoftazure&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?style=flat&logo=ansible&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C?style=flat&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat&logo=grafana&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-Reverse_Proxy-009639?style=flat&logo=nginx&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?style=flat&logo=nodedotjs&logoColor=white)

> Infraestrutura distribuída empresarial simulada em Azure IaaS, aplicando boas práticas de Administração de Sistemas, Segurança, Automação e Observabilidade.

---

## Índice

- [Visão Geral](#visão-geral)
- [Princípios de Design](#princípios-de-design)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Execução](#execução)
- [Serviços por VM](#serviços-por-vm)
- [Stack Docker](#stack-docker)
- [Monitorização e Alertas](#monitorização-e-alertas)
- [Fluxo de Logs e Métricas](#fluxo-de-logs-e-métricas)
- [Segurança](#segurança)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Troubleshooting](#troubleshooting)
- [Evolução Futura](#evolução-futura)
- [Autores](#autores)

---

## Visão Geral

A **TechNova** é uma infraestrutura distribuída desenvolvida para simular um ambiente empresarial moderno em **Microsoft Azure (IaaS — North Central US)**, segmentada em **4 máquinas virtuais Ubuntu Server**, cada uma com função dedicada e comunicação via rede privada interna.

---

## Princípios de Design

| Princípio | Descrição |
|-----------|-----------|
| **Defense in Depth** | Múltiplas camadas de proteção (NSG, UFW, Fail2ban, SSH hardening) |
| **Least Privilege** | Permissões mínimas necessárias por utilizador e serviço |
| **Segregation of Duties** | Separação clara de responsabilidades entre VMs |

---

## Arquitetura

| VM | Hostname | IP | Função |
|----|----------|----|--------|
| VM1 | `srv-infra` | `10.0.0.10` | DNS interno, NTP, NFS, segurança e serviços base |
| VM2 | `srv-apps` | `10.0.0.20` | Aplicação Node.js, MySQL e Nginx |
| VM3 | `srv-auto` | `10.0.0.30` | Automação com Ansible e sincronização de utilizadores |
| VM4 | `srv-monit` | `10.0.0.40` | Monitorização com Prometheus, Grafana, Alertmanager e Loki |

```text
=========================================================
TechNova - Mapa de Rede Completo (Enterprise View)
=========================================================

PROVIDER CLOUD
Microsoft Azure

REGIÃO
North Central US

AMBIENTE
Infrastructure as a Service (IaaS)

=========================================================
CAMADA EXTERNA
=========================================================

Internet
   │
   ▼
Azure Public IP
   │
   ▼
Network Security Group (NSG)
   │
   ├── Allow 80/tcp
   ├── Allow 443/tcp
   ├── Allow Bastion Access
   └── Deny unnecessary inbound traffic
   │
   ▼

=========================================================
CAMADA DE IDENTIDADE
=========================================================

Microsoft Entra ID
   │
   ├── RBAC
   ├── Virtual Machine Administrator Login
   ├── Virtual Machine User Login
   └── Identity Governance
   │
   ▼

Azure Bastion
   │
   ▼
VM1 only

=========================================================
REDE PRIVADA INTERNA
=========================================================

Virtual Network: 10.0.0.0/24
DNS Domain:      technova.local

Internal Hostnames:
  10.0.0.10  srv-infra.technova.local
  10.0.0.20  srv-apps.technova.local
  10.0.0.30  srv-auto.technova.local
  10.0.0.40  srv-monit.technova.local

=========================================================
SUBNETS LÓGICAS
=========================================================

[Subnet Infra]       10.0.0.0/28   → VM1 - srv-infra  (10.0.0.10)
[Subnet Apps]        10.0.0.16/28  → VM2 - srv-apps   (10.0.0.20)
[Subnet Automation]  10.0.0.32/28  → VM3 - srv-auto   (10.0.0.30)
[Subnet Monitoring]  10.0.0.48/28  → VM4 - srv-monit  (10.0.0.40)

=========================================================
NETWORK FLOWS
=========================================================

User Traffic:
Internet → NSG → VM2 → Nginx → App → MySQL

Administrative Flow:
Admin → Entra ID → Bastion → VM1 → SSH Internal → VM2 / VM3 / VM4

Automation Flow:
VM3 → SSH → VM1 / VM2 / VM4

Logs Flow:
VM1 Alloy ─┐
VM2 Alloy ─┼──► Loki VM4
VM3 Alloy ─┘

Metrics Flow:
VM1 Node Exporter ─┐
VM2 Node Exporter  ├──► Prometheus VM4
VM3 Node Exporter  ┤
VM4 Node Exporter  ┘
VM2 cAdvisor ──────► Prometheus

Alerts Flow:
Prometheus → Alertmanager → Webhook → Operator
```

---

## Pré-requisitos

Antes de iniciar, certifica-te de que tens:

- Conta **Microsoft Azure** com permissões para criar VMs e recursos de rede
- **Azure CLI** instalada e autenticada (`az login`)
- Acesso ao **Microsoft Entra ID** com roles: `Virtual Machine Administrator Login` ou `Virtual Machine User Login`
- Chave SSH gerada (`.pem`) para acesso como utilizador `deploy`
- As 4 VMs aprovisionadas na mesma VNet (`10.0.0.0/24`) com os IPs estáticos definidos
- **Bastion** configurado no Azure para acesso à VM1

> ⚠️ A VM1 é o ponto de entrada obrigatório. Todos os acessos administrativos passam por ela.

---

## Execução

### Ordem de execução

A VM1 deve estar ativa antes de executar os scripts das restantes VMs.

```
1. Entrar na VM1
2. Confirmar que a VM1 está ativa
3. Executar o script da VM2
4. Executar o script da VM3
5. Executar o script da VM4
```

### Acesso com perfil do Entra ID

```bash
# VM1
az ssh vm --resource-group RESOURCEMOVERRG-WESTUS2-NORTHCENTRALUS-EUS2 --name SRV-INFRA-VM1

# A partir da VM1, executar:
sh vm2.sh
sh vm3.sh
sh vm4.sh
```

### Acesso como `deploy`

```bash
# VM1
ssh -i SRV-INFRA-VM1_key.pem deploy@srv-infra-vm1.northcentralus.cloudapp.azure.com

# A partir da VM1, executar:
sh vm2.sh
sh vm3.sh
sh vm4.sh
```

---

## Serviços por VM

### VM1 — Infraestrutura (`srv-infra` · `10.0.0.10`)

| Serviço | Descrição |
|---------|-----------|
| **Bind9** | DNS interno (`technova.local`) — portas 53/tcp e 53/udp |
| **Chrony** | Sincronização de tempo via NTP — porta 123/udp |
| **NFS** | Partilha de ficheiros — portas 111 e 2049 (tcp/udp) |
| **SSH Hardening** | Acesso seguro restrito |
| **Fail2ban** | Proteção contra ataques de força bruta |
| **Node Exporter** | Métricas do sistema — porta 9100/tcp |
| **Grafana Alloy** | Recolha e envio de logs para Loki |

---

### VM2 — Aplicação (`srv-apps` · `10.0.0.20`)

| Endpoint | Descrição |
|----------|-----------|
| `http://10.0.0.20` | TechNova Asset Manager |
| `http://10.0.0.20/api/health` | Health check da aplicação |
| `http://10.0.0.20/api/assets` | API JSON |
| `http://10.0.0.20/metrics` | Métricas Prometheus *(interno)* |
| `http://10.0.0.20:8080` | cAdvisor — monitorização de containers |
| `http://10.0.0.20:8080/metrics` | Métricas cAdvisor |

**Stack:** Nginx (reverse proxy) · Node.js (backend) · MySQL (base de dados) · Docker Compose

---

### VM3 — Automação (`srv-auto` · `10.0.0.30`)

| Componente | Descrição |
|------------|-----------|
| **Ansible** | Execução central de playbooks de configuração |
| **Inventário** | Gestão das VMs do ambiente |
| **sync-users** | Sincronização de utilizadores e passwords entre VMs |
| **inotify / Shadow Watcher** | Deteção de alterações em ficheiros do sistema |
| **SSH Client** | Orquestração remota para VM1, VM2 e VM4 |

---

### VM4 — Monitorização (`srv-monit` · `10.0.0.40`)

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Prometheus** | `http://10.0.0.40:9090` | Recolha e armazenamento de métricas |
| **Grafana** | `http://10.0.0.40:3000` | Dashboards e visualização |
| **Alertmanager** | `http://10.0.0.40:9093` | Gestão e envio de alertas |
| **Loki** | `http://10.0.0.40:3100` | Agregação e indexação de logs |
| **Webhook Receiver** | `http://10.0.0.40:5001` | Receção de notificações de alertas |

> ⚠️ Estes endpoints são acessíveis apenas dentro da rede privada `10.0.0.0/24`.

---

## Stack Docker

### VM2 — Aplicação

| Container | Imagem | Função |
|-----------|--------|--------|
| `technova-nginx` | `nginx` | Reverse proxy |
| `technova-app` | custom (Node.js) | Backend da aplicação |
| `technova-mysql` | `mysql` | Base de dados |
| `technova-cadvisor` | `gcr.io/cadvisor/cadvisor` | Métricas de containers |

### VM4 — Observabilidade

| Container | Imagem | Função |
|-----------|--------|--------|
| `technova-prometheus` | `prom/prometheus:v2.54.1` | Recolha de métricas |
| `technova-alertmanager` | `prom/alertmanager:v0.27.0` | Gestão de alertas |
| `technova-loki` | `grafana/loki:3.1.1` | Agregação de logs |
| `technova-grafana` | `grafana/grafana:11.1.5` | Dashboards |
| `technova-webhook-listener` | `python:3.12-alpine` | Receptor de alertas (porta 5001) |

---

## Monitorização e Alertas

### Targets de Scraping (Prometheus)

| Job | Alvo |
|-----|------|
| `node-vm1-infra` | `10.0.0.10:9100` |
| `node-vm2-apps` | `10.0.0.20:9100` |
| `node-vm3-auto` | `10.0.0.30:9100` |
| `node-vm4-monit` | `localhost:9100` |
| `app-api-health` | `10.0.0.20:80/metrics` |
| `cadvisor-vm2` | `10.0.0.20:8080` |

### Alertas Configurados

| Alerta | Condição | Severidade |
|--------|----------|------------|
| `InstanceDown` | `up == 0` por 1m | 🔴 critical |
| `VM2AppDown` | app-api-health down por 1m | 🟡 warning |
| `HighCPUUsage` | CPU > 85% por 2m | 🔴 critical |
| `HighMemoryUsage` | RAM > 90% por 2m | 🟡 warning |
| `DiskSpaceLow` | Disco < 15% livre por 5m | 🟡 warning |

Alertas são enviados para o webhook receiver em `http://webhook-listener:5001/` e registados em `/tmp/technova-alerts.log`.

---

## Fluxo de Logs e Métricas

```text
VM1, VM2, VM3, VM4
      │
      ├── Alloy (logs)      ──►  Loki (VM4:3100)      ──► Grafana
      │
      ├── Node Exporter     ──►  Prometheus (VM4:9090) ──► Grafana
      │                                  │
      └── cAdvisor (VM2)   ─────────────►│
                                         │
                                   Alertmanager ─► Webhook receiver
```

---

## Segurança

| Camada | Controlos |
|--------|-----------|
| **Cloud (Azure)** | NSG, Azure Bastion, Microsoft Entra ID, RBAC |
| **Host** | UFW, Fail2ban, SSH Hardening, acesso não-root, sudo restrito |
| **Operacional** | Logs centralizados, alertas, métricas, auditabilidade |

**Boas práticas:**
- Acesso externo exclusivamente via **Azure Bastion** → VM1
- Credenciais do Grafana definidas via ficheiro `.env` — recomenda-se rotação periódica
- Portas críticas restritas via NSG (Azure) e UFW (local em cada VM)
- Resolução DNS interna via `technova.local` — sem exposição de IPs diretos
- Sincronização temporal entre VMs garantida pelo Chrony para consistência de logs e métricas

---

## Estrutura do Repositório

```text
github-project/
├── demo/
│   ├── vm1/
│   │   ├── bind9/
│   │   │   ├── Dockerfile
│   │   │   ├── named.conf.local
│   │   │   ├── named.conf.options
│   │   │   └── zones/
│   │   │       ├── technova.local.db
│   │   │       └── 10.0.0.in-addr.arpa.db
│   │   ├── docker-compose.yml
│   │   ├── start.sh
│   │   ├── stop.sh
│   │   └── test.sh
│   ├── vm2/
│   │   ├── docker-compose.yml
│   │   ├── nginx.local.conf
│   │   ├── prometheus.local.yml
│   │   ├── start.sh
│   │   ├── stop.sh
│   │   └── test.sh
│   └── security/
│       └── test.sh
├── vm1/
│   ├── dns/
│   │   ├── db.technova.local
│   │   ├── named.conf.local
│   │   └── named.conf.options
│   ├── nfs/
│   │   └── exports
│   ├── ntp/
│   │   └── chrony.conf
│   ├── root/
│   │   ├── ansible.sh
│   │   ├── bind9exporterfix.sh
│   │   ├── nodeexporterfix.sh
│   │   ├── vm2.sh
│   │   ├── vm3.sh
│   │   └── vm4.sh
│   └── security/
│       ├── 99-technova-hardening.conf
│       └── jail.local
├── vm2/
│   ├── app/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── nginx/
│       └── default.conf
├── vm3/
│   ├── files/
│   │   └── backup-technova.sh
│   ├── inventory/
│   │   └── inventory.ini
│   ├── logs/
│   │   ├── ansible.log
│   │   └── sync-users.log
│   ├── playbooks/
│   │   ├── deploy-github.yml
│   │   ├── deploy-https.yml
│   │   ├── deploy-shadow-watcher.yml
│   │   ├── deploy-site.yml
│   │   ├── deploy-ssh.yml
│   │   ├── manage-vm2.yml
│   │   ├── manage-vm4.yml
│   │   ├── manage_users.yml
│   │   ├── setup-grafana-cadvisor.yml
│   │   ├── setup-nfs.yml
│   │   └── site.yml
│   ├── scripts/
│   │   ├── demo-nfs.sh
│   │   ├── distribute-keys.sh
│   │   ├── run-site.sh
│   │   ├── sync-users.sh
│   │   └── test-connectivity.sh
│   └── vars/
│       └── users.yml
└── vm4/
    ├── alertmanager/
    │   └── alertmanager.yml
    ├── grafana/
    ├── loki/
    │   └── loki-config.yml
    ├── prometheus/
    │   ├── alerts.yml
    │   └── prometheus.yml
    └── webhook/
        ├── Dockerfile
        └── server.py
```
---

## Evolução Futura

| Componente | Estado |
|------------|--------|
| Load Balancer (Azure) | Planeado |
| Auto Scaling | Planeado |
| CI/CD Pipeline | Planeado |
| HA Database (MySQL Cluster) | Planeado |
| Kubernetes (AKS) | Planeado |
| DR Site (região secundária) | Planeado |

> Estado atual: **Small Enterprise Ready**

---

## Autores

Projeto desenvolvido no âmbito do programa **Upskill — Administração de Sistemas Linux** 2025/2026.
Carolini Vidal, Janaina Pascoal, Fabrício Lopes.
---

*Infraestrutura provisionada em Microsoft Azure · Domínio interno: `technova.local`*
