# TechNova - Infraestrutura Distribuída

## Visão geral

O projeto TechNova implementa uma infraestrutura automatizada com Ansible para suportar aplicação, monitorização e operações. A solução está distribuída por múltiplas VMs com papéis bem definidos, permitindo provisionamento consistente, observabilidade centralizada e resposta automatizada a eventos operacionais.

## Objetivo

Este repositório contém a automação completa da TechNova para provisionamento, configuração, recuperação e monitorização da infraestrutura.

O ambiente é composto por 4 VMs Ubuntu Server na rede `10.0.0.0/24`:

- VM1: infraestrutura base.
- VM2: aplicação.
- VM3: automação.
- VM4: monitorização.

## Arquitetura

| VM | Hostname | IP | Função |
|----|----------|----|--------|
| VM1 | `srv-infra` | `10.0.0.10` | DNS interno, NTP, NFS, segurança e serviços base |
| VM2 | `srv-apps` | `10.0.0.20` | Aplicação Node.js, MySQL e Nginx |
| VM3 | `srv-auto` | `10.0.0.30` | Automação com Ansible e sincronização de utilizadores |
| VM4 | `srv-monit` | `10.0.0.40` | Monitorização com Prometheus, Grafana, Alertmanager e Loki |

## Execução da automação

A VM1 é o ponto de entrada do ambiente. Primeiro acede à VM1 e, depois de ela estar ativa, executa os scripts correspondentes em cada VM.

### Ordem de execução

1. Entrar na VM1.
2. Confirmar que a VM1 está ativa.
3. Executar o script da VM2.
4. Executar o script da VM3.
5. Executar o script da VM4.

### Acesso com perfil do Entra ID

```bash
# VM1
az ssh vm --resource-group RESOURCEMOVERRG-WESTUS2-NORTHCENTRALUS-EUS2 --name SRV-INFRA-VM1

# VM2
sh vm2.sh

# VM3
sh vm3.sh

# VM4
sh vm4.sh
```

### Acesso como `deploy`

```bash
# VM1
ssh -i SRV-INFRA-VM1_key.pem deploy@srv-infra-vm1.northcentralus.cloudapp.azure.com

# VM2
sh vm2.sh

# VM3
sh vm3.sh

# VM4
sh vm4.sh
```
## Serviços

### VM1 - Infraestrutura

- DNS interno com `Bind9`.
- Sincronização de tempo com `Chrony`.
- Partilha de ficheiros com `NFS`.
- Hardening de SSH.
- Proteção com `Fail2ban`.
- Métricas com `Node Exporter`.
- Recolha de logs com `Grafana Alloy`.

### VM2 - Aplicação

- `http://10.0.0.20` — TechNova Asset Manager.
- `http://10.0.0.20/api/health` — Health check.
- `http://10.0.0.20/api/assets` — Lista de assets em JSON.
- `http://10.0.0.20/metrics` — Métricas Prometheus, apenas para rede interna.

### VM3 - Automação

- Execução central da automação com Ansible.
- Sincronização de utilizadores e passwords.
- Watcher para deteção de alterações.
- Suporte à orquestração dos scripts das restantes VMs.

### VM4 - Monitorização

- `http://10.0.0.40:9090` — Prometheus.
- `http://10.0.0.40:3000` — Grafana (`admin` / ver `.env`).
- `http://10.0.0.40:9093` — Alertmanager.
- `http://10.0.0.40:3100` — Loki.

## Tree

```text
github-project/
├── vm1
│   ├── dns
│   │   ├── db.technova.local
│   │   ├── named.conf.local
│   │   └── named.conf.options
│   ├── nfs
│   │   └── exports
│   ├── ntp
│   │   └── chrony.conf
│   ├── root
│   │   ├── ansible.sh
│   │   ├── bind9exporterfix.sh
│   │   ├── nodeexporterfix.sh
│   │   ├── vm2.sh
│   │   ├── vm3.sh
│   │   └── vm4.sh
│   └── security
│       ├── 99-technova-hardening.conf
│       └── jail.local
├── vm2
│   ├── app
│   │   ├── Dockerfile
│   │   └── package.json
│   └── nginx
│       ├── default.conf
│       ├── default.conf.bkp
│       └── default.conf.old
├── vm3
│   ├── files
│   │   └── backup-technova.sh
│   ├── inventory
│   │   └── inventory.ini
│   ├── logs
│   │   ├── ansible.log
│   │   └── sync-users.log
│   ├── playbooks
│   │   ├── deploy-github.yml
│   │   ├── deploy-https.yml
│   │   ├── deploy-shadow-watcher.yml
│   │   ├── deploy-site.yml
│   │   ├── deploy-ssh.yml
│   │   ├── fix-vm2.yml
│   │   ├── manage-vm2.yml
│   │   ├── manage-vm2.yml.old
│   │   ├── manage-vm4.yml
│   │   ├── manage_users.yml
│   │   ├── setup-grafana-cadvisor.yml
│   │   ├── setup-nfs.yml
│   │   ├── setup-shadow-watcher.yml
│   │   └── site.yml
│   ├── scripts
│   │   ├── demo-nfs.sh
│   │   ├── distribute-keys.sh
│   │   ├── run-site.sh
│   │   ├── sync-users.sh
│   │   ├── sync-users.yml
│   │   └── test-connectivity.sh
│   └── vars
│       └── users.yml
└── vm4
    ├── alertmanager
    │   └── alertmanager.yml
    ├── backups
    ├── grafana
    ├── loki
    │   └── loki-config.yml
    ├── prometheus
    │   ├── alerts.yml
    │   └── prometheus.yml
    └── webhook
        ├── Dockerfile
        └── server.py
```
**Stack Docker:**

| Container | Imagem | Função |
|-----------|--------|--------|
| technova-prometheus | prom/prometheus:v2.54.1 | Recolha de métricas |
| technova-alertmanager | prom/alertmanager:v0.27.0 | Gestão de alertas |
| technova-loki | grafana/loki:3.1.1 | Agregação de logs |
| technova-grafana | grafana/grafana:11.1.5 | Dashboards |
| technova-webhook-listener | python:3.12-alpine | Receptor de alertas (porta 5001) |

**Credenciais Grafana:** ver `.env` em `/opt/technova-monitoring/`

**Prometheus — targets de scraping:**

| Job | Alvo |
|-----|------|
| node-vm1-infra | 10.0.0.10:9100 |
| node-vm2-apps | 10.0.0.20:9100 |
| node-vm3-auto | 10.0.0.30:9100 |
| node-vm4-monit | localhost:9100 |
| app-api-health | 10.0.0.20:80/metrics |
| cadvisor-vm2 | 10.0.0.20:8080 |

### Alertas Configurados

| Alerta | Condição | Severidade |
|--------|----------|------------|
| InstanceDown | `up == 0` por 1m | critical |
| VM2AppDown | app-api-health down por 1m | warning |
| HighCPUUsage | CPU > 85% por 2m | critical |
| HighMemoryUsage | RAM > 90% por 2m | warning |
| DiskSpaceLow | Disco < 15% livre por 5m | warning |

Alertas são enviados para o webhook receiver em `http://webhook-listener:5001/` e registados em `/tmp/technova-alerts.log`.

## Fluxo de Logs e Métricas

```
VM1, VM2, VM3, VM4
      |
   Alloy (logs)  ──►  Loki (VM4:3100)  ──►  Grafana
      |
Node Exporter    ──►  Prometheus (VM4:9090)  ──►  Grafana
                            |
                       Alertmanager  ──►  Webhook receiver
```

## Observações

- O endpoint `/metrics` da VM2 é interno e não deve ser exposto publicamente.
- O acesso ao Grafana depende das credenciais definidas no ficheiro `.env`.
- A VM1 funciona como base da infraestrutura e ponto de partida da execução.
- A VM3 concentra a automação e sincronização operacional.