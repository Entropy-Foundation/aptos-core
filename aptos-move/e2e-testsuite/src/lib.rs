// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// The proptest `Arbitrary` strategy for the generated `EntryFunctionCall` enum (see
// `transaction_fuzzer`) builds a `TupleUnionValueTree` whose layout computation recurses once
// per enum variant. After the framework upgrade added more entry functions, the default limit
// of 128 is exceeded ("queries overflow the depth limit!"), so raise it for this crate.
#![recursion_limit = "256"]

#[cfg(test)]
mod tests;
