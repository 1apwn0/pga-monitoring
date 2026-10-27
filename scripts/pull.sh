#!/bin/bash
# 拉取 PGA 监控栈所需镜像；gcr.io 被墙时用镜像源兜底并 retag
cd /mnt/d/A2/pga-monitoring || exit 1

for img in prom/prometheus:v2.53.1 grafana/grafana:11.4.0 prom/alertmanager:v0.27.0 oliver006/redis_exporter:v1.66.0; do
  echo "=== pull $img"
  docker pull "$img" >/dev/null 2>&1 && echo "OK $img" || echo "FAIL $img"
done

echo "=== pull cadvisor"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^gcr.io/cadvisor/cadvisor:v0.49.1'; then
  echo "OK cadvisor already local"
else
  for src in gcr.io/cadvisor/cadvisor:v0.49.1 \
             docker.1ms.run/gcr.io/cadvisor/cadvisor:v0.49.1 \
             docker.xuanyuan.me/gcr.io/cadvisor/cadvisor:v0.49.1 \
             docker.m.daocloud.io/gcr.io/cadvisor/cadvisor:v0.49.1; do
    echo "--- try $src"
    if docker pull "$src" >/dev/null 2>&1; then
      if [ "$src" != "gcr.io/cadvisor/cadvisor:v0.49.1" ]; then
        docker tag "$src" gcr.io/cadvisor/cadvisor:v0.49.1
      fi
      echo "OK cadvisor from $src"
      break
    fi
  done
fi

echo "=== local images"
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'prom/|grafana|redis_exporter|cadvisor' | sort
echo "PULL_SCRIPT_DONE"
