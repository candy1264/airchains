#!/bin/bash

# 监控的错误信息
ERROR_STRING_1="cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991"
ERROR_STRING_2="Failed to Init VRF"

LOG_FILE="$HOME/logfile.log"

echo "开始监控 stationd 日志..."

# 实时输出日志到指定文件，并且在后台运行
sudo journalctl -u stationd -f -o cat > "$LOG_FILE" &

# 获取 journalctl 命令的进程ID，以便稍后停止
JOURNALCTL_PID=$!

# 循环检查日志文件中是否包含错误字符串
while true; do
  # 仅读取日志文件的最新3行来检测第一个错误字符串
  TAIL_LINES_3=$(tail -n 3 "$LOG_FILE")
  
  if echo "$TAIL_LINES_3" | grep -q "$ERROR_STRING_1"; then
    echo "检测到错误信息 '$ERROR_STRING_1'，重启 stationd 服务..."
    sudo systemctl restart stationd
  fi

  # 仅读取日志文件的最新100行来检测第二个错误字符串
  TAIL_LINES_100=$(tail -n 100 "$LOG_FILE")

  if echo "$TAIL_LINES_100" | grep -q "$ERROR_STRING_2"; then
    echo "检测到错误信息 '$ERROR_STRING_2'，重启 stationd 服务..."
    sudo systemctl restart stationd
  fi

  sleep 60
done
