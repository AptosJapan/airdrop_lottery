#!/bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <lottery_id> <csv_file> [has_header] [batch_size] [profile]"
    echo "  lottery_id: ID of the lottery to register participants for"
    echo "  csv_file: Path to CSV file containing addresses (one per line)"
    echo "  has_header: true/false (default: false)"
    echo "  batch_size: Number of addresses per batch (default: 5)"
    echo "  profile: Aptos CLI profile to use (default: default)"
    exit 1
fi

LOTTERY_ID=$1
CSV_FILE=$2
HAS_HEADER=${3:-false}
BATCH_SIZE=${4:-5}
PROFILE=${5:-default}

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file '$CSV_FILE' not found"
    exit 1
fi

ADDRESSES=()
line_count=0
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -n "$line" ]; then
        if [ "$HAS_HEADER" = "true" ] && [ $line_count -eq 0 ]; then
            line_count=$((line_count + 1))
            continue
        fi
        
        if [[ "$line" =~ ^(0x)?[0-9a-fA-F]+$ ]]; then
            if [[ ! "$line" =~ ^0x ]]; then
                line="0x$line"
            fi
            ADDRESSES+=("$line")
        else
            echo "Warning: Skipping invalid address format: $line"
        fi
    fi
    line_count=$((line_count + 1))
done < "$CSV_FILE"

if [ ${#ADDRESSES[@]} -eq 0 ]; then
    echo "Error: No valid addresses found in CSV file"
    exit 1
fi

CONTRACT_ADDR=$(aptos config show-profiles --profile $PROFILE | grep account | awk '{print $2}' | tr -d ',"')

echo "Registering participants from $CSV_FILE to lottery $LOTTERY_ID..."
echo "Profile: $PROFILE"
echo "Contract address: $CONTRACT_ADDR"
echo "Has header: $HAS_HEADER"
echo "Batch size: $BATCH_SIZE"
echo "Total addresses: ${#ADDRESSES[@]}"

batch_count=0
for ((i=0; i<${#ADDRESSES[@]}; i+=BATCH_SIZE)); do
    batch_count=$((batch_count + 1))
    batch_addresses=()
    
    for ((j=i; j<i+BATCH_SIZE && j<${#ADDRESSES[@]}; j++)); do
        batch_addresses+=("${ADDRESSES[j]}")
    done
    
    address_args=""
    for addr in "${batch_addresses[@]}"; do
        if [ -n "$address_args" ]; then
            address_args="${address_args},address:${addr}"
        else
            address_args="address:${addr}"
        fi
    done
    
    echo "Processing batch $batch_count with ${#batch_addresses[@]} addresses..."
    
    aptos move run \
      --function-id ${CONTRACT_ADDR}::airdrop_lottery::add_participant \
      --args u64:${LOTTERY_ID} "${address_args}" \
      --profile $PROFILE \
      --assume-yes \
      --verbose
    
    if [ $? -eq 0 ]; then
        echo "Batch $batch_count completed successfully"
    else
        echo "Error: Batch $batch_count failed"
        exit 1
    fi
done

echo "Bulk registration completed successfully! Processed ${#ADDRESSES[@]} addresses in $batch_count batches."
