#!/bin/bash

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
    wget -c https://golang.org/dl/go1.22.3.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
fi

# 验证安装后的 Go 版本
echo "当前 Go 版本："
go version

function install_node() {
if [ -d "/data/airchains/evm-station" ]; then
    rm -rf /data/airchains/evm-station
fi

if [ -d "tracks" ]; then
    rm -rf tracks
fi
mkdir -p /data/airchains/ && cd /data/airchains/
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git
cd /data/airchains/evm-station  && go mod tidy
/bin/bash ./scripts/local-setup.sh
# 确保脚本路径正确


    #自定义CHAINID和MONIKER,默认填写了node，不知道可不可以用同一个名字#
    sed -i.bak 's@CHAINID="{CHAIN_ID:-testname_1234-1}"@CHAINID="{CHAIN_ID:-node_1234-1}"@' /data/airchains/evm-station/scripts/local-setup.sh
    sed -i.bak 's@MONIKER="TESTNAME"@MONIKER="node"@' /data/airchains/evm-station/scripts/local-setup.sh
    #把json-rpc监听地址改为0.0.0.0#
    sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml
    #修改 — chain-id 为 上一步自定义的CHAINID，默认填写了node，保留1234-1#
    cat > /etc/systemd/system/evmosd.service << EOF
[Unit]
Description=evmosd node
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/.evmosd
ExecStart=/data/airchains/evm-station/build/station-evm start --metrics "" --log_level "info" --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id "node_1234-1"
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable evmosd
    systemctl restart evmosd
    #部署avail轻节点#
    mkdir  /data/airchains/availda && cd /data/airchains/availda
    wget https://github.com/availproject/avail-light/releases/download/v1.9.1/avail-light-linux-amd64.tar.gz
    tar xvf avail-light-linux-amd64.tar.gz
    mv avail-light-linux-amd64 avail-light  && chmod +x avail-light

    mkdir -p ~/.avail/turing/bin
    mkdir -p ~/.avail/turing/data
    mkdir -p ~/.avail/turing/config
    mkdir -p ~/.avail/identity

    cat > ~/.avail/turing/config/config.yml << EOF
bootstraps=['/dns/bootnode.1.lightclient.turing.avail.so/tcp/37000/p2p/12D3KooWBkLsNGaD3SpMaRWtAmWVuiZg1afdNSPbtJ8M8r9ArGRT']
full_node_ws=['wss://avail-turing.public.blastapi.io','wss://turing-testnet.avail-rpc.com']
confidence=80.0
avail_path='/root/.avail/turing/data'
kad_record_ttl=43200
ot_collector_endpoint='http://otel.lightclient.turing.avail.so:4317'
genesis_hash='d3d2f3a3495dc597434a99d7d449ebad6616db45e4e4f178f31cc6fa14378b70'
EOF
    cat > /etc/systemd/system/availd.service << EOF
[Unit]
Description=Avail Light Client
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/data/airchains/availda/avail-light --network "turing" --config /root/.avail/turing/config/config.yml --app-id 36 --identity /root/.avail/identity/identity.toml
 
Restart=always
RestartSec=30
Environment="DAEMON_HOME=/root/.avail"

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable availd

    systemctl restart availd 
    journalctl -u availd |head
    #部署Tracks服务#
cd /data/airchains/tracks/ && make build 
    # 提取 public key
JOURNALCTL_CMD="journalctl -u availd | grep 'public key'"

# 从 availd 的日志中提取公钥
extract_public_key() {
    eval $JOURNALCTL_CMD | awk -F'public key: ' '{print $2}' | head -n 1
}

# 调用提取函数
public_key=$(extract_public_key)
# 获取本机ip地址
LOCAL_IP=$(hostname -I | awk '{print $1}')
# 检查是否提取到公钥
if [ -n "$public_key" ]; then
    echo "Public key found: $public_key"
else
    echo "Error: Could not find public key in availd logs"
    exit 1
fi
    #注意修改 — daKey和 — moniker，moniker默认为node#
    /data/airchains/tracks/build/tracks init --daRpc "http://127.0.0.1:7000" --daKey "$public_key" --daType "avail" --moniker "node" --stationRpc "http://$LOCAL_IP:8545" --stationAPI "http://$LOCAL_IP:8545" --stationType "evm"
    #生成airchains钱包#
    /data/airchains/tracks/build/tracks keys junction --accountName node --accountPath $HOME/.tracks/junction-accounts/keys
    
    /data/airchains/tracks/build/tracks prover v1EVM
    #获取nodeid#
    grep node_id ~/.tracks/config/sequencer.toml
    #修改gas#
    sed -i.bak 's/utilis\.GenerateRandomWithFavour(1200, 2400, \[2\]int{1500, 2000}, 0\.7)/utilis.GenerateRandomWithFavour(24000, 34000, [2]int{26000, 30000}, 0.7)/' /data/airchains/tracks/junction/createStation.go

    cd /data/airchains/tracks/ && make build
    cat $HOME/.tracks/junction-accounts/keys/node.wallet.json
    echo "是否领取完成amf？ (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "未完成amf领取，退出脚本。"
    exit 1  # 可以选择退出脚本或者采取其他操作
fi

# 继续执行后续的脚本内容...

    #填入刚创建的钱包名字，以及air开头的钱包地址，本地IP地址，上面获取到的nodeid#
        # 定义路径#
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
    --accountName node \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC \"https://airchains-rpc.kubenode.xyz/\" \
    --info \"EVM Track\" \
    --tracks \"$AIR_ADDRESS\" \
    --bootstrapNode \"/ip4/$LOCAL_IP/tcp/2300/p2p/$node_id\""

echo "Running command:"
echo "$create_station_cmd"

# 执行命令
eval "$create_station_cmd"
cd /data/airchains/tracks/ && make build
    #把Tracks加入守护进程并启动#
    cat > /etc/systemd/system/tracksd.service << EOF
[Unit]
Description=tracksd
After=network-online.target

[Service]
User=root
WorkingDirectory=/root/.tracks
ExecStart=/data/airchains/tracks/build/tracks start

Restart=always
RestartSec=10
LimitNOFILE=65535
SuccessExitStatus=0 1
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable tracksd
    systemctl restart tracksd
}

function evmos_log(){
    journalctl -u evmosd -f
}
function avail_log(){
    journalctl -u availd -f

}
function tracks_log(){
    journalctl -u tracksd -f
}
function private_key(){
    #evmos私钥#
    cd /data/airchains/evm-station/ &&  /bin/bash ./scripts/local-keys.sh
    #avail助记词#
    cat /root/.avail/identity/identity.toml
    #airchain助记词#
    cat $HOME/.tracks/junction-accounts/keys/node.wallet.json

}
function check_avail_address(){
journalctl -u availd |head 
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
        echo "3. 查看avail状态"
        echo "4. 查看tracks状态"
        echo "5. 导出所有私钥"
        echo "6. 查看avail地址"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) evmos_log ;;
        3) avail_log ;;
        4) tracks_log ;;
        5) private_key ;;
        6) check_avail_address ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
    
}

# 显示主菜单
main_menu
