docker run -d --name airchains ubuntu:20.04 sleep infinity
docker exec -it airchains bash -c "
wget -O airchainrollup.sh https://raw.githubusercontent.com/candy1264/airchains/main/airchainrollup.sh && chmod +x airchainrollup.sh && ./airchainrollup.sh
"
