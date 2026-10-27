#!/bin/bash
# gcr.io 被墙且镜像源不代理时：从 GitHub Release 拉 cadvisor 静态二进制，本地构建镜像
set -e
cd /mnt/d/A2/pga-monitoring/scripts/cadvisor

VER=v0.49.1
ASSET=cadvisor-${VER}-linux-amd64

if [ ! -s cadvisor-binary ]; then
  echo "下载 $ASSET（直连，失败则走 gh-proxy）"
  curl -fL --retry 2 --max-time 300 -o cadvisor-binary \
    "https://github.com/google/cadvisor/releases/download/${VER}/${ASSET}" \
  || curl -fL --retry 2 --max-time 300 -o cadvisor-binary \
    "https://gh-proxy.com/https://github.com/google/cadvisor/releases/download/${VER}/${ASSET}"
fi

chmod +x cadvisor-binary
docker build -t gcr.io/cadvisor/cadvisor:v0.49.1 .
echo "CADVISOR_BUILD_OK"
