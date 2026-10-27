# PGA 监控系统 — Prometheus + Grafana + Alertmanager

一套用 Docker Compose 一键拉起的容器监控平台，自带一个 3 副本 nginx 应用集群 + Redis 作为被监控对象，开箱即有真实流量和真实告警演示。

[![CI](https://github.com/1apwn0/pga-monitoring/actions/workflows/ci.yml/badge.svg)](https://github.com/1apwn0/pga-monitoring/actions/workflows/ci.yml)

## 架构

```
                        ┌─────────────────────────────────────────┐
                        │            监控栈（PGA）                 │
                        │                                         │
 node-exporter ──┐      │  ┌────────────┐    ┌──────────────┐     │
 cadvisor ───────┼─拉取──┼─▶│ Prometheus │──▶ │ Alertmanager │     │
 redis-exporter ─┘      │  └─────┬──────┘    └──────────────┘     │
                        │        │ 抓取/存储                        │
                        │        ▼                                 │
                        │  ┌────────────┐                          │
                        │  │  Grafana   │  可视化看板 + 告警展示     │
                        │  └────────────┘                          │
                        └─────────────────────────────────────────┘

 被监控业务集群：app(nginx ×3 副本) + redis + loadgen(HTTP压测) + redis-loadgen(INCR写流量)
```

共 11 个容器：监控栈 6 个 + 业务集群 5 个（3 副本 app 算 3 个）。

## 一键启动

```bash
bash scripts/pull.sh        # 预拉镜像（gcr.io 被墙时自动走镜像源兜底）
docker compose up -d        # 启动全部 11 个容器
docker compose ps           # 查看状态
```

## 访问入口

| 服务 | 地址 | 说明 |
|------|------|------|
| Grafana | http://localhost:3000/d/pga-cluster | 看板免登录可看（匿名 Viewer）；管理员 admin / pga123 |
| Prometheus | http://localhost:9090/targets | 抓取目标健康状态 |
| Prometheus 告警 | http://localhost:9090/alerts | 规则触发状态 |
| Alertmanager | http://localhost:9093 | 告警分组/静默/通知 |
| cAdvisor | http://localhost:8090 | 原始容器指标 |
| node-exporter | http://localhost:9100/metrics | 原始节点指标 |

## 采集链路

- **node-exporter**（:9100）→ 宿主机（WSL Debian 节点）CPU / 内存 / 磁盘 / 网络
- **cAdvisor**（:8080）→ 每个容器的 CPU / 内存 / 网络收发，按 `name` 标签区分
- **redis-exporter**（:9121）→ Redis 连接数 / 命令速率 / 内存
- Prometheus 每 15s 抓一轮，每 15s 评估一次告警规则，命中后推给 Alertmanager

## 内置告警规则（prometheus/rules/alerts.yml）

| 告警 | 触发条件 | 级别 |
|------|---------|------|
| ExporterDown | 任一采集器 30s 抓不到 | critical |
| AppContainerDown | 应用副本容器 60s 无心跳 | warning |
| HighNodeCPU | 节点 CPU > 85% 持续 2m | warning |
| NodeMemoryPressure | 节点内存 > 90% 持续 2m | warning |
| RedisGone | redis_up == 0 | critical |

## 告警演示

```bash
docker stop pga-monitoring-app-2     # 干掉一个应用副本
# 约 1.5 分钟后：Grafana 看板「Firing 告警数」变红
# http://localhost:9090/alerts 出现 AppContainerDown FIRING
# http://localhost:9093 Alertmanager 收到分组告警
docker start pga-monitoring-app-2    # 恢复后告警自动 resolved
```

## CI/CD（.github/workflows/ci.yml）

push / PR 自动触发两个 job：

1. **配置校验**：`docker compose config` + `promtool check config`（含告警规则）+ `amtool check-config` + 看板 JSON 解析
2. **冒烟测试**：真实拉起 Prometheus + Alertmanager，等待 `/-/ready`，验证告警规则已加载后销毁

## 目录结构

```
├── docker-compose.yml          # 全部 11 个服务的编排
├── prometheus/
│   ├── prometheus.yml          # 抓取目标 + 告警上报
│   └── rules/alerts.yml        # 5 条告警规则
├── alertmanager/alertmanager.yml
├── grafana/
│   ├── provisioning/           # 数据源 + 看板自动加载（免手动导入）
│   └── dashboards/pga-cluster.json   # 12 面板中文看板
├── scripts/pull.sh             # 镜像预拉取（含镜像源兜底）
└── report/监控报告.md           # 一次完整运行的监控报告与截图
```
