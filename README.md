# TechNova - Infraestrutura Distribuída

Projeto de infraestrutura para 4 VMs Ubuntu Server na rede `10.0.0.0/24`.

## Arquitectura

| VM | Hostname | IP | Função |
|----|----------|----|--------|
| VM1 | srv-infra | 10.0.0.10 | DNS (Bind9), NTP (Chrony), NFS |
| VM2 | srv-apps | 10.0.0.20 | App Node.js + MySQL + Nginx |
| VM3 | srv-auto | 10.0.0.30 | Automação (Ansible) |
| VM4 | srv-monit | 10.0.0.40 | Monitorização (Prometheus, Grafana, Loki) |

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
    
## Deployment

Executar cada script na VM correspondente como root:

```bash
# VM1
sudo bash vm1-infra/bootstrap.sh

# VM2 (depois de VM1 estar activa)
sudo bash vm2-apps/bootstrap.sh

# VM3 (depois de VM1 estar activa)
sudo bash vm3-auto/bootstrap.sh

# VM4 (depois de VM1 estar activa)
sudo bash vm4-monit/bootstrap.sh
```

## Serviços

### VM2 - Aplicação
- `http://10.0.0.20` — TechNova Asset Manager
- `http://10.0.0.20/api/health` — Health check
- `http://10.0.0.20/api/assets` — Lista de assets (JSON)
- `http://10.0.0.20/metrics` — Métricas Prometheus (rede interna)

### VM4 - Monitorização
- `http://10.0.0.40:9090` — Prometheus
- `http://10.0.0.40:3000` — Grafana (admin / ver `.env`)
- `http://10.0.0.40:9093` — Alertmanager
- `http://10.0.0.40:3100` — Loki

## Alertas Configurados

| Alerta | Condição | Severidade |
|--------|----------|------------|
| InstanceDown | `up == 0` por 1m | critical |
| VM2AppDown | app-api-health down por 1m | warning |
| HighCPUUsage | CPU > 85% por 2m | critical |
| HighMemoryUsage | RAM > 90% por 2m | warning |
| DiskSpaceLow | Disco < 15% livre por 5m | warning |