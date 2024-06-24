
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


if [ -d "/root/data/airchains/evm-station" ]; then
    rm -rf /root/data/airchains/evm-station
fi

if [ -d "tracks" ]; then
    rm -rf tracks
fi


mkdir -p /root/data/airchains/ && cd /root/data/airchains/
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git

cd /root/data/airchains/evm-station  && go mod tidy

# 确保脚本路径正确
nano ./scripts/local-setup.sh
/bin/bash ./scripts/local-setup.sh

    #把json-rpc监听地址改为0.0.0.0#
    sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml
    #修改 — chain-id 为 上一步自定义的CHAINID，默认填写了node，保留1234-1#
    # 提示用户输入 CHAIN_ID
read -p "Enter new CHAIN_ID (default: 重复上面修改文档的CHAIN ID 名字加_1234-1): " CHAIN_ID
CHAIN_ID=${CHAIN_ID:-name_1234-1}  # 设置默认值

    cat > /etc/systemd/system/evmosd.service << EOF
[Unit]
Description=evmosd node
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/.evmosd
ExecStart=/root/data/airchains/evm-station/build/station-evm start --metrics "" --log_level "info" --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id "$CHAIN_ID"
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable evmosd
    systemctl restart evmosd
##
cd
wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
sudo chmod +x eigenlayer
sudo mv eigenlayer /usr/local/bin/eigenlayer
# 定义key_file的路径
key_file="/root/.eigenlayer/operator_keys/node.ecdsa.key.json"  # 替换为你的实际文件路径

# 检查文件是否存在
if [ -f "$key_file" ]; then
    echo "文件 $key_file 已经存在，删除文件"
    rm -f "$key_file"
    echo "删除文件后执行创建操作"
    echo "123456" | eigenlayer operator keys create --key-type ecdsa --insecure node
else
    echo "文件 $key_file 不存在，执行创建操作"
    echo "123456" | eigenlayer operator keys create --key-type ecdsa --insecure node
fi

# 定义提取公钥的函数，接受一个参数作为提示信息
extract_public_key() {
    local prompt="$1"  # 接受第一个参数作为提示信息
    echo -n "$prompt"  # 输出传入的提示信息，不换行
    read public_key   # 读取用户输入的公钥
    echo "$public_key"  # 输出函数内部读取到的公钥
    echo "$public_key"  # 返回用户输入的公钥
}

# 调用提取公钥的函数，并将结果存储在变量中，传递提示信息作为参数
public_key=$(extract_public_key "")

# 打印提取到的公钥（或者你可以在这里进行其他操作）
echo "$public_key"

# 添加一个结束标志，确认脚本执行完毕
echo "脚本执行完毕"

    #部署Tracks服务#
cd /root/data/airchains/tracks/ && make build 

# 获取本机ip地址
LOCAL_IP=$(hostname -I | awk '{print $1}')
    #注意修改 — daKey和 — moniker，moniker默认为node#
    /root/data/airchains/tracks/build/tracks init --daRpc "https://disperser-holesky.eigenda.xyz" --daKey "$public_key" --daType "eigen" --moniker "$MONIKER" --stationRpc "http://$LOCAL_IP:8545" --stationAPI "http://$LOCAL_IP:8545" --stationType "evm"
    #生成airchains钱包#
    /root/data/airchains/tracks/build/tracks keys junction --accountName node --accountPath /root/.tracks/junction-accounts/keys
    
    /root/data/airchains/tracks/build/tracks prover v1EVM
    
    #修改gas#
    sed -i.bak 's/utilis\.GenerateRandomWithFavour(1200, 2400, \[2\]int{1500, 2000}, 0\.7)/utilis.GenerateRandomWithFavour(2400, 3400, [2]int{2600, 5000}, 0.7)/' /root/data/airchains/tracks/junction/createStation.go
    cd /root/data/airchains/tracks/ && make build
    cat /root/.tracks/junction-accounts/keys/node.wallet.json
    echo "是否领取完成amf？ (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "未完成amf领取，退出脚本。"
    exit 1  # 可以选择退出脚本或者采取其他操作
fi

# 继续执行后续的脚本内容...

    #填入刚创建的钱包名字，以及air开头的钱包地址，本地IP地址，上面获取到的nodeid#
        # 定义路径#
CONFIG_PATH="/root/.tracks/config/sequencer.toml"
WALLET_PATH="/root/.tracks/junction-accounts/keys/node.wallet.json"
#获取nodeid#
    grep node_id ~/.tracks/config/sequencer.toml
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

    #把Tracks加入守护进程并启动#
    cat > /etc/systemd/system/tracksd.service << EOF
[Unit]
Description=tracksd
After=network-online.target

[Service]
User=root
WorkingDirectory=/root/.tracks
ExecStart=/root/data/airchains/tracks/build/tracks start

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

function tracks_log(){
    journalctl -u tracksd -f
}
function private_key(){
    #evmos私钥#
    cd /root/data/airchains/evm-station/ &&  /bin/bash ./scripts/local-keys.sh
    #airchain助记词#
    cat root/.tracks/junction-accounts/keys/node.wallet.json

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
