#!/bin/bash
# Windows Git Bash 版：GitHub IP 翻烙饼环境下的自动重试推送
cd /d/A2/pga-monitoring || exit 1
CANDIDATES="20.205.243.166 20.200.245.247 20.27.177.113 140.82.112.3 140.82.113.4 140.82.116.3 140.82.121.3"
LOCAL=$(git rev-parse HEAD)

for round in $(seq 1 30); do
  for ip in $CANDIDATES; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --resolve github.com:443:$ip https://github.com 2>/dev/null)
    if [ "$code" = "200" ]; then
      echo "[$(date +%T)] 第 ${round} 轮：${ip} 可用，尝试推送"
      git config http.https://github.com/.curloptResolve github.com:443:$ip
      if GIT_TERMINAL_PROMPT=0 timeout 75 git push origin main >/dev/null 2>&1; then
        REMOTE=$(git ls-remote origin -h refs/heads/main 2>/dev/null | awk '{print $1}')
        if [ "$REMOTE" = "$LOCAL" ]; then
          echo "PUSH_SUCCESS 第 ${round} 轮 via ${ip}"
          exit 0
        fi
      fi
    fi
  done
  sleep 40
done
echo "PUSH_FAILED_ALL_ROUNDS"
exit 1
