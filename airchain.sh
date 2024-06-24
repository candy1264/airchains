
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
eigenlayer operator keys create  -i=true --key-type ecdsa wallet
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

go run cmd/main.go keys junction --accountName wallet --accountPath $HOME/.tracks/junction-accounts/keys
nodeid=$(grep "node_id" ~/.tracks/config/sequencer.toml | awk -F '"' '{print $2}')
ip=$(curl -s4 ifconfig.me/ip)
bootstrapNode=/ip4/$ip/tcp/2300/p2p/$nodeid
echo $bootstrapNode
CONFIG_PATH="$HOME/.tracks/config/sequencer.toml"
WALLET_PATH="$HOME/.tracks/junction-accounts/keys/node.wallet.json"

# 从配置文件中提取 nodeid
NODE_ID=$(grep 'node_id =' $CONFIG_PATH | awk -F'"' '{print $2}')

# 从钱包文件中提取 air 开头的钱包地址
AIR_ADDRESS=$(jq -r '.address' $WALLET_PATH)

# 获取本机 IP 地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 定义 JSON RPC URL 和其他参数
JSON_RPC="https://airchains-rpc.kubenode.xyz/"
INFO="EVM Track"
TRACKS="air_address"
BOOTSTRAP_NODE="/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID"

# 运行 tracks create-station 命令
create_station_cmd="/data/airchains/tracks/build/tracks create-station \
    --accountName wallet \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC \"https://airchains-rpc.kubenode.xyz/\" \
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

function tracks_log(){
    journalctl -u tracksd -f
}
function private_key(){
    #evmos私钥#
    cd $HOME/data/airchains/evm-station/ &&  /bin/bash ./scripts/local-keys.sh
    #airchain助记词#
    cat $HOME/.tracks/junction-accounts/keys/node.wallet.json

}
function restart(){
sudo systemctl restart evmosd
sudo systemctl restart tracksd
}

function delete_node(){
sudo rm -rf data
sudo rm -rf .evmosd
sudo rm -rf .tracks
sudo systemctl stop evmosd.service
sudo systemctl stop tracksd.service
sudo systemctl disable evmosd.service
sudo systemctl disable tracksd.service
sudo pkill -9 evmosd
sudo pkill -9 tracksd
sudo journalctl --vacuum-time=1s

}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区candy编写，推特 @ccaannddyy11，免费开源，请勿相信收费"
        echo "特别鸣谢 @TestnetCn @y95277777"
        echo "================================================================"
        echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
        echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 查看evmos状态"
        echo "3. 查看tracks状态"
        echo "4. 导出所有私钥"
        echo "5. 删除节点"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) evmos_log ;;
        3) tracks_log ;;
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
