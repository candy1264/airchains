#!/bin/bash

# 检查并安装依赖项
dependencies=("build-essential" "git" "make" "jq" "curl" "clang" "pkg-config" "libssl-dev" "wget")
for dep in "${dependencies[@]}"; do
    if dpkg-query -W "$dep" >/dev/null 2>&1; then
        echo "$dep 已安装，跳过安装步骤。"
    else
        echo "安装 $dep..."
        sudo apt update
        sudo apt install -y "$dep"
    fi
done

# 检查并安装 Go
if command -v go >/dev/null 2>&1; then
    echo "go 已安装，跳过安装步骤。"
else
    echo "下载并安装 Go..."
    wget -c https://golang.org/dl/go1.22.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
    if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    source ~/.bashrc
fi

# 克隆 Git 仓库
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git

# 进入 evm-station 并执行 go mod tidy
cd $HOME/evm-station && go mod tidy

# 确保脚本路径正确
nano ./scripts/local-setup.sh
/bin/bash ./scripts/local-setup.sh

# 修改 JSON-RPC 监听地址
sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml

# 提示用户输入 CHAIN_ID
read -p "Enter new CHAIN_ID (default: 重复上面修改文档的CHAIN ID 名字加_1234-1): " CHAIN_ID
CHAIN_ID=${CHAIN_ID:-name_1234-1}

# 创建并启动 evmosd 服务
cat > /etc/systemd/system/evmosd.service << EOF
[Unit]
Description=evmosd node
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/.evmosd
ExecStart=$HOME/evm-station/build/station-evm start --metrics "" --log_level "info" --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id "$CHAIN_ID"
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable evmosd
systemctl restart evmosd

# 部署 eigen
wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
sudo chmod +x eigenlayer
sudo mv eigenlayer /usr/local/bin/eigenlayer

# 检查并创建密钥
KEY_FILE="$HOME/.eigenlayer/operator_keys/wallet.ecdsa.key.json"
if [ -f "$KEY_FILE" ]; then
    echo "文件 $KEY_FILE 已经存在，删除文件"
    rm -f "$KEY_FILE"
fi
echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet

# 删除旧的 tracks 配置并初始化
sudo rm -rf ~/.tracks
cd $HOME/tracks
go mod tidy

# 提示用户输入公钥和节点名
read -p "请输入Public Key hex: " dakey
read -p "请输入节点名: " moniker
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 初始化 tracks
go run cmd/main.go init \
    --daRpc "disperser-holesky.eigenda.xyz" \
    --daKey "$dakey" \
    --daType "eigen" \
    --moniker "$moniker" \
    --stationRpc "http://$LOCAL_IP:8545" \
    --stationAPI "http://$LOCAL_IP:8545" \
    --stationType "evm"

# 提示用户选择操作
echo "你需要创建新地址吗？（Y/N/S）"
echo "Y: 创建新地址"
echo "N: 导入地址"
echo "S: 跳过"
read -r response

# 将用户输入转换为大写
response=$(echo "$response" | tr '[:lower:]' '[:upper:]')

# 根据用户输入执行相应命令
if [[ "$response" == "Y" ]]; then
    echo "正在创建新地址..."
    go run cmd/main.go keys junction --accountName wallet --accountPath "$HOME/.tracks/junction-accounts/keys"
elif [[ "$response" == "N" ]]; then
    echo "请输入你的助记词："
    read -r mnemonic
    echo "正在导入地址..."
    go run cmd/main.go keys import --accountName wallet --accountPath "$HOME/.tracks/junction-accounts/keys" --mnemonic "$mnemonic"
elif [[ "$response" == "S" ]]; then
    echo "已跳过创建或导入地址的步骤。"
else
    echo "无效的输入，请输入“Y”、“N”或“S”。"
fi

go run cmd/main.go prover v1EVM

# 询问用户是否要继续执行
read -p "是否已经领水完毕要继续执行？(yes/no): " choice

if [[ "$choice" != "yes" ]]; then
    echo "脚本已终止。"
    exit 0
fi

# 如果用户选择继续，则执行以下操作
echo "继续执行脚本..."

CONFIG_PATH="$HOME/.tracks/config/sequencer.toml"

# 定义初始 WALLET_PATH
WALLET_PATH="$HOME/.tracks/junction-accounts/keys/wallet.wallet.json"

# 检查 WALLET_PATH 是否存在
if [ -f "$WALLET_PATH" ]; then
    echo "钱包文件存在，从钱包文件中提取地址..."
    AIR_ADDRESS=$(jq -r '.address' "$WALLET_PATH")
else
    echo "钱包文件不存在，请输入钱包地址："
    read -r AIR_ADDRESS
    echo "你输入的钱包地址是: $AIR_ADDRESS"
fi

# 从配置文件中提取 nodeid
NODE_ID=$(grep 'node_id =' $CONFIG_PATH | awk -F'"' '{print $2}')

# 获取本机 IP 地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 定义 JSON RPC URL 和其他参数
JSON_RPC="https://airchains-rpc.kubenode.xyz/"
INFO="EVM Track"
BOOTSTRAP_NODE="/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID"

# 运行 tracks create-station 命令
create_station_cmd="go run cmd/main.go create-station \
    --accountName wallet \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC \"$JSON_RPC\" \
    --info \"$INFO\" \
    --tracks \"$AIR_ADDRESS\" \
    --bootstrapNode \"$BOOTSTRAP_NODE\""

echo "Running command:"
echo "$create_station_cmd"

# 执行命令
eval "$create_station_cmd"

# 创建并启动 stationd 服务
sudo tee /etc/systemd/system/stationd.service > /dev/null << EOF
[Unit]
Description=station track service
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/tracks/
ExecStart=$(which go) run cmd/main.go start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable stationd
sudo systemctl restart stationd

# 定义功能
function evmos_log(){
    journalctl -u evmosd -f
}

function stationd_log(){
    sudo journalctl -u stationd -f -o cat
}

function private_key(){
    #evmos私钥#
    cd $HOME/evm-station/ && /bin/bash ./scripts/local-keys.sh

    #airchain助记词#
    cat $HOME/.tracks/junction-accounts/keys/wallet.wallet.json
}

function check_avail_address(){
    journalctl -u availd | head 
}

function restart(){
    sudo systemctl restart evmosd
    sudo systemctl restart stationd
}

function delete_node(){
    rm -rf .evmosd
    rm -rf .tracks
    sudo systemctl stop evmosd.service
    sudo systemctl stop stationd.service
    sudo systemctl disable availd.service
    sudo systemctl disable evmosd.service
    sudo systemctl disable stationd.service
    sudo pkill -9 evmosd
    sudo pkill -9 stationd
    sudo journalctl --vacuum-time=1s
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区candy编写，推特 @ccaannddyy11，免费开源，请勿相信收费"
        echo "特别鸣谢 @TestnetCn @y95277777 @EthExploring"
        echo "================================================================"
        echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
        echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 查看evmos状态"
        echo "3. 查看stationd状态"
        echo "4. 导出所有私钥"
        echo "5. 查看avail地址"
        echo "6. 删除节点"
        read -p "请输入选项（1-6）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) evmos_log ;;
        3) stationd_log ;;
        4) private_key ;;
        5) check_avail_address ;;
        6) delete_node ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
