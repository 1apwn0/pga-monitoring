#!/bin/bash
# 断点续传：只补未完成 part 的缺失尾部区间，每段再拆 4 线程，最多重试 10 轮
cd /mnt/d/A2/pga-monitoring/scripts/cadvisor || exit 1
URL="https://gh-proxy.com/https://github.com/google/cadvisor/releases/download/v0.49.1/cadvisor-v0.49.1-linux-amd64"
TOTAL=47502823
N=16
CHUNK=$(( (TOTAL + N - 1) / N ))

for round in $(seq 1 10); do
  ALLDONE=1
  PIDS=""
  for i in $(seq 0 $((N-1))); do
    f=$(printf "part_%02d" "$i")
    start=$((i*CHUNK)); end=$(( (i+1)*CHUNK - 1 )); [ "$end" -ge "$TOTAL" ] && end=$((TOTAL-1))
    want=$((end-start+1))
    have=0; [ -f "$f" ] && have=$(stat -c %s "$f")
    if [ "$have" -lt "$want" ]; then
      ALLDONE=0
      missing=$((want-have))
      sub=$(( (missing + 3) / 4 ))
      for k in 0 1 2 3; do
        s2=$((start+have+k*sub)); e2=$((start+have+(k+1)*sub-1))
        [ "$e2" -gt "$end" ] && e2=$end
        [ "$s2" -gt "$e2" ] && continue
        curl -s --max-time 240 -r "${s2}-${e2}" -o "seg_${f}_${k}" "$URL" &
        PIDS="$PIDS $!"
      done
    fi
  done
  [ "$ALLDONE" = "1" ] && break
  echo "第 ${round} 轮补传中..."
  wait
  for i in $(seq 0 $((N-1))); do
    f=$(printf "part_%02d" "$i")
    if ls seg_${f}_* >/dev/null 2>&1; then
      cat $(ls seg_${f}_* | sort) >> "$f"
      rm -f seg_${f}_*
    fi
  done
done

# 校验完整性
ACTUAL=0
for i in $(seq 0 $((N-1))); do
  f=$(printf "part_%02d" "$i"); [ -f "$f" ] && ACTUAL=$((ACTUAL + $(stat -c %s "$f")))
done
echo "当前累计: $ACTUAL / $TOTAL"
if [ "$ACTUAL" = "$TOTAL" ]; then
  cat $(ls part_* | sort) > cadvisor-binary
  rm -f part_*
  chmod +x cadvisor-binary
  echo "RESUME_OK"
else
  echo "STILL_INCOMPLETE"; exit 1
fi
