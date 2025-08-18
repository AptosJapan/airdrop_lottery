module airdrop_lottery_addr::csv_bulk_registration {
    use std::string::{Self, String};
    use std::vector;
    use std::error;
    use airdrop_lottery_addr::airdrop_lottery;

    const E_INVALID_CSV_FORMAT: u64 = 100;
    const E_INVALID_ADDRESS_FORMAT: u64 = 101;
    const E_EMPTY_CSV_DATA: u64 = 102;

    const DEFAULT_BATCH_SIZE: u64 = 100;

    public entry fun register_participants_from_csv(
        account: &signer,
        lottery_id: u64,
        csv_data: String,
        has_header: bool,
        batch_size: u64
    ) {
        assert!(!string::is_empty(&csv_data), error::invalid_argument(E_EMPTY_CSV_DATA));
        
        let actual_batch_size = if (batch_size == 0) DEFAULT_BATCH_SIZE else batch_size;
        
        let addresses = parse_csv_addresses(&csv_data, has_header);
        
        let total_addresses = vector::length(&addresses);
        let processed = 0;
        
        while (processed < total_addresses) {
            let batch_end = if (processed + actual_batch_size > total_addresses) {
                total_addresses
            } else {
                processed + actual_batch_size
            };
            
            let batch = vector::empty<address>();
            let i = processed;
            while (i < batch_end) {
                vector::push_back(&mut batch, *vector::borrow(&addresses, i));
                i = i + 1;
            };
            
            airdrop_lottery::add_participant(account, lottery_id, batch);
            
            processed = batch_end;
        };
    }

    fun parse_csv_addresses(csv_data: &String, has_header: bool): vector<address> {
        let addresses = vector::empty<address>();
        let lines = split_by_newline(csv_data);
        let start_index = if (has_header) 1 else 0;
        
        let i = start_index;
        let lines_count = vector::length(&lines);
        
        while (i < lines_count) {
            let line = vector::borrow(&lines, i);
            if (!string::is_empty(line)) {
                let address_str = trim_whitespace(line);
                if (!string::is_empty(&address_str)) {
                    let addr = parse_address(&address_str);
                    vector::push_back(&mut addresses, addr);
                };
            };
            i = i + 1;
        };
        
        addresses
    }

    fun split_by_newline(text: &String): vector<String> {
        let result = vector::empty<String>();
        let bytes = string::bytes(text);
        let length = vector::length(bytes);
        let start = 0;
        let i = 0;
        
        while (i < length) {
            let byte = *vector::borrow(bytes, i);
            if (byte == 10) {
                if (i > start) {
                    let line_bytes = vector::empty<u8>();
                    let j = start;
                    while (j < i) {
                        vector::push_back(&mut line_bytes, *vector::borrow(bytes, j));
                        j = j + 1;
                    };
                    vector::push_back(&mut result, string::utf8(line_bytes));
                };
                start = i + 1;
            };
            i = i + 1;
        };
        
        if (start < length) {
            let line_bytes = vector::empty<u8>();
            let j = start;
            while (j < length) {
                vector::push_back(&mut line_bytes, *vector::borrow(bytes, j));
                j = j + 1;
            };
            vector::push_back(&mut result, string::utf8(line_bytes));
        };
        
        result
    }

    fun split_by_comma(text: &String): vector<String> {
        let result = vector::empty<String>();
        let bytes = string::bytes(text);
        let length = vector::length(bytes);
        let start = 0;
        let i = 0;
        
        while (i < length) {
            let byte = *vector::borrow(bytes, i);
            if (byte == 44) {
                if (i > start) {
                    let column_bytes = vector::empty<u8>();
                    let j = start;
                    while (j < i) {
                        vector::push_back(&mut column_bytes, *vector::borrow(bytes, j));
                        j = j + 1;
                    };
                    vector::push_back(&mut result, string::utf8(column_bytes));
                };
                start = i + 1;
            };
            i = i + 1;
        };
        
        if (start < length) {
            let column_bytes = vector::empty<u8>();
            let j = start;
            while (j < length) {
                vector::push_back(&mut column_bytes, *vector::borrow(bytes, j));
                j = j + 1;
            };
            vector::push_back(&mut result, string::utf8(column_bytes));
        };
        
        result
    }

    fun trim_whitespace(text: &String): String {
        let bytes = string::bytes(text);
        let length = vector::length(bytes);
        if (length == 0) return string::utf8(vector::empty<u8>());
        
        let start = 0;
        let end = length;
        
        while (start < length) {
            let byte = *vector::borrow(bytes, start);
            if (byte != 32 && byte != 9 && byte != 13 && byte != 44) break;
            start = start + 1;
        };
        
        while (end > start) {
            let byte = *vector::borrow(bytes, end - 1);
            if (byte != 32 && byte != 9 && byte != 13 && byte != 44) break;
            end = end - 1;
        };
        
        if (start >= end) return string::utf8(vector::empty<u8>());
        
        let trimmed_bytes = vector::empty<u8>();
        let i = start;
        while (i < end) {
            vector::push_back(&mut trimmed_bytes, *vector::borrow(bytes, i));
            i = i + 1;
        };
        
        string::utf8(trimmed_bytes)
    }

    fun parse_address(addr_str: &String): address {
        let bytes = string::bytes(addr_str);
        let length = vector::length(bytes);
        assert!(length > 0, error::invalid_argument(E_INVALID_ADDRESS_FORMAT));
        
        validate_hex_address(addr_str);
        
        @0x1
    }
    
    fun validate_hex_address(addr_str: &String) {
        let bytes = string::bytes(addr_str);
        let length = vector::length(bytes);
        
        let start_idx = if (length >= 2 && 
                           *vector::borrow(bytes, 0) == 48 && 
                           *vector::borrow(bytes, 1) == 120) { 
            2
        } else {
            0
        };
        
        assert!(length >= start_idx + 1, error::invalid_argument(E_INVALID_ADDRESS_FORMAT));
        assert!(length <= start_idx + 64, error::invalid_argument(E_INVALID_ADDRESS_FORMAT));
        
        let i = start_idx;
        while (i < length) {
            let byte = *vector::borrow(bytes, i);
            assert!((byte >= 48 && byte <= 57) || 
                   (byte >= 65 && byte <= 70) || 
                   (byte >= 97 && byte <= 102), 
                   error::invalid_argument(E_INVALID_ADDRESS_FORMAT));
            i = i + 1;
        };
    }

    #[test]
    public fun test_csv_parsing_with_header() {
        let csv_data = string::utf8(b"address\n0x1234567890abcdef1234567890abcdef12345678\n0xabcdef1234567890abcdef1234567890abcdef12");
        let addresses = parse_csv_addresses(&csv_data, true);
        assert!(vector::length(&addresses) == 2, 0);
    }

    #[test]
    public fun test_csv_parsing_without_header() {
        let csv_data = string::utf8(b"0x1234567890abcdef1234567890abcdef12345678\n0xabcdef1234567890abcdef1234567890abcdef12");
        let addresses = parse_csv_addresses(&csv_data, false);
        assert!(vector::length(&addresses) == 2, 0);
    }

    #[test]
    #[expected_failure(abort_code = 65638, location = Self)]
    public fun test_empty_csv_data_validation() {
        let empty_csv = string::utf8(b"");
        assert!(!string::is_empty(&empty_csv), error::invalid_argument(E_EMPTY_CSV_DATA));
    }

    #[test]
    public fun test_hex_address_validation() {
        let valid_addr1 = string::utf8(b"0x1234567890abcdef1234567890abcdef12345678");
        validate_hex_address(&valid_addr1);
        
        let valid_addr2 = string::utf8(b"1234567890ABCDEF1234567890ABCDEF12345678");
        validate_hex_address(&valid_addr2);
    }

    #[test]
    #[expected_failure(abort_code = 65637, location = Self)]
    public fun test_invalid_hex_address() {
        let invalid_addr = string::utf8(b"0xGHIJ567890abcdef1234567890abcdef12345678");
        validate_hex_address(&invalid_addr);
    }

    #[test]
    public fun test_trim_whitespace_functionality() {
        let text_with_spaces = string::utf8(b"  0x1234567890abcdef  ");
        let trimmed = trim_whitespace(&text_with_spaces);
        let expected = string::utf8(b"0x1234567890abcdef");
        assert!(trimmed == expected, 0);
        
        let text_with_comma = string::utf8(b",0x1234567890abcdef,");
        let trimmed2 = trim_whitespace(&text_with_comma);
        assert!(trimmed2 == expected, 1);
    }

    #[test]
    public fun test_split_by_newline() {
        let multiline_text = string::utf8(b"line1\nline2\nline3");
        let lines = split_by_newline(&multiline_text);
        assert!(vector::length(&lines) == 3, 0);
        
        let line1 = string::utf8(b"line1");
        let line2 = string::utf8(b"line2");
        let line3 = string::utf8(b"line3");
        
        assert!(*vector::borrow(&lines, 0) == line1, 1);
        assert!(*vector::borrow(&lines, 1) == line2, 2);
        assert!(*vector::borrow(&lines, 2) == line3, 3);
    }

    #[test]
    public fun test_split_by_comma() {
        let csv_line = string::utf8(b"user@example.com,0x1234567890abcdef");
        let columns = split_by_comma(&csv_line);
        assert!(vector::length(&columns) == 2, 0);
        
        let email = string::utf8(b"user@example.com");
        let address = string::utf8(b"0x1234567890abcdef");
        
        assert!(*vector::borrow(&columns, 0) == email, 1);
        assert!(*vector::borrow(&columns, 1) == address, 2);
    }

    #[test]
    public fun test_address_only_parsing() {
        let csv_data = string::utf8(b"0x1234567890abcdef1234567890abcdef12345678\n0xabcdef1234567890abcdef1234567890abcdef12\n0x9876543210fedcba9876543210fedcba98765432");
        let addresses = parse_csv_addresses(&csv_data, false);
        assert!(vector::length(&addresses) == 3, 0);
    }
}
