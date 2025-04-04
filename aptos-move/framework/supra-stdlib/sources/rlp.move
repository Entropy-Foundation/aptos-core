module supra_std::rlp {

    use std::bcs;
    #[test_only]
    use std::vector;

    // Encode/Decode for type T
    // Types supported: bool, u8, u16, u32, u64, u128, address, vector<u8>
    // Attempting to encode any other type results in E_UNSUPPORTED_TYPE error
    public fun encode<T>(x: T): vector<u8> {
        native_rlp_encode(x)
    }

    public fun decode<T>(encoded_rlp: vector<u8>): T {
        native_rlp_decode(encoded_rlp)
    }

    // Encode/Decode for list
    // Type of lists supported: bool, u8, u16, u32, u64, u128, address
    // Attempting to encode any other type results in E_UNSUPPORTED_TYPE error
    public fun encode_list<T: drop>(data: vector<T>): vector<u8> {
        native_rlp_encode_list<T>(bcs::to_bytes(&data))
    }

    public fun decode_list<T>(encoded_rlp: vector<u8>): vector<T> {
        native_rlp_decode_list(encoded_rlp)
    }

    //
    // Native functions
    //
    native public fun native_rlp_encode<T>(x: T): vector<u8>;
    native public fun native_rlp_decode<T>(data: vector<u8>): T;

    native public fun native_rlp_encode_list<T>(x: vector<u8>): vector<u8>;
    native public fun native_rlp_decode_list<T>(data: vector<u8>): vector<T>;

    //
    // 1) Test encode_bool / decode_bool
    //
    #[test]
    fun test_bool() {
        let cases = vector[true, false];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 1000 + i);
            i = i + 1;
        };
    }

    //
    // 2) Test encode_u8 / decode_u8
    //
    #[test]
    fun test_u8() {
        let cases: vector<u8> = vector[0, 1, 42, 255];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 2000 + i);
            i = i + 1;
        };
    }

    //
    // 3) Test encode_u16 / decode_u16
    //
    #[test]
    fun test_u16() {
        let cases: vector<u16> = vector[0, 1, 42, 65535];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 3000 + i);
            i = i + 1;
        };
    }

    //
    // 4) Test encode_u32 / decode_u32
    //
    #[test]
    fun test_u32() {
        let cases: vector<u32> = vector[
        0,
        1,
        42,
        4294967295 // (2^32 - 1)
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 4000 + i);
            i = i + 1;
        };
    }

    //
    // 5) Test encode_u64 / decode_u64
    //
    #[test]
    fun test_u64() {
        let cases: vector<u64> = vector[
        0,
        1,
        42,
        9999999999,
        18446744073709551615 // (2^64 - 1)
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 5000 + i);
            i = i + 1;
        };
    }

    //
    // 6) Test encode_u128 / decode_u128
    //
    #[test]
    fun test_u128() {
        let cases: vector<u128> = vector[
        0,
        1,
        123456789012345678901234567890,
        340282366920938463463374607431768211455 // (2^128 - 1)
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 6000 + i);
            i = i + 1;
        };
    }

    //
    // 8) Test encode_address / decode_address
    //
    #[test]
    fun test_address() {
        // Some representative addresses
        let addr1 = @0x0;
        let addr2 = @0x1;
        let addr3 = @0x1234;
        let addr4 = @0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        let addr5 = @0x123456789ABCDEF0123456789ABCDEF0;

        let addresses: vector<address> = vector[addr1, addr2, addr3, addr4, addr5];
        let len = vector::length(&addresses);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&addresses, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 8000 + i);
            i = i + 1;
        };
    }

    //
    // 9) Test encode_bytes / decode_bytes
    //
    #[test]
    fun test_bytes() {
        let empty = b"";
        let single_byte = b"\xAB";
        let short_bytes = b"Hello RLP!";
        let random_hex = x"DEADBEEF";
        let longer = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

        let cases: vector<vector<u8>> =  vector[
        empty,
        single_byte,
        short_bytes,
        random_hex,
        longer
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode(orig);
            let decoded = decode(encoded);
            assert!(decoded == orig, 9000 + i);
            i = i + 1;
        };
    }

    //
    // 10) Test encode_list / decode_list
    //
    #[test]
    fun test_list() {

        let u8_list: vector<u8> =  vector[1, 2, 3];
        let encoded = encode_list<u8>(u8_list);
        let decoded: vector<u8> = decode_list<u8>(encoded);
        assert!(decoded == u8_list, 10000);

        let u64_list: vector<u64> =  vector[1, 2, 3];
        let encoded = encode_list<u64>(u64_list);
        let decoded: vector<u64> = decode_list<u64>(encoded);
        assert!(decoded == u64_list, 10001);

        let bool_list: vector<bool> =  vector[true, false, true];
        let encoded = encode_list<bool>(bool_list);
        let decoded: vector<bool> = decode_list<bool>(encoded);
        assert!(decoded == bool_list, 10002);

        let addr1 = @0x0;
        let addr2 = @0x1;
        let addr3 = @0x1234;
        let addr4 = @0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        let addr5 = @0x123456789ABCDEF0123456789ABCDEF0;
        let adress_list: vector<address> = vector[addr1, addr2, addr3, addr4, addr5];

        let encoded = encode_list<address>(adress_list);
        let decoded: vector<address> = decode_list<address>(encoded);
        assert!(decoded == adress_list, 10003);

    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_u8_with_invalid_data() {
        let invalid_data = b"\xDE\xAD\xBE\xEF"; // random bytes, not valid RLP
        let _ = decode<vector<u8>>(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_u64_with_empty_data() {
        // Empty data is definitely not valid RLP for a u64
        let invalid_data = b"";
        let _ = decode<u64>(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_address_with_invalid_data() {
        let invalid_data = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz012"; // random bytes, not valid RLP
        let _ = decode<address>(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x3, location = Self)]
    fun test_encode_with_unsupported_type() {
        let invalid_data = vector[1,2,3];
        let _ = encode<vector<u128>>(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x3, location = Self)]
    fun test_encode_list_with_unsupported_type() {
        let invalid_data = b"1234";
        let _ = encode_list<vector<u8>>(vector[invalid_data]);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x3, location = Self)]
    fun test_decode_list_with_unsupported_type() {
        let invalid_data = b"1234"; // random bytes, not valid RLP
        let _ = decode_list<vector<u8>>(invalid_data);
        // Should abort.
    }
}
