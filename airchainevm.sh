#!/bin/bash

# 安装所需的软件包
function install_dependencies() {
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
}

# 安装节点
function install_node() {
    git clone https://github.com/airchains-network/evm-station.git
    git clone https://github.com/airchains-network/tracks.git

    cd $HOME/evm-station && go mod tidy

    nano ./scripts/local-setup.sh
    /bin/bash ./scripts/local-setup.sh

    sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml

    read -p "Enter new CHAIN_ID (default: name_1234-1): " CHAIN_ID
    CHAIN_ID=${CHAIN_ID:-name_1234-1}

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

    wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
    sudo chmod +x eigenlayer
    sudo mv eigenlayer /usr/local/bin/eigenlayer

    KEY_FILE="$HOME/.eigenlayer/operator_keys/wallet.ecdsa.key.json"
    if [ -f "$KEY_FILE" ]; then
        echo "文件 $KEY_FILE 已经存在，删除文件"
        rm -f "$KEY_FILE"
        echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet
    else
        echo "文件 $KEY_FILE 不存在，执行创建密钥操作"
        echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet
    fi

    sudo rm -rf ~/.tracks
    cd $HOME/tracks
    go mod tidy

    read -p "请输入Public Key hex: " dakey
    read -p "请输入节点名: " moniker
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    go run cmd/main.go init --daRpc "disperser-holesky.eigenda.xyz" --daKey "$dakey" --daType "eigen" --moniker "$moniker" --stationRpc "http://$LOCAL_IP:8545" --stationAPI "http://$LOCAL_IP:8545" --stationType "evm"

    echo "你需要创建新地址吗？（Y/N/S）"
    echo "Y: 创建新地址"
    echo "N: 导入地址"
    echo "S: 跳过"
    read -r response
    response=$(echo "$response" | tr '[:lower:]' '[:upper:]')

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

    read -p "是否已经领水完毕要继续执行？(yes/no): " choice
    if [[ "$choice" != "yes" ]]; then
        echo "脚本已终止。"
        exit 0
    fi

    echo "继续执行脚本..."
    CONFIG_PATH="$HOME/.tracks/config/sequencer.toml"
    WALLET_PATH="$HOME/.tracks/junction-accounts/keys/wallet.wallet.json"

    if [ -f "$WALLET_PATH" ]; then
        echo "钱包文件存在，从钱包文件中提取地址..."
        AIR_ADDRESS=$(jq -r '.address' "$WALLET_PATH")
    else
        echo "钱包文件不存在，请输入钱包地址："
        read -r AIR_ADDRESS
        echo "你输入的钱包地址是: $AIR_ADDRESS"
    fi

    NODE_ID=$(grep 'node_id =' $CONFIG_PATH | awk -F'"' '{print $2}')
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    create_station_cmd="go run cmd/main.go create-station --accountName wallet --accountPath $HOME/.tracks/junction-accounts/keys --jsonRPC \"https://airchains-rpc.kubenode.xyz/\" --info \"EVM Track\" --tracks \"$AIR_ADDRESS\" --bootstrapNode \"/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID\""

    echo "Running command:"
    echo "$create_station_cmd"
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

function evmos_log() {
    journalctl -u evmosd -f
}

function stationd_log() {
    sudo journalctl -u stationd -f -o cat
}

function private_key() {
    cd $HOME/evm-station/ && /bin/bash ./scripts/local-keys.sh
    cat $HOME/.tracks/junction-accounts/keys/wallet.wallet.json
}

function check_avail_address() {
    journalctl -u availd | head 
}

function restart() {
    sudo systemctl restart evmosd
    sudo systemctl restart stationd
}

function delete_node() {
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

install_dependencies
main_menu
