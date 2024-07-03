# 监控的错误信息
ERROR_STRINGS=("cosmos/cosmos-sdk@v0.50.3/baseapp/baseapp.go:991" "Failed to Init VRF")

LOG_FILE="$HOME/logfile.log"

echo "开始监控 stationd 日志..."

# 实时输出日志到指定文件
sudo journalctl -u stationd -f -o cat > "$LOG_FILE" &

# 循环检查日志文件中是否包含错误字符串
while true; do
  for ERROR_STRING in "${ERROR_STRINGS[@]}"; do
    if grep -q "$ERROR_STRING" "$LOG_FILE"; then
      echo "检测到错误信息 '$ERROR_STRING'，重启 stationd 服务..."
      sudo systemctl restart stationd
    fi
  done
  sleep 60
done
