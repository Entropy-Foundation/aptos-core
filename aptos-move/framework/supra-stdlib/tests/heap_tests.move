#[test_only]
module supra_std::heap_tests {
    use supra_std::heap;
    use std::vector;
    use std::option;
    use aptos_std::debug;

    #[test_only]
    inline fun is_heap<T>(v: &vector<T>, cmp: |&T, &T| bool): bool {
        let n = vector::length<T>(v);
        let result = true;
        for (i in 0..n) {
            let left = 2 * i + 1;
            let right = 2 * i + 2;
            if (left < n && !cmp(vector::borrow<T>(v, i), vector::borrow<T>(v, left))) {
                result = false;
            };
            if (right < n && !cmp(vector::borrow<T>(v, i), vector::borrow<T>(v, right))) {
                result = false;
            }
        };
        result
    }

    #[test]
    public fun test_heapify() {
        let v = vector<u64>[78, 32, 33, 34, 12, 21, 113, 321, 897];
        let heap = heap::new<u64>();
        vector::for_each<u64>(
            v,
            |item| {
                heap::add<u64>(&mut heap, item, |a, b| { *a < *b });
            }
        );

        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);
        heap::clear<u64>(&mut heap);
        heap::destroy_empty<u64>(heap);
    }

    #[test]
    public fun test_heap_add_remove() {
        let v = vector<u64>[78, 32, 33, 34, 12, 21, 113, 321, 897];
        let heap = heap::new<u64>();
        vector::for_each<u64>(
            v,
            |item| {
                heap::add<u64>(&mut heap, item, |a, b| { *a < *b });
            }
        );

        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);

        let removed = heap::remove(&mut heap, |a, b| { *a < *b });
        assert!(option::is_some<u64>(&removed), 3);
        assert!(option::extract<u64>(&mut removed) == 12, 2);

        removed = heap::remove(&mut heap, |a, b| { *a < *b });
        assert!(option::is_some<u64>(&removed), 3);
        assert!(option::extract<u64>(&mut removed) == 21, 2);

        heap::add<u64>(&mut heap, 2, |a, b| { *a < *b });
        removed = heap::remove(&mut heap, |a, b| { *a < *b });
        assert!(option::is_some<u64>(&removed), 3);
        assert!(option::extract<u64>(&mut removed) == 2, 2);

        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);
        heap::clear<u64>(&mut heap);
        heap::destroy_empty<u64>(heap);
    }

    #[test]
    public fun test_heap_pop() {
        let v = vector<u64>[78, 32, 33, 34, 12, 21, 113, 321, 897];
        let heap = heap::new<u64>();
        vector::for_each<u64>(
            v,
            |item| {
                heap::add<u64>(&mut heap, item, |a, b| { *a < *b });
            },
        );

        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);

        let popped = heap::pop_back(&mut heap);
        assert!(popped == 897, 2);
        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);
        heap::clear<u64>(&mut heap);
        heap::destroy_empty<u64>(heap);
    }

    #[test]
    public fun test_not_heap_afer_unsafe_swap() {
        let v = vector<u64>[78, 32, 33, 34, 12, 21, 113, 321, 897];
        let heap = heap::new<u64>();
        vector::for_each<u64>(
            v,
            |item| {
                heap::add<u64>(&mut heap, item, |a, b| { *a < *b });
            }
        );

        assert!(is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);

        supra_std::heap::unsafe_swap(&mut heap, 0, 1);
        assert!(!is_heap<u64>(&heap::get_heap_contents(&heap), |a, b| { *a < *b }), 1);
        //heap::clear<u64>(&mut heap);
        //heap::destroy_empty<u64>(heap);
        heap::destroy<u64>(heap);
    }

    #[test]
    public fun test_removal_from_empty_heap_returns_none() {
        let heap = heap::new<u64>();
        let removed = heap::remove(&mut heap, |a, b| { *a < *b });
        assert!(option::is_none(&removed), 1);
        heap::destroy_empty<u64>(heap);
    }
}
