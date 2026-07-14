module supra_std::heap {
    use std::vector;
    use std::option::{Self, Option};

    const EHEAP_INDEX_OUT_OF_BOUNDS: u64 = 1;
    const EREMOVAL_FROM_EMPTY_HEAP: u64 = 2;
    const ENON_EMPTY_HEAP: u64 = 3;

    struct Heap<T> has store {
        elements: vector<T>,
    }

    public fun new<T: copy + drop>(): Heap<T> {
        Heap { elements: vector::empty<T>(), }
    }

    // Read-only borrow of the element at `index`
    public fun borrow<T>(heap: &Heap<T>, index: u64): &T {
        assert!(size(heap) > index, EHEAP_INDEX_OUT_OF_BOUNDS);
        vector::borrow(&heap.elements, index)
    }

    // Swaps elements at indices `i` and `j`
    // CAUTION: This method must not be used or called outside of this module. This method has been made public
    // only to allow `add` and `remove` inline methods to be able to call this with generic `cmp` comparision function
    // DO NOT USE THIS METHOD DIRECTLY, We will break this in future once `Function Values` are supported
    public fun unsafe_swap<T>(heap: &mut Heap<T>, i: u64, j: u64) {
        vector::swap(&mut heap.elements, i, j);
    }

    // Precondition: n == vector::length(&heap.elements) AND `heap` already maintains heap property with respect to `cmp` comparision function except
    //               at `index` where `index` may be sub-optimal with respect to its descendents with respect to `cmp`
    // Postcondition: `heap` maintains heap property with respect to `cmp` function

    //    public inline fun sift_down<T>(heap: &mut Heap<T>, index: u64, n: u64, cmp:|&T,&T|bool) {
    //        let opt = index;
    //        let left = 2 * index + 1;
    //        let right = 2 * index + 2;
    //
    //     while(opt < n) {
    //            let left = 2 * opt + 1;
    //            let right = 2 * opt + 2;
    //        if (left < n && cmp(supra_std::heap::borrow(heap,left), supra_std::heap::borrow(heap,opt))) {
    //            opt = left;
    //        };
    //        if (right < n && cmp(supra_std::heap::borrow(heap,right), supra_std::heap::borrow(heap,opt))) {
    //            opt = right;
    //        };
    //        if (opt != index) {
    //            supra_std::heap::unsafe_swap<T>(heap, index, opt);
    //        }
    //        else {
    //            break;
    //        };
    //     }
    //
    //    }

    // Returns the `size` of the `heap`
    public fun size<T>(heap: &Heap<T>): u64 {
        vector::length(&heap.elements)
    }

    // Returns the read-only reference to the elements of the heap
    public fun borrow_elems<T>(heap: &Heap<T>): &vector<T> {
        &heap.elements
    }

    //CAUTION: This method must never be called from outside of this module
    //This method is made public only to allow it to be called by `add`, which has to be an `inline`
    // method to receive a lambda for comparison
    // DO NOT USE THIS METHOD DIRECTLY, We will break this in future once `Function Values` are supported
    public fun unsafe_push_back<T>(heap: &mut Heap<T>, value: T) {
        vector::push_back(&mut heap.elements, value);
    }

    // Precondition: `heap` must already have the `heap` property with respect to `cmp` comparison function
    // Postcondition: A new element `value` is added to the `heap` while retaining the `heap` property with respect to `cmp` function
    public inline fun add<T>(heap: &mut Heap<T>, value: T, cmp: |&T, &T| bool) {
        supra_std::heap::unsafe_push_back(heap, value);
        let index = supra_std::heap::size(heap) - 1;
        while (index > 0) {
            let parent: u64 = if (index & 1 == 1) (index - 1) >> 1 else index >> 1;

            if (cmp(
                    supra_std::heap::borrow(heap, index),
                    supra_std::heap::borrow(heap, parent),
                )) {
                supra_std::heap::unsafe_swap<T>(heap, index, parent);
                index = parent;
            } else { break }
        }
    }

    //Precondition: `heap` must be having `heap` property with respect to `cmp` comparison function
    //Postcondition: If `heap` is non-empty it will return `option::some` of the optimum element (`max` or `min` as defined by `cmp` function), and it will
    // leave the `heap` that continues to maintain `heap` property with respect to `cmp` function
    public inline fun remove<T: copy>(heap: &mut Heap<T>, cmp: |&T, &T| bool): Option<T> {

        let result = option::none<T>();
        let n = supra_std::heap::size<T>(heap);
        if (n > 0) {
            supra_std::heap::unsafe_swap<T>(heap, 0, n - 1);
            let index = 0;
            result = option::some(supra_std::heap::pop_back(heap));
            n = n - 1;
            let opt = index;

            //The loop is guaranteed to terminate because if `opt` does not increase, it must necessarily go in the `else` branch and `break`
            while (opt <= (n / 2)) {
                let left = 2 * opt + 1;
                let right = 2 * opt + 2;
                if (left < n
                    && cmp(
                        supra_std::heap::borrow(heap, left),
                        supra_std::heap::borrow(heap, opt),
                    )) {
                    opt = left;
                };
                if (right < n
                    && cmp(
                        supra_std::heap::borrow(heap, right),
                        supra_std::heap::borrow(heap, opt),
                    )) {
                    opt = right;
                };
                if (opt != index) {
                    supra_std::heap::unsafe_swap<T>(heap, index, opt);
                    index = opt;
                } else {
                    break;
                };
            }
        };

        result
    }

    // Removes the last element from the heap, this should still maintain the heap property
    // Precondition: `heap` must not be empty
    public fun pop_back<T: copy>(heap: &mut Heap<T>): T {
        vector::pop_back(&mut heap.elements)
    }

    // Returns true if the heap is empty, false otherwise
    public fun is_empty<T>(h: &Heap<T>): bool {
        vector::is_empty<T>(&h.elements)
    }

    // Destroys an empty heap
    public fun destroy_empty<T: copy + drop>(h: Heap<T>) {
        assert!(is_empty<T>(&h), ENON_EMPTY_HEAP);
        vector::destroy_empty<T>(h.elements);
        let Heap<T> { elements } = h;
    }

    // Destroy a heap and removes/drop all the elements if it is non-empty
    public fun destroy<T: copy + drop>(h: Heap<T>) {
        clear(&mut h);
        destroy_empty(h);
    }

    // Returns a copy of the heap contents
    public fun get_heap_contents<T: copy>(heap: &Heap<T>): vector<T> {
        heap.elements
    }

    // Removes all the elements from the heap
    public fun clear<T: drop>(h: &mut Heap<T>) {
        while (vector::length(&h.elements) > 0) {
            vector::pop_back(&mut h.elements);
        }
    }

    // If the heap is non-empty, it returns the copy of the first element
    public fun get_top_element<T: copy + drop>(heap: &Heap<T>): Option<T> {
        if (is_empty(heap)) {
            option::none<T>()
        } else {
            option::some<T>(*vector::borrow<T>(&heap.elements, 0))
        }
    }
}
