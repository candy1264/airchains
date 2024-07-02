#!/bin/bash

# 定义服务名称和错误字符串
service_name="stationd"
error_string="cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991"
log_file="/var/log/journal/$(journalctl --list-boots | awk 'NR==2{print $1}')/system.journal"
last_checked=""

# 检查日志文件是否存在
if [ ! -f "$log_file" ]; then
  echo "日志文件 $log_file 不存在。"
  exit 1
fi

echo "开始监控 $service_name 的日志..."

while true; do
  # 获取最近的日志条目
  new_log=$(sudo journalctl -u "$service_name" -n 100 -o cat | grep "$error_string")

  # 检查是否有新的错误日志
  if [[ -n "$new_log" && "$new_log" != "$last_checked" ]]; then
    echo "检测到错误日志，正在重新启动 $service_name..."
    sudo systemctl restart "$service_name"
    echo "$service_name 已重新启动。"
    last_checked="$new_log"
  else
    echo "没有检测到新的错误日志。"
  fi

  # 等待 60 秒后重新检查
  sleep 60
done
