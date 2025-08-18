#!/usr/bin/env python3
"""
CSV Bulk Registration Script for Aptos Airdrop Lottery
Usage: python3 scripts/bulk_register.py <lottery_id> <csv_file> [--no-header] [--batch-size N]
"""

import argparse
import csv
import subprocess
import sys
import json
from pathlib import Path

def read_csv_content(csv_file, has_header=True):
    """Read CSV file and return as string format expected by Move script"""
    lines = []
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f):
            line = line.strip()
            if line:  # Skip empty lines
                if has_header and line_num == 0:
                    continue  # Skip header line
                lines.append(line)
    
    return '\n'.join(lines)

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

def main():
    parser = argparse.ArgumentParser(description='Bulk register lottery participants from CSV')
    parser.add_argument('lottery_id', type=int, help='Lottery ID to register participants for')
    parser.add_argument('csv_file', help='Path to CSV file (address format, one per line)')
    parser.add_argument('--header', action='store_true', help='CSV file has header row (default: no header)')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size for registration (default: 100)')
    parser.add_argument('--profile', default='default', help='Aptos CLI profile to use (default: default)')
    
    args = parser.parse_args()
    
    csv_path = Path(args.csv_file)
    if not csv_path.exists():
        print(f"Error: CSV file '{args.csv_file}' not found")
        sys.exit(1)
    
    try:
        has_header = args.header
        csv_content = read_csv_content(args.csv_file, has_header)
        
        contract_addr = get_contract_address(args.profile)
        
        print(f"Registering participants from {args.csv_file} to lottery {args.lottery_id}...")
        print(f"Profile: {args.profile}")
        print(f"Contract address: {contract_addr}")
        print(f"Has header: {has_header}")
        print(f"Batch size: {args.batch_size}")
        
        cmd = [
            'aptos', 'move', 'run',
            '--function-id', f'{contract_addr}::csv_bulk_registration::register_participants_from_csv',
            '--args', 
            f'u64:{args.lottery_id}',
            f'string:{csv_content}',
            f'bool:{str(has_header).lower()}',
            f'u64:{args.batch_size}',
            '--profile', args.profile,
            '--assume-yes'
        ]
        
        result = subprocess.run(cmd, check=True)
        print("Bulk registration completed successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
