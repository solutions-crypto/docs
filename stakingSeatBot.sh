#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin"
PATH=$PATH
DEBUG_ALL=0
DEBUG_MIN=0

# SETTINGS
NETWORK="???"
POOL_ID="???"
ACCOUNT_ID="???"
NUM_SEATS_TO_OCCUPY=???

# Epoch Lengths
GUILDNET_EPOCH_LEN=5000
BETANET_EPOCH_LEN=10000
TESTNET_EPOCH_LEN=43200
MAINET_EPOCH_LEN=43200

# Additional Script Configuration
ADD0=000000000000000000000000
SEAT_PRICE_BUFFER=10000
COMMA=","
#DOUBLE_QUOTE="\""


# Export the network to the environment
export NEAR_ENV=$NETWORK

# Select the correct RPC server for the network
case $NETWORK in

  guildnet)
    HOST="https://rpc.openshards.io"
    ;;

  mainnet)
    HOST="https://rpc.near.org"
    ;;

  testnet)
    HOST="https://rpc.testnet.near.org/"
    ;;

  betanet)
    HOST="https://rpc.betanet.near.org/"
    ;;

  *)
    ;;
esac

echo "Starting Script"
echo "---------------"

# Ensure user has configured the script
if [ "$POOL_ID" == "???" ]
then
echo "You have not properly configured this script. Please edit the file and replace every instance of ??? with valid data"
fi

PUBLIC_KEY="near view $POOL_ID get_staking_key '{}' | tail -n 1"
if [ "$DEBUG_ALL" == "1" ]
echo "The public key retrieved from the network for $POOL_ID is: $PUBLIC_KEY"
fi

VALIDATORS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}' -H 'Content-Type: application/json' $HOST )
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
  echo "Epoch start: $EPOCH_START"
fi

LAST_BLOCK=$(echo "$STATUS" | jq .sync_info.latest_block_height)
if [ "$DEBUG_MIN" == "1" ]
then
  echo "Last Block: $LAST_BLOCK"
fi

# Calculate blocks and time remaining in epoch based on the network selected
BLOCKS_COMPLETED=$((LAST_BLOCK - EPOCH_START))

case $NETWORK in

  guildnet)
    BLOCKS_REMAINING=$((BLOCKS_COMPLETED - GUILDNET_EPOCH_LEN))
    EPOCH_MINS_REMAINING=$((BLOCKS_REMAINING / 60))
    ;;

  mainnet)
    BLOCKS_REMAINING=$((BLOCKS_COMPLETED - MAINET_EPOCH_LEN))
    EPOCH_MINS_REMAINING=$((BLOCKS_REMAINING / 60))
    ;;

  testnet)
    BLOCKS_REMAINING=$((BLOCKS_COMPLETED - TESTNET_EPOCH_LEN))
    EPOCH_MINS_REMAINING=$((BLOCKS_REMAINING / 60))
    ;;

  betanet)
    BLOCKS_REMAINING=$((BLOCKS_COMPLETED - BETANET_EPOCH_LEN))
    EPOCH_MINS_REMAINING=$((BLOCKS_REMAINING / 60))
    ;;

  *)
    ;;
esac

if [ "$DEBUG_MIN" == "1" ]
then
echo "Blocks Completed: $BLOCKS_COMPLETED"
echo "Blocks Remaining: $BLOCKS_REMAINING"
echo "Epoch Minutes Remaining: $EPOCH_MINS_REMAINING"
fi

CURRENT_STAKE_S=$(echo "$VALIDATORS" | jq -c ".result.current_validators[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .stake)
CURRENT_STAKE_L=(${CURRENT_STAKE_S//\"/})
CURRENT_STAKE="${CURRENT_STAKE_L%????????????????????????}"

if [[ "$DEBUG_MIN" == "1" && -z "$CURRENT_STAKE_S" ]]
then
  echo "$POOL_ID is not listed in the proposals for the current epoch"
fi

if [[ "$DEBUG_MIN" == "1" && "$CURRENT_STAKE_S" ]]
then
  echo "Current Stake: $CURRENT_STAKE"
  echo "Current Stake_S: $CURRENT_STAKE_S"
  echo "Current Stake_L: $CURRENT_STAKE_L"
fi

VALIDATOR_NEXT_STAKE_S=$(echo "$VALIDATORS" | jq -c ".result.next_validators[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .stake)
VALIDATOR_NEXT_STAKE_L=(${VALIDATOR_NEXT_STAKE_S//\"/})
VALIDATOR_NEXT_STAKE="${VALIDATOR_NEXT_STAKE_L%????????????????????????}"

if [[ "$DEBUG_MIN" == "1" && -z "$VALIDATOR_NEXT_STAKE" ]]
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
if [[ "$KICK_REASON" && "$DEBUG_MIN" == "1" ]]
then
    echo "Validator Kicked Reason = $KICK_REASON"
    PING_COMMAND=$(near call $POOL_ID ping "{}" --accountId $ACCOUNT_ID)
    echo "$PING_COMMAND"
    exit
fi
if [[ "$KICK_REASON" && "$DEBUG_MIN" == "0" ]]
then
    echo "Validator was Kicked Pinging"
    echo "$PING_COMMAND"
    exit
fi

# Proposal for epoch +2
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
fi

OUR_PROPOSAL_S=$(echo $OUR_PROPOSAL | sed 's/[^0-9]*//g')
PROPOSAL_STAKE=$(echo $PROPOSAL_STAKE | sed 's/[^0-9]*//g')
if [[ "$PROPOSAL_STAKE" && "$DEBUG_MIN" == "1" ]]
then
echo "Our Proposal: $OUR_PROPOSAL"
echo "Our Proposal_S: $OUR_PROPOSAL_S"
echo "Proposal Stake: $PROPOSAL_STAKE"
fi

if [ "$DEBUG_ALL" == "1" ]
then
echo $VALIDATORS | jq -c ".result.current_proposals[]"
fi

PROPOSAL_REASON=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)
if [[ "$PROPOSAL_REASON" && "$DEBUG_MIN" == "1" ]]
then
echo Proposal Reason: "$PROPOSAL_REASON"
fi

# Current Epoch Seat Price
CURRENT_SEAT_PRICE=$(near validators current | awk '/price/ {print substr($6, 1, length($6)-2)}')
CURRENT_SEAT_PRICE="${CURRENT_SEAT_PRICE/$COMMA/}"
CURRENT_SEAT_PRICE=$((CURRENT_SEAT_PRICE+SEAT_PRICE_BUFFER))
if [[ "$DEBUG_MIN" == "1" && "$CURRENT_SEAT_PRICE" ]]
then
  echo "Current Epoch Seat Price: $CURRENT_SEAT_PRICE"
fi

# Next Epoch Seat Price
SEAT_PRICE_NEXT=$(near validators next | awk '/price/ {print substr($7, 1, length($7)-2)}')
SEAT_PRICE_NEXT="${SEAT_PRICE_NEXT/$COMMA/}"
SEAT_PRICE_NEXT=$((SEAT_PRICE_NEXT * NUM_SEATS_TO_OCCUPY))
if [ "$DEBUG_MIN" == "1" ]
then
  echo "Next Epoch Seat Price: $SEAT_PRICE_NEXT"
fi

SEAT_PRICE_PROPOSALS=$(near proposals | awk '/price =/ {print substr($15, 1, length($15)-1)}')
SEAT_PRICE_PROPOSALS="${SEAT_PRICE_PROPOSALS/$COMMA/}"
SEAT_PRICE_PROPOSALS=$((SEAT_PRICE_PROPOSALS + SEAT_PRICE_BUFFER))
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


if [[ "$PROPOSAL_STAKE" -lt "$SEAT_PRICE_PROPOSALS" ]]
then
    echo "$PROPOSAL_STAKE is less than $SEAT_PRICE_PROPOSALS"

    echo "Network Proposal Seat Price = $SEAT_PRICE_PROPOSALS"
    echo "Validator Current Proposal = $PROPOSAL_STAKE" 
    echo "Seat Price Buffer = $SEAT_PRICE_BUFFER"
    SEAT_PRICE_DIFF=$((SEAT_PRICE_PROPOSALS - PROPOSAL_STAKE ))
    # If the difference between $SEAT_PRICE_PROPOSALS + $SEAT_PRICE_BUFFER - $PROPOSAL_STAKE is greater than 4500 increase stake by difference
    # Since the buffer is greater than 10k this should not cause a problem 
    # The price buffer is added to the Network Proposal Price before calculation so even if we are 4k under the price we are still 5k over the minimum
    if [ $SEAT_PRICE_DIFF -gt 4500 ]
    then
    # TODO Check to ensure accountId has enough balance to perform action or we will get this sometimes
    # Failure [blah.stake.guildnet]: Error: Smart contract panicked: panicked at &#39;Not enough unstaked balance to stake&#39;, src&#x2F;internal.rs:92:9
    SEAT_PRICE_DIFF=$(echo \"$SEAT_PRICE_DIFF$ADD0\")
    stake $SEAT_PRICE_DIFF
    echo Stake increased by "$SEAT_PRICE_DIFF"
    else
    echo "The seat price difference of: $SEAT_PRICE_DIFF is not sufficent to trigger a transaction"
    fi
fi


# OPTION 2

if [[ "$PROPOSAL_STAKE" -gt "$SEAT_PRICE_PROPOSALS" ]]
then
    echo "$PROPOSAL_STAKE is greater than $SEAT_PRICE_PROPOSALS" 
    echo "Network Proposal Seat Price = $SEAT_PRICE_PROPOSALS"
    echo "Validator Current Proposal = $PROPOSAL_STAKE" 
    echo "Seat Price Buffer = $SEAT_PRICE_BUFFER"

    SEAT_PRICE_DIFF=$((PROPOSAL_STAKE - SEAT_PRICE_PROPOSALS))
    echo "Stake Diff: $SEAT_PRICE_DIFF"
    NEW_PROPOSAL_NUMBERS=$(echo $SEAT_PRICE_DIFF | sed 's/[^0-9]*//g')
    NEW_PROPOSAL_NUMBERS=$((SEAT_PRICE_DIFF + SEAT_PRICE_BUFFER))
    if [[ "$NEW_PROPOSAL_NUMBERS" -gt 10000 ]]
    then
      AMOUNT=\"$NEW_PROPOSAL_NUMBERS$ADD0\"
      echo "Decreasing stake by: ${AMOUNT}"
      unstake "$AMOUNT"
    else
    echo "The seat price difference of: $NEW_PROPOSAL_NUMBERS is not sufficent to trigger a transaction"
    fi
fi

if [[ "$PROPOSAL_STAKE" = "$SEAT_PRICE_PROPOSALS" ]]
then
echo "The proposal stake and seat price are equal no action will be taken"
fi

echo "Script Done"
echo "----------- "
echo " "
