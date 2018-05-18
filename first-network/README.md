## BYFN脚本说明

* byfn.sh： 启动一个带kafka集群的测试网络，两个peer组织org1和org2，两个orderer组织，orderer1和orderer2，然后跑一边e2e_cli的示例
* eyfn.sh: 在byfn网络的基础上首先会生成Org3的证书和config.json，包括peer组织的org3和Orderer组织的Orderer3，然后构建config_update交易并进行签名（详细见下方说明），发送给orderer进行升级，启动org3的节点，1个Orderer和2个peer并做升级cc以及test交易；然后再在此基础上生成org4的证书和config，并进行签名和升级，此目的主要是为了测试不用策略的配置下添加新组织的签名权限。



## 测试步骤

### fabric 分支说明

```
  feature/v1.1.0-AdminGenesisPolicy
  feature/v1.1.0-AnyGenesisPolicy
  feature/v1.1.0-CustomGenesisPolicy
```

目前3个分支：

* admin分支采用的是默认策略，即添加新组织需要N/2+1个签名，N为当前配置块中的相应组织个数(有peer组织和orderer组织的区分)，例如当前2个peer org（org1和org2）和2个orderer org(ord1和ord2)，当只需要添加1个peer org(org3)时，需要org1和org2的两个签名，如果需要添加1个peer org和1个orderer org时，需要org1,org2,ord1,ord2一共四个签名
* any分支采用的任意一个组织签名的策略，即添加新组织时，只需要任意一个原来组织的签名就行，例如添加org3时，只需要org1或者org2的签名就行；添加ord3时，只需要ord1和ord2的签名就行
* cutom分支采用的是自定义策略，此策略在操作时需要创世组织的签名，例如创世组织有org1和org2，新添加了1个组织org3，当需要添加org4时，必须用org1或者org2的签名，而不能使用org3的签名

这3个分支主要修改的代码是configtxgen工具的代码，其中admin的代码为原始代码，即如果需要测试时，将分支切换以后，需要在fabric目录下执行`make release`操作，重新生成configtxgen工具

### 脚本使用

前提为所有1.1.0镜像都已经编译好

首先执行`which configtxgen`命令，确保configtxgen工具指向的是你刚编译出来的路径，如果找不到工具，请根据实际情况修改`PATH`环境变量

在`first-network`目录下，直接执行`./byfn.sh up && ./eyfn.sh up`，脚本会依次启动网络并添加组织

当脚本结束时，执行`./eyfn.sh down`清理环境

### 调试策略

当需要调试时，可以采取以下几种方式：

1. 根据实际情况注释掉`scripts/script.sh`中createchannel后面的函数，即不跑cc相关的业务逻辑，这样可以更针对性的测试

2. 同样也可以注释掉`eyfn.sh`中的`networkUp`函数中的相关代码，可以针对性的测试添加org4的业务逻辑

3. 添加org3的主要操作在`scripts/step1org3.sh`中，其中一些关键代码如下：

   ```
   # Modify the configuration to append the new org
   set -x
   jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' config.json ./channel-artifacts/org3.json > config1.json
   set +x
   
   # Modify the configuration to append the new orderer org
   set -x
   jq -s '.[0] * {"channel_group":{"groups":{"Orderer":{"groups": {"Orderer3MSP":.[1]}}}}}' config1.json ./channel-artifacts/ord3.json > config2.json
   set +x
   
   # Add the new orderer address
   set -x
   jq '.channel_group.values.OrdererAddresses.value.addresses=[.channel_group.values.OrdererAddresses.value.addresses[],"orderer0.ord3.example.com:7050"]' config2.json > modified_config.json
   set +x
   ```

   以上为添加组织3的相关信息，证书ip等

   ```
   # By default, 
   # ADMIN Policy needs N/2+1 signatures by orgs
   # ANY Policy needs 1 signature by any org
   # CUSTOM Policy needs 1 signature by only one of genesis org
   
   signConfigtxAsPeerOrg 1 org3_update_in_envelope.pb
   #signConfigtxAsOrdererOrg 1 org3_update_in_envelope.pb
   signConfigtxAsOrdererOrg 2 org3_update_in_envelope.pb
   echo
   echo "========= Submitting transaction from a different peer (peer0.org2) which also signs it ========= "
   echo
   setGlobals 0 2
   peer channel update -f org3_update_in_envelope.pb -c ${CHANNEL_NAME} -o orderer0.ord1.example.com:7050 --tls --cafile ${ORDERER_CA}
   ```

   以上为对`org3_update_in_envelope.pb`的签名，其中`signConfigtxAsPeerOrg 1 org3_update_in_envelope.pb`表示用org1的证书签名交易，`signConfigtxAsOrdererOrg 2 org3_update_in_envelope.pb`表示用ordererOrg2的证书签名交易，最后在执行`peer update`命令时，默认也带了一个签名(通过`setGlobals 0 2`选择)，所以可以通过修改此处的签名组织和个数来校验添加新组织的策略

   *step1Org4.sh中也是类似*

   *step1Org3.sh中默认会执行`apt-get -y update && apt-get -y install jq`，如果不想每次测试都安装jq，可以编写Dockerfile将jq装上`hyperledger/fabric-tools`中*

   ### 其他说明

   脚本中有很多有用的地方可以学习参考，比如判断orderer服务是否启动

   ```
   peer channel fetch 0 0_block.pb -o orderer0.ord1.example.com:7050 -c "testchainid" --tls --cafile $ORDERER_CA
   ```

   单独生成组织3的证书和配置

   ```
   cryptogen generate --config=./org4-crypto.yaml
   configtxgen -printOrg Org3MSP > ../channel-artifacts/org3.json
   configtxgen -printOrg Orderer3MSP > ../channel-artifacts/ord3.json
   ```

   通过configtxlator构建update交易（不启动http服务）

   ```
     configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > original_config.pb
     configtxlator proto_encode --input "${MODIFIED}" --type common.Config > modified_config.pb
     configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb > config_update.pb
     configtxlator proto_decode --input config_update.pb  --type common.ConfigUpdate > config_update.json
     echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
     configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope > "${OUTPUT}"
   ```

   等等



