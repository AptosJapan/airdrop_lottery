#!/bin/bash


set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <lottery_id> <csv_file> [has_header] [batch_size]"
    echo "  lottery_id: ID of the lottery to register participants for"
    echo "  csv_file: Path to CSV file containing email,address data"
    echo "  has_header: true/false (default: true)"
    echo "  batch_size: Number of addresses per batch (default: 100)"
    exit 1
fi

LOTTERY_ID=$1
CSV_FILE=$2
HAS_HEADER=${3:-true}
BATCH_SIZE=${4:-100}

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file '$CSV_FILE' not found"
    exit 1
fi

CSV_CONTENT=$(cat "$CSV_FILE" | sed 's/"/\\"/g' | tr '\n' '\\n')

CONTRACT_ADDR=$(aptos config show-profiles --profile default | grep account | awk '{print $2}')

echo "Registering participants from $CSV_FILE to lottery $LOTTERY_ID..."
echo "Contract address: $CONTRACT_ADDR"
echo "Has header: $HAS_HEADER"
echo "Batch size: $BATCH_SIZE"

aptos move run \
  --function-id ${CONTRACT_ADDR}::csv_bulk_registration::register_participants_from_csv \
  --args u64:${LOTTERY_ID} string:"${CSV_CONTENT}" bool:${HAS_HEADER} u64:${BATCH_SIZE} \
  --assume-yes

echo "Bulk registration completed successfully!"
