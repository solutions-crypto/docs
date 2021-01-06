#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin"
PATH=$PATH
DEBUG_ALL=0
DEBUG_MIN=1

NETWORK="guildnet"
GUILDNET_EPOCH_LEN=5000
# BETANET_EPOCH_LEN=10000
#TESTNET=43200
# MAINET=43200
ADD0=000000000000000000000000

export NEAR_ENV=$NETWORK
export NODE_PATH=/home/cryptosolutions/node_modules/

HOST="https://rpc.openshards.io"
POOL_ID="node0.stake.guildnet"
pool_id1='"node0.stake.guildnet"'
ACCOUNT_ID="node0.guildnet"
#PUBLIC_KEY="ed25519:HKGjaHYZ5nU9tV6ZZemHKtri54FxTLipAJDvDmYtDQhA"
SEAT_PRICE_BUFFER=4000
NUM_SEATS_TO_OCCUPY=1

PARAMS='{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}'
CT='Content-Type: application/json'

COMMA=","
DOUBLE_QUOTE="\""


echo "Starting Script"
echo "---------------"
VALIDATORS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}' -H 'Content-Type: application/json' $HOST )
#VALIDATORS=$(curl -s -d "'$PARAMS'" -H "$CT" "$HOST")
if [ "$DEBUG_ALL" == "1" ]
then
  echo "Validators: $VALIDATORS"
fi

STATUS_VAR="/status"
STATUS=$(curl -s "$HOST$STATUS_VAR")
if [ "$DEBUG_ALL" == "1" ]
then
  echo "STATUS: $STATUS"
fi

EPOCH_START=$(echo "$VALIDATORS" | jq .result.epoch_start_height)
if [ "$DEBUG_MIN" == "1" ]
then
  echo "$VALIDATORS" 
  echo "Epoch start: $EPOCH_START"
fi

LAST_BLOCK=$(echo "$STATUS" | jq .sync_info.latest_block_height)
if [ "$DEBUG_MIN" == "1" ]
then
  echo "Last Block: $LAST_BLOCK"
fi

CURRENT_STAKE_S=$(echo "$VALIDATORS" | jq -c '.result.current_validators[] | select(.account_id | contains ('$pool_id1'))' | jq .stake)
CURRENT_STAKE_L=(${CURRENT_STAKE_S//\"/})
CURRENT_STAKE="${CURRENT_STAKE_L%????????????????????????}"


if [[ "$DEBUG_MIN" == "1" && "$CURRENT_STAKE_S" ]]
then
  echo "Current Stake: $CURRENT_STAKE"
  echo "Current Stake: $CURRENT_STAKE_S"
  echo "Current Stake: $CURRENT_STAKE_L"
  else
  echo "$POOL_ID is not listed in the proposals for the current epoch"
fi



VALIDATOR_NEXT_STAKE_S=$(echo "$VALIDATORS" | jq -c ".result.next_validators[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .stake)
VALIDATOR_NEXT_STAKE_L=(${VALIDATOR_NEXT_STAKE_S//\"/})
VALIDATOR_NEXT_STAKE="${VALIDATOR_NEXT_STAKE_L%????????????????????????}"
if [ -z "$VALIDATOR_NEXT_STAKE" ]
then
  echo "$POOL_ID is not listed in the proposals for the next epoch"
fi
if [[ "$DEBUG_MIN" == "1" && "$VALIDATOR_NEXT_STAKE" ]]
then
  echo "Next Stake: $VALIDATOR_NEXT_STAKE"
  echo "Next Stake S: $VALIDATOR_NEXT_STAKE_S"
  echo "Next Stake Long: $VALIDATOR_NEXT_STAKE_L"
fi


KICK_REASON=$(echo "$VALIDATORS" | jq -c ".result.prev_epoch_kickout[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)

OUR_PROPOSAL=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .stake)
PROPOSAL_STAKE_S=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .stake)
PROPOSAL_STAKE=${PROPOSAL_STAKE_S//\"/}
PROPOSAL_STAKE="${PROPOSAL_STAKE_S%?????????????????????????}"
if [[ -z "$OUR_PROPOSAL" ]]
then
echo "We dont have a proposal sending a ping"
PING_COMMAND=$(near call $POOL_ID ping "{}" --accountId $ACCOUNT_ID)
echo "$PING_COMMAND"
exit
else
OUR_PROPOSAL_S=$(echo $OUR_PROPOSAL | sed 's/[^0-9]*//g')
PROPOSAL_STAKE=$(echo $PROPOSAL_STAKE | sed 's/[^0-9]*//g')
echo "Our Proposal: $OUR_PROPOSAL"
echo "Our Proposal_S: $OUR_PROPOSAL_S"
echo "Our Proposal Stake: $PROPOSAL_STAKE"
#OUR_PROPOSAL=$(near proposals | awk "/$POOL_ID/ {print substr("$6", 1)}")
#OUR_PROPOSAL="${OUR_PROPOSAL/$COMMA/}"
#echo $VALIDATORS | jq -c ".result.current_proposals[]"
PROPOSAL_REASON=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)
echo "Proposal Reason: $PROPOSAL_REASON"
fi


# Change
# If the validators stake is null in all 3 of these lists proposals, current, and next   then execute function to send proposal
# If stake is not null check if current proposal is rollover?
# if yes then ping 
# FIX IT 

if [[ "$KICK_REASON" ]]
then
    echo Validator Kicked Reason = "$KICK_REASON"
fi

CURRENT_SEAT_PRICE=$(near validators current | awk '/price/ {print substr($6, 1, length($6)-2)}')
CURRENT_SEAT_PRICE="${CURRENT_SEAT_PRICE/$COMMA/}"
CURRENT_SEAT_PRICE=$((CURRENT_SEAT_PRICE+SEAT_PRICE_BUFFER))
if [ "$DEBUG_MIN" == "1" ]
then
  echo "Current Epoch Seat Price: $CURRENT_SEAT_PRICE"
fi

SEAT_PRICE_NEXT=$(near validators next | awk '/price/ {print substr($7, 1, length($7)-2)}')
SEAT_PRICE_NEXT="${SEAT_PRICE_NEXT/$COMMA/}"
SEAT_PRICE_NEXT=$((SEAT_PRICE_NEXT * NUM_SEATS_TO_OCCUPY))
if [ "$DEBUG_MIN" == "1" ]
then
  echo "Next Epoch Seat Price: $SEAT_PRICE_NEXT"
fi

SEAT_PRICE_PROPOSALS=$(near proposals | awk '/price =/ {print substr($15, 1, length($15)-1)}')
SEAT_PRICE_PROPOSALS="${SEAT_PRICE_PROPOSALS/$COMMA/}"
SEAT_PRICE_PROPOSALS=$((SEAT_PRICE_PROPOSALS * NUM_SEATS_TO_OCCUPY))

if [ "$DEBUG_MIN" == "1" ]
then
  echo "Seat Price Proposals: $SEAT_PRICE_PROPOSALS"
fi

function stake
{
  near call $POOL_ID stake '{"amount": '"$1"'}' --accountId $ACCOUNT_ID
}

function unstake
{
  near call $POOL_ID unstake '{"amount": '"$1"'}' --accountId $ACCOUNT_ID
}


if [[ "$PROPOSAL_STAKE" -le "$SEAT_PRICE_PROPOSALS" ]]
then
    echo "$PROPOSAL_STAKE is less than $SEAT_PRICE_PROPOSALS"

    echo "Network Proposal Seat Price = $SEAT_PRICE_PROPOSALS"
    echo "Validator Current Proposal = $PROPOSAL_STAKE" 
    echo "Seat Price Buffer = $SEAT_PRICE_BUFFER"
    SEAT_PRICE_DIFF=$((SEAT_PRICE_PROPOSALS - PROPOSAL_STAKE ))
    SEAT_PRICE_DIFF=$((SEAT_PRICE_DIFF + SEAT_PRICE_BUFFER))
    SEAT_PRICE_DIFF=$(echo \"$SEAT_PRICE_DIFF$ADD0\")
    
    stake $SEAT_PRICE_DIFF
    echo Stake increased by "$SEAT_PRICE_DIFF"
fi

# OPTION 2
ADJUST=$((SEAT_PRICE_PROPOSALS + SEAT_PRICE_BUFFER))
echo $ADJUST is the seat price plus buffer
if [[ "$PROPOSAL_STAKE" -gt "$ADJUST" ]]
then
    echo "$PROPOSAL_STAKE is greater than $ADJUST" 
    echo "Network Proposal Seat Price = $ADJUST"
    echo "Validator Current Proposal = $PROPOSAL_STAKE" 
    echo "Seat Price Buffer = $SEAT_PRICE_BUFFER"

    SEAT_PRICE_DIFF=$((PROPOSAL_STAKE - ADJUST))
    echo "Stake Diff: $SEAT_PRICE_DIFF"
    NEW_PROPOSAL_NUMBERS=$(echo $SEAT_PRICE_DIFF | sed 's/[^0-9]*//g')
    NEW_PROPOSAL_NUMBERS=$((SEAT_PRICE_DIFF + SEAT_PRICE_BUFFER))
    AMOUNT=\"$NEW_PROPOSAL_NUMBERS$ADD0\"

    if [ "$AMOUNT" -gt 10000 ]
    then
    echo "Decreasing stake by: ${AMOUNT}"
    unstake "$AMOUNT"
    fi
fi


echo "Script Done"
echo "----------- "
echo " "

