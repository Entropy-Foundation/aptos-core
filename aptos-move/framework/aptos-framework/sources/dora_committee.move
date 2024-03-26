/// Design:
/// CommitteeInfoStore: store all the committee information, supported operation: add, remove
/// CommitteeInfo: store all the dora node information, supported operation: add, remove
/// DoraNodeInfo: store the dora node information, supported operation: update
/// NodeData: store the dora node information with operator's address
/// requirements:
/// 1. two committee has different id
/// 2. two indentical node should not be in the same committee
/// 3. the operator
module aptos_framework::dora_committee {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::capability;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::account::new_event_handle;
    use aptos_framework::event::{emit_event, EventHandle, emit};

    /// The signer is not the admin of the committee contract.
    const ENOT_ADMIN: u64 = 1;

    /// The number of committee is not equal to the number of committee member
    const INVALID_COMMITTEE_NUMBERS: u64 = 2;

    /// The node is not found in the committee
    const NODE_NOT_FOUND: u64 = 3;

    const SEED_COMMITTEE: vector<u8> = b"aptos_framework::dora_committee::CommitteeInfoStore";

    /// Capability that grants an owner the right to perform action.
    struct OwnerCap has drop { }

    struct SupraCommitteeEventHandler has key {
        create: EventHandle<CreateCommitteeInfoStoreEvent>,
        add_committee: EventHandle<AddCommitteeEvent>,
        remove_committee: EventHandle<RemoveCommitteeEvent>,
        update_committee: EventHandle<UpdateCommitteeEvent>,
        add_committee_member: EventHandle<AddCommitteeMemberEvent>,
        remove_committee_member: EventHandle<RemoveCommitteeMemberEvent>,
        update_node_info: EventHandle<UpdateNodeInfoEvent>,
    }

    struct CommitteeInfoStore has key {
        committee_map: SimpleMap<u64, CommitteeInfo>,
        node_to_committee_map: SimpleMap<address, u64>,
    }

    struct CommitteeInfo has store, drop {
        map_key: vector<address>,
        map_value: vector<DoraNodeInfo>,
        has_valid_dkg:bool,
    }

    struct DoraNodeInfo has store, copy, drop {
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,
        elgamal_pub_key:vector<u8>,
        network_port:u16,
        rpc_port:u16
    }

    struct NodeData has key, drop {
        operator: address,
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,
    }

    struct AddCommitteeEvent has store, drop {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    struct RemoveCommitteeEvent has store, drop {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    struct UpdateCommitteeEvent has store, drop {
        committee_id: u64,
        old_committee_info: CommitteeInfo,
        new_committee_info: CommitteeInfo
    }

    struct AddCommitteeMemberEvent has store, drop {
        committee_id: u64,
        committee_member: DoraNodeInfo
    }

    struct RemoveCommitteeMemberEvent has store, drop {
        committee_id: u64,
        committee_member: DoraNodeInfo
    }

    struct UpdateNodeInfoEvent has store, drop {
        committee_id: u64,
        old_node_info: DoraNodeInfo,
        new_node_info: DoraNodeInfo
    }

    struct CreateCommitteeInfoStoreEvent has store, drop {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    fun create_event_handler(owner_signer: &signer) {
        move_to(owner_signer, SupraCommitteeEventHandler {
            create: new_event_handle<CreateCommitteeInfoStoreEvent>(owner_signer),
            add_committee: new_event_handle<AddCommitteeEvent>(owner_signer),
            remove_committee: new_event_handle<RemoveCommitteeEvent>(owner_signer),
            update_committee: new_event_handle<UpdateCommitteeEvent>(owner_signer),
            add_committee_member: new_event_handle<AddCommitteeMemberEvent>(owner_signer),
            remove_committee_member: new_event_handle<RemoveCommitteeMemberEvent>(owner_signer),
            update_node_info: new_event_handle<UpdateNodeInfoEvent>(owner_signer),
        });
    }

    /// Internal - create OwnerCap
    fun create_owner(owner_signer: &signer) {
        capability::create<OwnerCap>(owner_signer, &OwnerCap { } );
    }

    /// Internal - create committeeInfo store functions
    fun create_committeeInfo_store(owner_signer: &signer): address{
        let address = signer::address_of(owner_signer);
        let (resource_account, _) = account::create_resource_account(owner_signer, SEED_COMMITTEE);
        move_to(&resource_account, CommitteeInfoStore {
            committee_map: simple_map::new(),
            node_to_committee_map: simple_map::new()});
        address
    }

    /// Its Initial function which will be executed automatically while deployed packages
    fun init_module(owner_signer: &signer) {
        create_owner(owner_signer);
        create_committeeInfo_store(owner_signer);
        create_event_handler(owner_signer);
    }

    #[view]
    /// Get the committee's dora node vector
    public fun get_committee_info(com_store_addr:address, id:u64):vector<NodeData> acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee= simple_map::borrow(&committee_store.committee_map, &id);
        let addrs = committee.map_key;
        let dora_nodes = committee.map_value;
        let node_data_vec = vector::empty<NodeData>();
        while (vector::length(&addrs) > 0) {
            let addr = vector::pop_back(&mut addrs);
            let dora_node_info = vector::pop_back(&mut dora_nodes);
            let node_data = NodeData {
                operator: addr,
                ip_public_address: dora_node_info.ip_public_address,
                dora_public_key: dora_node_info.dora_public_key,
                network_public_key: dora_node_info.network_public_key,
            };
            vector::push_back(&mut node_data_vec, node_data);
        };
        node_data_vec
    }

    #[view]
    /// Get the committee's ids from the store
    public fun get_committee_ids(com_store_addr:address):vector<u64> acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        simple_map::keys(&committee_store.committee_map)
    }

    #[view]
    // questions : only pass the address is okay?
    /// Get the committee's id for a single node, only pass the address is okay
    public fun get_committee_id(
        com_store_addr:address,
        map_key:vector<address>,
    ): u64 acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let node_address = vector::pop_back(&mut map_key);
        let id = *simple_map::borrow(&committee_store.node_to_committee_map, &node_address);
        id
    }

    #[view]
    /// Get the node's information
    public fun get_node_info(com_store_addr:address, id:u64, node_address:address): NodeData acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow(&committee_store.committee_map, &id);
        let (flag, index) = vector::index_of(&committee.map_key, &node_address);
        let dora_node_info = committee.map_value[index];
        assert!(flag, error::invalid_argument(NODE_NOT_FOUND));
        NodeData {
            operator: node_address,
            ip_public_address: dora_node_info.ip_public_address,
            dora_public_key: dora_node_info.dora_public_key,
            network_public_key: dora_node_info.network_public_key,
        }
    }

    #[view]
    /// Get the committee's id for a single node
    public fun get_committee_id_for_node(com_store_addr:address, node_address:address):u64 acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let id =  *simple_map::borrow(&committee_store.node_to_committee_map, &node_address);
        id
    }

    #[view]
    /// Get the dora node peers vector for a single node
    public fun get_peers_for_node(com_store_addr:address, node_address:address):vector<NodeData> acquires CommitteeInfoStore {
        let committee_id = get_committee_id_for_node(node_address, com_store_addr);
        let this_node = get_node_info(com_store_addr, committee_id, node_address);
        let dora_node_info = get_committee_info(com_store_addr, committee_id);
        let (_,index) = vector::index_of(&dora_node_info, &this_node);
        vector::remove(&mut dora_node_info, index);
        dora_node_info
    }

    #[view]
    /// Check if the committee has a valid dkg
    public fun does_com_have_dkg(com_store_addr:address, com_id:u64):bool acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow(&committee_store.committee_map, &com_id);
        committee.has_valid_dkg
    }

    /// Update the dkg flag
    public fun update_dkg_flag(com_store_addr:address, owner_signer:&signer, com_id:u64,flag_value:bool) acquires CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});
        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &com_id);
        committee.has_valid_dkg = flag_value;
    }

    /// This function is used to add a new committee to the store
    public entry fun upsert_committee(
        com_store_addr:address,
        owner_signer:&signer,
        id:u64,
        map_key: vector<address>,
        node_addresses: vector<address>,
        ip_public_address: vector<vector<u8>>,
        dora_public_key: vector<vector<u8>>,
        network_public_key: vector<vector<u8>>,
        elgamal_pub_key:vector<vector<u8>>,
        network_port:vector<u16>,
        rpc_port:vector<u16>
    ) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});
        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let owner_address = signer::address_of(owner_signer);
        let dora_node_info = vector::empty<DoraNodeInfo>();
        while(vector::length(&node_addresses) > 0) {
            let ip_public_address = vector::pop_back(&mut ip_public_address);
            let dora_public_key = vector::pop_back(&mut dora_public_key);
            let network_public_key = vector::pop_back(&mut network_public_key);
            let elgamal_pub_key = vector::pop_back(&mut elgamal_pub_key);
            let network_port = vector::pop_back(&mut network_port);
            let rpc_port = vector::pop_back(&mut rpc_port);
            let dora_node = DoraNodeInfo {
                ip_public_address: copy ip_public_address,
                dora_public_key: copy dora_public_key,
                network_public_key: copy network_public_key,
                elgamal_pub_key: copy elgamal_pub_key,
                network_port: network_port,
                rpc_port: rpc_port,
            };
            vector::push_back(&mut dora_node_info, dora_node);
        };
        let committee_info = CommitteeInfo {
            map_key: copy map_key,
            map_value: dora_node_info,
            has_valid_dkg: false,
        };
        let event_handler = borrow_global_mut<SupraCommitteeEventHandler>(owner_address);
        if (simple_map::contains_key(&committee_store.committee_map, &id)) {
            emit_event(
            &mut event_handler.add_committee,
            AddCommitteeEvent{
                committee_id: id,
                committee_info: copy committee_info},)
        } else {
            let old_committee_info = *simple_map::borrow(&committee_store.committee_map, &id);
            emit_event(
            &mut event_handler.update_committee,
                UpdateCommitteeEvent{
                    committee_id: id,
                    old_committee_info: old_committee_info,
                    new_committee_info: committee_info},
            )
        };
        simple_map::upsert(&mut committee_store.committee_map, id, committee_info);
    }

    /// Add the committee in bulk
    public entry fun upsert_committee_bulk(
        com_store_addr: address,
        owner_signer:&signer,
        ids:vector<u64>,
        map_key_bulk: vector<vector<address>>,
        node_addresses_bulk: vector<vector<address>>,
        ip_public_address_bulk: vector<vector<vector<u8>>>,
        dora_public_key_bulk: vector<vector<vector<u8>>>,
        network_public_key_bulk: vector<vector<vector<u8>>>,
        elgamal_pub_key_bulk:vector<vector<vector<u8>>>,
        network_port_bulk:vector<vector<u16>>,
        rpc_por_bulkt:vector<vector<u16>>,
    ) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // TODO assert the length
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            let map_key = vector::pop_back(&mut map_key_bulk);
            let node_addresses = vector::pop_back(&mut node_addresses_bulk);
            let ip_public_address = vector::pop_back(&mut ip_public_address_bulk);
            let dora_public_key = vector::pop_back(&mut dora_public_key_bulk);
            let network_public_key = vector::pop_back(&mut network_public_key_bulk);
            let elgamal_pub_key = vector::pop_back(&mut elgamal_pub_key_bulk);
            let network_port = vector::pop_back(&mut network_port_bulk);
            let rpc_port = vector::pop_back(&mut rpc_por_bulkt);
            upsert_committee(com_store_addr, owner_signer, id, map_key, node_addresses, ip_public_address, dora_public_key, network_public_key, elgamal_pub_key, network_port, rpc_port);
        }
    }

    /// Remove the committee from the store
    public entry fun remove_committee(com_store_addr:address, owner_signer:&signer , id:u64) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let (id, committee_info) = simple_map::remove(&mut committee_store.committee_map, &id);
        let owner_address = signer::address_of(owner_signer);
        let event_handler = borrow_global_mut<SupraCommitteeEventHandler>(owner_address);
        emit_event(
            &mut event_handler.remove_committee,
            RemoveCommitteeEvent{
                committee_id: id,
                committee_info: committee_info},)
    }

    /// Remove the committee in bulk
    public entry fun remove_committee_bulk(com_store_addr:address, owner_signer:&signer, ids:vector<u64>) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            remove_committee(com_store_addr, owner_signer, id);
        }
    }

    /// Upsert the node to the committee
    public entry fun upsert_committee_member(
        com_store_addr:address,
        owner_signer:&signer,
        id:u64,
        node_address: address,
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,
        elgamal_pub_key:vector<u8>,
        network_port:u16,
        rpc_port:u16,
    ) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        let dora_node_info = DoraNodeInfo {
            ip_public_address: copy ip_public_address,
            dora_public_key: copy dora_public_key,
            network_public_key: copy network_public_key,
            elgamal_pub_key: copy elgamal_pub_key,
            network_port: network_port,
            rpc_port: rpc_port,
        };
        let owner_address = signer::address_of(owner_signer);
        let event_handler = borrow_global_mut<SupraCommitteeEventHandler>(owner_address);
        let (flag, index) = vector::index_of(&committee.map_key, &node_address);
        let old_node_info = committee.map_value[index];
        if (!flag) {
            vector::push_back(&mut committee.map_key, node_address);
            vector::push_back(&mut committee.map_value, dora_node_info);
            emit_event(
                &mut event_handler.add_committee_member,
                AddCommitteeMemberEvent{
                    committee_id: id,
                    committee_member: dora_node_info},)
        } else {
            committee.map_value[index] = dora_node_info;
            emit_event(
                &mut event_handler.update_node_info,
                UpdateNodeInfoEvent{
                    committee_id: id,
                    old_node_info: dora_node_info,
                    new_node_info: old_node_info},)
        };
    }

    /// Upsert dora nodes to the committee
    public entry fun upsert_committee_member_bulk(
        com_store_addr:address,
        owner_signer:&signer,
        ids:vector<u64>,
        node_addresses: vector<address>,
        ip_public_address: vector<vector<u8>>,
        dora_public_key: vector<vector<u8>>,
        network_public_key: vector<vector<u8>>,
        elgamal_pub_key:vector<vector<u8>>,
        network_port:vector<u16>,
        rpc_port:vector<u16>
    ) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // TODO assert the length
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            let node_address = vector::pop_back(&mut node_addresses);
            let ip_public_address = vector::pop_back(&mut ip_public_address);
            let dora_public_key = vector::pop_back(&mut dora_public_key);
            let network_public_key = vector::pop_back(&mut network_public_key);
            let elgamal_pub_key = vector::pop_back(&mut elgamal_pub_key);
            let network_port = vector::pop_back(&mut network_port);
            let rpc_port = vector::pop_back(&mut rpc_port);
            upsert_committee_member(com_store_addr, owner_signer, id, node_address, ip_public_address, dora_public_key, network_public_key, elgamal_pub_key, network_port, rpc_port);
        }
    }

    /// Remove the node from the committee
    public entry fun remove_committee_member(com_store_addr:address, owner_signer:&signer, id:u64, node_address: address) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        let (flag, index) = vector::index_of(&committee.map_key, &node_address);
        assert!(flag, error::invalid_argument(NODE_NOT_FOUND));
        vector::remove(&mut committee.map_key, index);
        vector::remove(&mut committee.map_value, index);
        let owner_address = signer::address_of(owner_signer);
        let event_handler = borrow_global_mut<SupraCommitteeEventHandler>(owner_address);
        emit_event(
            &mut event_handler.remove_committee_member,
            RemoveCommitteeMemberEvent {
                committee_id: id,
                committee_member: DoraNodeInfo {
                    ip_public_address: vector::empty(),
                    dora_public_key: vector::empty(),
                    network_public_key: vector::empty(),
                    elgamal_pub_key: vector::empty(),
                    network_port: 0,
                    rpc_port: 0,
                }
            },
        )
    }

    /// The node can update its information
    /// If the node is not here, report errors
    public entry fun update_node_info(
        com_store_addr:address,
        owner_signer:&signer,
        id:u64,
        node_address: address,
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,
        elgamal_pub_key:vector<u8>,
        network_port:u16,
        rpc_port:u16
    ) acquires CommitteeInfoStore, SupraCommitteeEventHandler {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        let (flag, index) = vector::index_of(&committee.map_key, &node_address);
        assert!(flag, error::invalid_argument(NODE_NOT_FOUND));
        let old_node_info = committee.map_value[index];
        let new_node_info = DoraNodeInfo {
            ip_public_address: copy ip_public_address,
            dora_public_key: copy dora_public_key,
            network_public_key: copy network_public_key,
            elgamal_pub_key: copy elgamal_pub_key,
            network_port: network_port,
            rpc_port: rpc_port,
        };
        committee.map_value[index] = new_node_info;
        let owner_address = signer::address_of(owner_signer);
        let event_handler = borrow_global_mut<SupraCommitteeEventHandler>(owner_address);
        emit_event(
            &mut event_handler.update_node_info,
            UpdateNodeInfoEvent{
                committee_id: id,
                old_node_info: old_node_info,
                new_node_info: new_node_info},)

    }

    /// Find the node in the committee
    public fun find_node_in_committee(com_store_add:address, id:u64, node_address: address): (bool, NodeData) acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_add);
        let committee = simple_map::borrow(&committee_store.committee_map, &id);
        let (flag, index) = vector::index_of(&committee.map_key, &node_address);
        if (!flag) {
            return (false, NodeData {
                operator: copy node_address,
                ip_public_address: vector::empty(),
                dora_public_key: vector::empty(),
                network_public_key: vector::empty(),
            })
        } else {
            let dora_node_info = committee.map_value[index];
            (true, NodeData {
                operator: copy node_address,
                ip_public_address: dora_node_info.ip_public_address,
                dora_public_key: dora_node_info.dora_public_key,
                network_public_key: dora_node_info.network_public_key,
            })
        }
    }

    #[test_only]
    public fun initialize(owner_signer:&signer) {
        init_module(owner_signer);
    }

    // #[test]
    // public entry fun test_add_committee_member(com_store_addr: address,owner_signer:&signer) acquires CommitteeInfoStore {
    //     init_module(owner_signer);
    //     let committee_info = CommitteeInfo {
    //         map: simple_map::new(),
    //         has_valid_dkg: false,
    //         add_committee_member_event: new_event_handle<AddCommitteeMemberEvent>(owner_signer),
    //         remove_committee_member_event: new_event_handle<RemoveCommitteeMemberEvent>(owner_signer),
    //     };
    //     upsert_committee(com_store_addr, owner_signer, 1, committee_info);
    //     let node_addr = @0x1;
    //     let dora_node_info = DoraNodeInfo {
    //         ip_public_address: vector::empty(),
    //         dora_public_key: vector::empty(),
    //         network_public_key: vector::empty(),
    //         elgamal_pub_key: vector::empty(),
    //         network_port: 0,
    //         rpc_port: 0,
    //         update_node_info_event: new_event_handle<UpdateNodeInfoEvent>(owner_signer),
    //     };
    //     add_committee_member(com_store_addr, owner_signer, 1, node_addr, dora_node_info);
    //     let node_data = get_node_info(com_store_addr, 1, node_addr);
    // }

}
