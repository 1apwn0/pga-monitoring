#!/usr/bin/env python3
# 采集监控报告数据：Prometheus API 查询 + 业务侧 redis-cli
import json
import subprocess
import urllib.parse
import urllib.request

PROM = "http://localhost:9090/api/v1/query"


def q(expr):
    url = PROM + "?" + urllib.parse.urlencode({"query": expr})
    with urllib.request.urlopen(url, timeout=15) as r:
        data = json.load(r)
    return data["data"]["result"]


def one(expr):
    r = q(expr)
    return float(r[0]["value"][1]) if r else None


print("===== 应用副本在线数 =====")
n = one('count(container_last_seen{name=~".*-app-[0-9]+"})')
print(int(n) if n is not None else 0)

print("===== 容器内存 TOP8 =====")
for x in q('topk(8, max by (name) (container_memory_usage_bytes{name!="", name!="/"}))'):
    name = x["metric"].get("name", "?")
    v = float(x["value"][1])
    print("%-40s %8.1f MB" % (name, v / 1024 / 1024))

print("===== 容器CPU TOP8（毫核·1m均值） =====")
for x in q('topk(8, sum by (name) (rate(container_cpu_user_seconds_total{name!="", name!="/"}[1m])))'):
    name = x["metric"].get("name", "?")
    v = float(x["value"][1]) * 1000
    print("%-40s %6.2f mCore" % (name, v))

print("===== 容器网络收流量 TOP5（B/s） =====")
for x in q('topk(5, sum by (name) (rate(container_network_receive_bytes_total{name!="", name!="/"}[1m])))'):
    name = x["metric"].get("name", "?")
    print("%-40s %8.0f B/s" % (name, float(x["value"][1])))

print("===== 节点资源 =====")
v = one('100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)')
print("CPU使用率: %.1f%%" % v if v is not None else "CPU使用率: 无数据")
v = one('(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100')
print("内存使用率: %.1f%%" % v if v is not None else "内存使用率: 无数据")

print("===== Redis 状态 =====")
print("连接数:", one("redis_connected_clients"))
v = one("rate(redis_commands_processed_total[1m])")
print("命令速率: %.1f 次/秒" % v if v is not None else "命令速率: 无数据")
v = one("redis_memory_used_bytes")
print("内存: %.0f KB" % (v / 1024) if v is not None else "内存: 无数据")

print("===== Redis 命中计数器（业务侧） =====")
out = subprocess.run(
    ["docker", "exec", "pga-monitoring-redis-loadgen-1",
     "sh", "-c", "redis-cli -h redis GET pga:hits"],
    capture_output=True, text=True)
print(out.stdout.strip() or out.stderr.strip())

print("===== 当前告警 =====")
alerts = q("ALERTS")
if not alerts:
    print("（无）")
for x in alerts:
    m = x["metric"]
    print("%-8s %s" % (m.get("alertstate", "?"), m.get("alertname", "?")))

print("COLLECT_DONE")
