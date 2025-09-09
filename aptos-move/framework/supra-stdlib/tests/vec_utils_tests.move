#[test_only]
module supra_std::vec_utils_tests {

    use std::features;
    use std::vector;
    use supra_std::vec_utils;

    fun prepare_env(supra_framework: &signer) {
        let flag = vector[features::get_supra_vec_utils_feature()];
        features::change_feature_flags_for_testing(
            supra_framework, flag, vector::empty<u64>()
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x1, location = vec_utils)]
    fun test_flatten_aborts_when_feature_disabled() {
        let _ = vec_utils::flatten_nested_vec_to_vec(vector[ vector[1u8], vector[2u8, 3u8] ]);
    }

    // Round-trip on a few shapes: empty, single, multiple (with empty inner)
    #[test(supra_framework = @supra_framework)]
    fun test_roundtrip_basic(supra_framework: signer) {
        prepare_env(&supra_framework);

        // Case 1: empty outer vec
        {
            let data = vector<vector<u8>>[];
            let flat = vec_utils::flatten_nested_vec_to_vec(data);
            let back = vec_utils::unflatten_vec_to_nested_vec(flat);
            assert!(back == vector<vector<u8>>[], 100);
        };

        // Case 2: single inner vec
        {
            let data = vector[ vector[1u8, 2u8, 3u8] ];
            let flat = vec_utils::flatten_nested_vec_to_vec(data);
            let back = vec_utils::unflatten_vec_to_nested_vec(flat);
            assert!(back == vector[ vector[1u8, 2u8, 3u8] ], 101);
        };

        // Case 3: multiple, including an empty inner vec
        {
            let data = vector[
                vector[10u8, 11u8],
                vector[],                    // zero-length inner vec
                vector[0xFFu8],
                vector[9u8, 0u8, 9u8],
            ];
            let flat = vec_utils::flatten_nested_vec_to_vec(data);
            let back = vec_utils::unflatten_vec_to_nested_vec(flat);
            assert!(
                back == vector[
                    vector[10u8, 11u8],
                    vector[],
                    vector[0xFFu8],
                    vector[9u8, 0u8, 9u8],
                ],
                102
            );
        };
    }
}
