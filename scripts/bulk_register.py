#!/usr/bin/env python3
"""
CSV Bulk Registration Script for Aptos Airdrop Lottery
Usage: python3 scripts/bulk_register.py <lottery_id> <csv_file> [--header] [--batch-size N] [--profile PROFILE]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

def parse_csv_addresses(csv_file, has_header=False):
    """Parse CSV file and return list of validated addresses"""
    addresses = []
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f):
            line = line.strip()
            if line and not line.isspace():
                if has_header and line_num == 0:
                    continue
                
                if re.match(r'^(0x)?[0-9a-fA-F]+$', line):
                    if not line.startswith('0x'):
                        line = '0x' + line
                    addresses.append(line)
                else:
                    print(f"Warning: Skipping invalid address format: {line}")
    
    return addresses

def get_contract_address(profile='default'):
    """Get the account address from Aptos CLI config for specified profile"""
    try:
        result = subprocess.run(['aptos', 'config', 'show-profiles', '--profile', profile], 
                              capture_output=True, text=True, check=True)
        
        for line in result.stdout.split('\n'):
            if 'account' in line:
                return line.split()[-1].strip('",\'')
        
        raise Exception("Could not find account address in config")
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to get Aptos config: {e}")

def send_batch(contract_addr, lottery_id, addresses, profile, batch_num):
    """Send a batch of addresses to add_participant function"""
    address_args = ','.join([f'address:{addr}' for addr in addresses])
    
    print(f"Processing batch {batch_num} with {len(addresses)} addresses...")
    
    cmd = [
        'aptos', 'move', 'run',
        '--function-id', f'{contract_addr}::airdrop_lottery::add_participant',
        '--args', 
        f'u64:{lottery_id}',
        address_args,
        '--profile', profile,
        '--assume-yes'
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"Batch {batch_num} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error: Batch {batch_num} failed: {e}")
        if e.stderr:
            print(f"Error details: {e.stderr}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Bulk register lottery participants from CSV')
    parser.add_argument('lottery_id', type=int, help='Lottery ID to register participants for')
    parser.add_argument('csv_file', help='Path to CSV file (address format, one per line)')
    parser.add_argument('--header', action='store_true', help='CSV file has header row (default: no header)')
    parser.add_argument('--batch-size', type=int, default=5, help='Batch size for registration (default: 5)')
    parser.add_argument('--profile', default='default', help='Aptos CLI profile to use (default: default)')
    
    args = parser.parse_args()
    
    csv_path = Path(args.csv_file)
    if not csv_path.exists():
        print(f"Error: CSV file '{args.csv_file}' not found")
        sys.exit(1)
    
    try:
        addresses = parse_csv_addresses(args.csv_file, args.header)
        
        if not addresses:
            print("Error: No valid addresses found in CSV file")
            sys.exit(1)
        
        contract_addr = get_contract_address(args.profile)
        
        print(f"Registering participants from {args.csv_file} to lottery {args.lottery_id}...")
        print(f"Profile: {args.profile}")
        print(f"Contract address: {contract_addr}")
        print(f"Has header: {args.header}")
        print(f"Batch size: {args.batch_size}")
        print(f"Total addresses: {len(addresses)}")
        
        batch_count = 0
        failed_batches = 0
        
        for i in range(0, len(addresses), args.batch_size):
            batch_count += 1
            batch_addresses = addresses[i:i + args.batch_size]
            
            success = send_batch(contract_addr, args.lottery_id, batch_addresses, args.profile, batch_count)
            if not success:
                failed_batches += 1
        
        if failed_batches == 0:
            print(f"Bulk registration completed successfully! Processed {len(addresses)} addresses in {batch_count} batches.")
        else:
            print(f"Bulk registration completed with {failed_batches} failed batches out of {batch_count} total batches.")
            sys.exit(1)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
