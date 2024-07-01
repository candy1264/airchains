
# 检查是否已安装 build-essential
if dpkg-query -W build-essential >/dev/null 2>&1; then
    echo "build-essential 已安装，跳过安装步骤。"
else
    echo "安装 build-essential..."
    sudo apt update
    sudo apt install -y build-essential
fi

# 检查是否已安装 git
if dpkg-query -W git >/dev/null 2>&1; then
    echo "git 已安装，跳过安装步骤。"
else
    echo "安装 git..."
    sudo apt update
    sudo apt install -y git
fi

# 检查是否已安装 make
if dpkg-query -W make >/dev/null 2>&1; then
    echo "make 已安装，跳过安装步骤。"
else
    echo "安装 make..."
    sudo apt update
    sudo apt install -y make
fi

# 检查是否已安装 jq
if dpkg-query -W jq >/dev/null 2>&1; then
    echo "jq 已安装，跳过安装步骤。"
else
    echo "安装 jq..."
    sudo apt update
    sudo apt install -y jq
fi

# 检查是否已安装 curl
if dpkg-query -W curl >/dev/null 2>&1; then
    echo "curl 已安装，跳过安装步骤。"
else
    echo "安装 curl..."
    sudo apt update
    sudo apt install -y curl
fi

# 检查是否已安装 clang
if dpkg-query -W clang >/dev/null 2>&1; then
    echo "clang 已安装，跳过安装步骤。"
else
    echo "安装 clang..."
    sudo apt update
    sudo apt install -y clang
fi

# 检查是否已安装 pkg-config
if dpkg-query -W pkg-config >/dev/null 2>&1; then
    echo "pkg-config 已安装，跳过安装步骤。"
else
    echo "安装 pkg-config..."
    sudo apt update
    sudo apt install -y pkg-config
fi

# 检查是否已安装 libssl-dev
if dpkg-query -W libssl-dev >/dev/null 2>&1; then
    echo "libssl-dev 已安装，跳过安装步骤。"
else
    echo "安装 libssl-dev..."
    sudo apt update
    sudo apt install -y libssl-dev
fi

# 检查是否已安装 wget
if dpkg-query -W wget >/dev/null 2>&1; then
    echo "wget 已安装，跳过安装步骤。"
else
    echo "安装 wget..."
    sudo apt update
    sudo apt install -y wget
fi

# 检查是否已安装 go
if command -v go >/dev/null 2>&1; then
    echo "go 已安装，跳过安装步骤。"
else
    echo "下载并安装 Go..."
    wget -c https://golang.org/dl/go1.22.4.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
fi

# 验证安装后的 Go 版本
echo "当前 Go 版本："
go version

function install_node() {
    sudo apt-get update && sudo apt-get install jq build-essential -y
    cd $HOME
    git clone https://github.com/airchains-network/wasm-station.git
    git clone https://github.com/airchains-network/tracks.git
    cd wasm-station
    go mod tidy
    /bin/bash ./scripts/local-setup.sh

    sudo tee <<EOF >/dev/null /etc/systemd/system/wasmstationd.service
[Unit]
Description=wasmstationd
After=network.target

[Service]
User=$USER
ExecStart=$HOME/wasm-station/build/wasmstationd start --api.enable
Restart=always
RestartSec=3
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload && \
    sudo systemctl enable wasmstationd && \
    sudo systemctl start wasmstationd
    
    cd
wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
sudo chmod +x eigenlayer
sudo mv eigenlayer /usr/local/bin/eigenlayer
# 定义文件路径
KEY_FILE="$HOME/.eigenlayer/operator_keys/wallet.ecdsa.key.json"
# 检查文件是否存在
if [ -f "$KEY_FILE" ]; then
    echo "文件 $KEY_FILE 已经存在，删除文件"
    rm -f "$KEY_FILE"
    # 执行创建密钥命令
    echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet
else
    echo "文件 $KEY_FILE 不存在，执行创建密钥操作"
    # 执行创建密钥命令
    echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet
fi

sudo rm -rf ~/.tracks
cd $HOME/tracks
go mod tidy
#!/bin/bash

# 提示用户输入公钥和节点名
read -p "请输入Public Key hex: " dakey
read -p "请输入节点名: " moniker

# 执行 Go 命令，替换用户输入的值
go run cmd/main.go init \
    --daRpc "disperser-holesky.eigenda.xyz" \
    --daKey "$dakey" \
    --daType "eigen" \
    --moniker "$moniker" \
    --stationRpc "http://127.0.0.1:26657" \
    --stationAPI "http://127.0.0.1:1317" \
    --stationType "wasm"

#!/bin/bash

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



go run cmd/main.go prover v1WASM

# 询问用户是否要继续执行
read -p "是否已经领水完毕要继续执行？(yes/no): " choice

if [[ "$choice" != "yes" ]]; then
    echo "脚本已终止。"
    exit 0
fi

# 如果用户选择继续，则执行以下操作
echo "继续执行脚本..."

echo $bootstrapNode
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
JSON_RPC="https://airchains-testnet-rpc.cosmonautstakes.com"
INFO="EVM Track"
TRACKS="air_address"
BOOTSTRAP_NODE="/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID"

# 运行 tracks create-station 命令
create_station_cmd="go run cmd/main.go create-station \
    --accountName wallet \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC \"https://airchains-testnet-rpc.cosmonautstakes.com\" \
    --info \"WASM Track\" \
    --tracks \"$AIR_ADDRESS\" \
    --bootstrapNode \"/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID\""

echo "Running command:"
echo "$create_station_cmd"

# 执行命令
eval "$create_station_cmd"
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
}



function evmos_log(){
    journalctl -u evmosd -f
}

function stationd_log(){
    journalctl -u stationd -f
}
function private_key(){
    #evmos私钥#
    cd $HOME/data/airchains/evm-station/ &&  /bin/bash ./scripts/local-keys.sh
    #airchain助记词#
    cat $HOME/.tracks/junction-accounts/keys/wallet.wallet.json

}
function restart(){
sudo systemctl restart evmosd
sudo systemctl restart tracksd
}

function delete_node(){
sudo rm -rf data
sudo rm -rf .wasmstationd
sudo rm -rf .tracks
sudo systemctl stop wasmstationd.service
sudo systemctl stop stationd.service
sudo systemctl disable wasmstationd.service
sudo systemctl disable stationd.service
sudo pkill -9 wasmstationd
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
        echo "2. 查看wasmstationd状态"
        echo "3. 查看stationd状态"
        echo "4. 导出所有私钥"
        echo "5. 删除节点"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) wasmstationd_log ;;
        3) stationd_log ;;
        4) private_key ;;
        5) delete_node ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
    
}

# 显示主菜单
main_menu
