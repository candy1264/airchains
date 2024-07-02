#!/bin/bash

# 监控的错误信息
ERROR_STRINGS=("cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991" "Failed to Init VRF")

echo "开始监控 stationd 日志..."

while true; do
  # 检查日志输出中是否包含错误字符串
  for ERROR_STRING in "${ERROR_STRINGS[@]}"; do
    if sudo journalctl -u stationd -f | grep -q "$ERROR_STRING"; then
      echo "检测到错误信息 '$ERROR_STRING'，重启 stationd 服务..."
      sudo systemctl restart stationd
    fi
  done
  # 每60秒检测一次
  sleep 60
done
