# 基于 fisco bcos 的供应链金融

## 1 运行本程序之前的准备工作

请根据 `fisco bcos` 官方的教程完成私有链的搭建：

[搭建第一个区块链网络](https://fisco-bcos-doc.readthedocs.io/zh_CN/latest/docs/quick_start/air_installation.html)

## 2 配置证书

```bash
# 假设我们将asset-app-3.0放在~/fisco目录下 进入~/fisco目录
$ cd ~/fisco
# 创建放置证书的文件夹
$ mkdir -p asset-app-3.0/src/test/resources
# 拷贝节点证书到项目的资源目录
$ cp -r nodes/127.0.0.1/sdk/* asset-app-3.0/src/test/resources
# 若在IDE直接运行，拷贝证书到resources路径
$ mkdir -p asset-app-3.0/src/main/resources
$ cp -r nodes/127.0.0.1/sdk/* asset-app-3.0/src/main/resources
```

## 3 运行程序

```bash
# 切换到项目目录
$ cd ~/fisco/asset-app-3.0
# 编译项目
$ ./gradlew build

# 进入到脚本目录
cd dist
# 部署到私有链上
bash finance_run.sh deploy

# 查看使用帮助
bash finance_run.sh
```

# 4 智能合约

智能合约的位置在 `src/main/resources/contract/SupplyChain.Finance.sol`

# 5 运行结果

运行结果请看 `report` 目录下的 md 文件

---

