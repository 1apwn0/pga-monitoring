#!/bin/bash
# gh-proxy 单线程仅 ~12KB/s，但支持 Range → 16 线程分段并行下载
set -e
cd /mnt/d/A2/pga-monitoring/scripts/cadvisor

URL="https://gh-proxy.com/https://github.com/google/cadvisor/releases/download/v0.49.1/cadvisor-v0.49.1-linux-amd64"

TOTAL=$(curl -sIL "$URL" | grep -i '^content-length' | tail -1 | tr -d '\r' | awk '{print $2}')
if [ -z "$TOTAL" ]; then echo "ERROR: 拿不到 Content-Length"; exit 1; fi
echo "总大小: $TOTAL 字节"

N=16
CHUNK=$(( (TOTAL + N - 1) / N ))
rm -f part_* cadvisor-binary

for i in $(seq 0 $((N-1))); do
  START=$((i*CHUNK))
  END=$(( (i+1)*CHUNK - 1 ))
  [ "$END" -ge "$TOTAL" ] && END=$((TOTAL-1))
  curl -s --retry 5 --retry-all-errors --max-time 900 \
       -r "${START}-${END}" -o "part_$(printf %02d "$i")" "$URL" &
done
wait

cat part_* > cadvisor-binary
rm -f part_*
ACTUAL=$(stat -c %s cadvisor-binary)
echo "实际大小: $ACTUAL 字节"
if [ "$ACTUAL" = "$TOTAL" ]; then
  chmod +x cadvisor-binary
  echo "DOWNLOAD_OK"
else
  echo "DOWNLOAD_SIZE_MISMATCH"; exit 1
fi
