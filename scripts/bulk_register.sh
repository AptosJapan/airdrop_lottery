#!/bin/bash


set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <lottery_id> <csv_file> [has_header] [batch_size] [profile]"
    echo "  lottery_id: ID of the lottery to register participants for"
    echo "  csv_file: Path to CSV file containing addresses (one per line)"
    echo "  has_header: true/false (default: false)"
    echo "  batch_size: Number of addresses per batch (default: 100)"
    echo "  profile: Aptos CLI profile to use (default: default)"
    exit 1
fi

LOTTERY_ID=$1
CSV_FILE=$2
HAS_HEADER=${3:-false}
BATCH_SIZE=${4:-100}
PROFILE=${5:-default}

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file '$CSV_FILE' not found"
    exit 1
fi

CSV_CONTENT=$(cat "$CSV_FILE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

CONTRACT_ADDR=$(aptos config show-profiles --profile $PROFILE | grep account | awk '{print $2}' | tr -d ',"')

echo "Registering participants from $CSV_FILE to lottery $LOTTERY_ID..."
echo "Profile: $PROFILE"
echo "Contract address: $CONTRACT_ADDR"
echo "Has header: $HAS_HEADER"
echo "Batch size: $BATCH_SIZE"

aptos move run \
  --function-id ${CONTRACT_ADDR}::csv_bulk_registration::register_participants_from_csv \
  --args u64:${LOTTERY_ID} string:"${CSV_CONTENT}" bool:${HAS_HEADER} u64:${BATCH_SIZE} \
  --profile $PROFILE \
  --assume-yes

echo "Bulk registration completed successfully!"
