#!/usr/bin/env bash

CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer0.ord1.example.com/msp/tlscacerts/tlsca.ord1.example.com-cert.pem

CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "$LANGUAGE" = "node" ]; then
	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi

echo "Channel name : "$CHANNEL_NAME

# import utils
. scripts/utils.sh


checkOSNAvailability() {
	#Use orderer's MSP for fetching system channel config block
	setOrdererGlobalsXXX 1

	local rc=1
	local starttime=$(date +%s)

	# continue to poll
	# we either get a successful response, or reach TIMEOUT
	while test "$(($(date +%s)-starttime))" -lt "30" -a $rc -ne 0
	do
		 sleep 3
		 echo "Attempting to fetch system channel 'cbc' ...$(($(date +%s)-starttime)) secs"
		 if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			 peer channel fetch 0 cbc.block -o orderer0.ord1.example.com:7050 -c "cbc" >&log.txt
		 else
			 peer channel fetch 0 cbc.block -o orderer0.ord1.example.com:7050 -c "cbc" --tls --cafile $ORDERER_CA >&log.txt
		 fi
		 test $? -eq 0 && VALUE=$(ls | grep cbc.block | wc -l)
		 test "$VALUE" = "1" && let rc=0
	done
	cat log.txt
	verifyResult $rc "Ordering Service is not available, Please try again ..."
	echo "===================== Ordering Service is up and running ===================== "
	echo
	cp cbc.block channel-artifacts
}

checkmychannelAvailability() {
	#Use orderer's MSP for fetching system channel config block
	setOrdererGlobalsXXX 1

	local rc=1
	local starttime=$(date +%s)

	# continue to poll
	# we either get a successful response, or reach TIMEOUT
	while test "$(($(date +%s)-starttime))" -lt "30" -a $rc -ne 0
	do
		 sleep 3
		 echo "Attempting to fetch system channel 'cbc' ...$(($(date +%s)-starttime)) secs"
		 if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			 peer channel fetch 0 mychannel.block -o orderer0.ord1.example.com:7050 -c "mychannel" >&log.txt
		 else
			 peer channel fetch 0 mychannel.block -o orderer0.ord1.example.com:7050 -c "mychannel" --tls --cafile $ORDERER_CA >&log.txt
		 fi
		 test $? -eq 0 && VALUE=$(ls | grep cbc.block | wc -l)
		 test "$VALUE" = "1" && let rc=0
	done
	cat log.txt
	verifyResult $rc "Ordering Service is not available, Please try again ..."
	echo "===================== Ordering Service is up and running ===================== "
	echo
	cp mychannel.block channel-artifacts
}

createChannel() {
	setGlobals 0 1

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer0.ord1.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer0.ord1.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

#createChannel
#sleep 3
checkOSNAvailability
sleep 3
checkmychannelAvailability

