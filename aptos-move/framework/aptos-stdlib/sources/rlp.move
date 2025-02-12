module std::rlp {

    use std::bcs;
    use aptos_std::from_bcs;
    #[test_only]
    use std::string;
    #[test_only]
    use std::vector;

    //
    // 2) Encode/Decode for Primitives
    //
    //    Each function:
    //      - BCS-serialize the primitive
    //      - RLP-encode the resulting bytes
    //    Then decode does the reverse: RLP-decode -> BCS bytes -> Convert to the primitive.

    public fun encode_bool(x: bool): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_bool(encoded_rlp: vector<u8>): bool {
        from_bcs::to_bool(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u8(x: u8): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u8(encoded_rlp: vector<u8>): u8 {
        from_bcs::to_u8(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u16(x: u16): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u16(encoded_rlp: vector<u8>): u16 {
        from_bcs::to_u16(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u32(x: u32): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u32(encoded_rlp: vector<u8>): u32 {
        from_bcs::to_u32(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u64(x: u64): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u64(encoded_rlp: vector<u8>): u64 {
        from_bcs::to_u64(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u128(x: u128): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u128(encoded_rlp: vector<u8>): u128 {
        from_bcs::to_u128(native_rlp_decode(encoded_rlp))
    }

    public fun encode_u256(x: u256): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&x))
    }

    public fun decode_u256(encoded_rlp: vector<u8>): u256 {
        from_bcs::to_u256(native_rlp_decode(encoded_rlp))
    }

    public fun encode_address(addr: address): vector<u8> {
        native_rlp_encode(bcs::to_bytes(&addr))
    }

    public fun decode_address(encoded_rlp: vector<u8>): address {
        from_bcs::to_address(native_rlp_decode(encoded_rlp))
    }

    public fun encode_bytes(data: vector<u8>): vector<u8> {
        native_rlp_encode(data)
    }

    public fun decode_bytes(encoded_rlp: vector<u8>): vector<u8> {
        native_rlp_decode(encoded_rlp)
    }

    public fun encode_string(s: &std::string::String): vector<u8> {
        native_rlp_encode(bcs::to_bytes(s))
    }

    public fun decode_string(encoded_rlp: vector<u8>): std::string::String {
        from_bcs::to_string(native_rlp_decode(encoded_rlp))
    }

    //
    // Native functions
    //
    native public fun native_rlp_encode(
        data: vector<u8>,
    ): vector<u8>;

    native public fun native_rlp_decode(
        encoded_data: vector<u8>,
    ): vector<u8>;

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
            let encoded = encode_bool(orig);
            let decoded = decode_bool(encoded);
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
            let encoded = encode_u8(orig);
            let decoded = decode_u8(encoded);
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
            let encoded = encode_u16(orig);
            let decoded = decode_u16(encoded);
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
            let encoded = encode_u32(orig);
            let decoded = decode_u32(encoded);
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
            let encoded = encode_u64(orig);
            let decoded = decode_u64(encoded);
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
            let encoded = encode_u128(orig);
            let decoded = decode_u128(encoded);
            assert!(decoded == orig, 6000 + i);
            i = i + 1;
        };
    }

    //
    // 7) Test encode_u256 / decode_u256
    //
    #[test]
    fun test_u256() {
        let cases: vector<u256> = vector[
        0,
        1,
        115792089237316195423570985008687907853269984665640564039457584007913129639935
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode_u256(orig);
            let decoded = decode_u256(encoded);
            assert!(decoded == orig, 7000 + i);
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
            let encoded = encode_address(orig);
            let decoded = decode_address(encoded);
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
            let encoded = encode_bytes(orig);
            let decoded = decode_bytes(encoded);
            assert!(decoded == orig, 9000 + i);
            i = i + 1;
        };
    }

    //
    // 10) Test encode_string / decode_string
    //
    #[test]
    fun test_string() {
        let s_empty = string::utf8(b"");
        let s_ascii = string::utf8(b"Hello, RLP!");

        let cases: vector<string::String> = vector[
        s_empty,
        s_ascii,
        ];
        let len = vector::length(&cases);

        let i = 0;
        while (i < len) {
            let orig = *vector::borrow(&cases, i);
            let encoded = encode_string(&orig);
            let decoded = decode_string(encoded);
            assert!(decoded == orig, 10000 + i);
            i = i + 1;
        };
    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_u8_with_invalid_data() {
        let invalid_data = b"\xDE\xAD\xBE\xEF"; // random bytes, not valid RLP for a single BCS-encoded u8
        let _ = decode_u8(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_u64_with_empty_data() {
        // Empty data is definitely not valid RLP (or BCS) for a u64
        let invalid_data = b"";
        let _ = decode_u64(invalid_data);
        // Should abort.
    }

    #[test]
    #[expected_failure( abort_code = 0x1, location = Self)]
    fun test_decode_string_with_junk_data() {
        // This might cause the RLP decode to fail (and return empty),
        let invalid_data = b"\xFF\xFF\xFF\xFF\x00\x01\x02";
        let _ = decode_string(invalid_data);
        // Should abort.
    }
}
