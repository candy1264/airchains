#!/bin/bash

# 监控的错误信息
ERROR_STRINGS=("cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991" "Failed to Init VRF")

LOG_FILE="$HOME/logfile.log"

echo "开始监控 stationd 日志..."

# 实时输出日志到指定文件，并且在后台运行
sudo journalctl -u stationd -f -o cat > "$LOG_FILE" &

# 获取 journalctl 命令的进程ID，以便稍后停止
JOURNALCTL_PID=$!

# 循环检查日志文件中是否包含错误字符串
while true; do
  # 仅读取日志文件的最后50行
  TAIL_LINES=$(tail -n 50 "$LOG_FILE")
  
  for ERROR_STRING in "${ERROR_STRINGS[@]}"; do
    if echo "$TAIL_LINES" | grep -q "$ERROR_STRING"; then
      echo "检测到错误信息 '$ERROR_STRING'，重启 stationd 服务..."
      sudo systemctl restart stationd
      break
    fi
  done
  
  sleep 60
done
