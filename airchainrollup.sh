
function install_node() {
    mkdir -p /data/airchains/ && cd /data/airchains/
    
    it clone https://github.com/airchains-network/evm-station.git
    
    git clone https://github.com/airchains-network/tracks.git
    #设置并运行EVM-Station#
    cd /data/airchains/evm-station  && go mod tidy
    #自定义CHAINID和MONIKER,默认填写了node，不知道可不可以用同一个名字#
    sed -i.bak 's@CHAINID="{CHAIN_ID:-testname_1234-1}"@CHAINID="{CHAIN_ID:-node_1234-1}"@' ~./scripts/local-setup.sh
    sed -i.bak 's@MONIKER="TESTNAME"@MONIKER="node"@' ~./scripts/local-setup.sh
    #把json-rpc监听地址改为0.0.0.0#
    sed -i.bak 's@address = "127.0.0.1:8545"@address = "0.0.0.0:8545"@' ~/.evmosd/config/app.toml
    #修改 — chain-id 为 上一步自定义的CHAINID，默认填写了node，保留1234-1#
    /bin/bash ./scripts/local-setup.sh
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

# 检查是否提取到公钥
if [ -n "$public_key" ]; then
    echo "Public key found: $public_key"
else
    echo "Error: Could not find public key in availd logs"
    exit 1
fi
    #注意修改 — daKey和 — moniker，moniker默认为node#
    /data/airchains/tracks/build/tracks   init --daRpc "http://127.0.0.1:7000" --daKey "$public_key" --daType "avail" --moniker "node" --stationRpc "http://127.0.0.1:8545" --stationAPI "http://127.0.0.1:8545" --stationType "evm"
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
/data/airchains/tracks/build/tracks create-station --accountName node --accountPath $HOME/.tracks/junction-accounts/keys --jsonRPC "$JSON_RPC" --info "$INFO" --tracks "$AIR_ADDRESS" --bootstrapNode "$BOOTSTRAP_NODE"

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
    #查看助记词#
    #evmosd#
    /bin/bash ./scripts/local-setup.sh
    /bin/bash ./scripts/local-keys.sh
    #avail#
    cat /root/.avail/identity/identity.toml
    #airchian#
    cat $HOME/.tracks/junction-accounts/keys node.wallet.json
}



#自动转账脚本#
function transfer() {
    pip install web3

    cat <<EOF > create_transfer_script.py
import os
import subprocess

def generate_transfer_script():
    # 设置文件路径
    keyring_test_dir = os.path.expanduser("~/.evmosd/keyring-test")

    # 获取 .address 文件名
    address_files = [f for f in os.listdir(keyring_test_dir) if f.endswith('.address')]

    # 确保有 .address 文件
    if not address_files:
        raise FileNotFoundError("No .address files found in the keyring-test directory")

    # 取第一个 .address 文件作为示例
    address_filename = address_files[0]
    address_path = os.path.join(keyring_test_dir, address_filename)

    # 读取地址文件内容
    with open(address_path, "r") as f:
        sender_address = f.read().strip()

    # 处理文件名得到接收者地址（去掉 .address 后缀并加上 0x 前缀）
    receiver_address = "0x" + address_filename.replace(".address", "")

    # 运行 local-keys.sh 脚本获取私钥
    result = subprocess.run(["/bin/bash", "./scripts/local-keys.sh"], capture_output=True, text=True)

    # 检查脚本是否成功运行
    if result.returncode != 0:
        print("Error running local-keys.sh script")
        print(result.stderr)
        return None, None, None

    # 假设私钥在脚本输出的某一行中
    sender_private_key = result.stdout.strip().split()[-1]

    # 返回必要的信息
    return sender_address, sender_private_key, receiver_address

def create_transfer_file(sender_address, sender_private_key, receiver_address, filename="transfer.py"):
    # 自定义配置
    rpc_url = "http://127.0.0.1:8545"  # 自定义的 RPC URL
    chain_id = 1234  # 自定义的链 ID
    amount = 1000000  # 转账金额（示例为 1个币）

    # 定义要写入 transfer.py 文件的内容
    file_content = f"""
from web3 import Web3
import time

# 自定义配置
rpc_url = "{rpc_url}"  # 自定义的 RPC URL
chain_id = {chain_id}  # 自定义的链 ID

# 钱包地址和私钥
sender_address = "{sender_address}"  # 发送者钱包地址
sender_private_key = "{sender_private_key}"  # 发送者钱包的私钥

# 接收者钱包地址和转账金额（以最小单位表示）
receiver_address = "{receiver_address}"  # 接收者钱包地址
amount = {amount}  # 转账金额（示例为 1个币）

def main():
    while True:
        try:
            # 创建 Web3 实例
            web3 = Web3(Web3.HTTPProvider(rpc_url))

            # 检查是否成功连接到节点
            if web3.isConnected():
                print("成功连接到以太坊节点")
            else:
                print("无法连接到以太坊节点")
                exit(1)

            # 构建交易对象
            transaction = {{
                "to": receiver_address,
                "value": amount,
                "gas": 21000,  # 设置默认的 gas 数量
                "gasPrice": web3.toWei(50, "gwei"),  # 设置默认的 gas 价格
                "nonce": web3.eth.getTransactionCount(sender_address),
                "chainId": chain_id,
            }}

            # 签名交易
            signed_txn = web3.eth.account.signTransaction(transaction, sender_private_key)

            # 发送交易
            tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)

            # 等待交易确认
            tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)

            # 输出交易结果
            print("Transaction Hash:", tx_receipt.transactionHash.hex())
            print("Gas Used:", tx_receipt.gasUsed)
            print("Status:", tx_receipt.status)

            # 等待一段时间后再发送下一笔交易
            print("等待10秒钟...")
            time.sleep(10)

        except Exception as e:
            print("发生异常:", e)
            print("等待10秒钟后继续...")
            time.sleep(10)
            continue

if __name__ == "__main__":
    main()
"""

    # 创建并写入 transfer.py 文件
    with open(filename, "w") as file:
        file.write(file_content)

    print(f"{filename} 文件已创建并写入内容。")

if __name__ == "__main__":
    sender_address, sender_private_key, receiver_address = generate_transfer_script()
    if sender_address and sender_private_key and receiver_address:
        create_transfer_file(sender_address, sender_private_key, receiver_address)
    else:
        print("无法生成交易脚本。请检查配置。")
EOF
        
python create_transfer_script.py
screen -S transfer_session -dm python3 transfer.py



}


function transfer_log(){
    screen -r transfer_session
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
    /bin/bash ./scripts/local-keys.sh
    #avail助记词#
    cat /root/.avail/identity/identity.toml
    #airchain助记词#
    cat $HOME/.tracks/junction-accounts/keys/node.wallet.json

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
        echo "2. 安装自动转账脚本"
        echo "3. 查看转账脚本是否正常运行（按CTRL+AD退出）"
        echo "4. 查看evmos状态"
        echo "5. 查看avail状态"
        echo "6. 查看tracks状态"
        echo "7. 导出所有私钥"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) transfer ;;
        3) transfer_log ;;
        4) evmos_log ;;
        5) avail_log ;;
        6) tracks_log ;;
        7) private_key ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
    
}

# 显示主菜单
main_menu
