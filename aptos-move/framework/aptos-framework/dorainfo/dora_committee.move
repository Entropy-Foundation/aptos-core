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
    use std::vector;
    use aptos_std::capability;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::account::new_event_handle;
    use aptos_framework::event::{emit_event, EventHandle};

    /// The signer is not the admin of the committee contract.
    const ENOT_ADMIN: u64 = 1;
    const INVALID_COMMITTEE_NUMBERS: u64 = 2;
    // TODO: use a better seed
    const SEED_COMMITTEE: vector<u8> = b"aptos_framework::DoraNode::CommitteeInfoStore";

    /// Capability that grants an owner the right to perform action.
    struct OwnerCap has drop { }

    struct CommitteeInfoStore has key, store{
        committee_map: SimpleMap<u64, CommitteeInfo>,
        node_to_committee_map: SimpleMap<address, u64>,
        create_events: EventHandle<CreateCommitteeInfoStoreEvent>,
        add_committee_event: EventHandle<AddCommitteeEvent>,
        remove_committee_event: EventHandle<RemoveCommitteeEvent>,
        update_committee_event: EventHandle<UpdateCommitteeEvent>
    }

    struct CommitteeInfo has store, copy, drop{
        map: SimpleMap<address, DoraNodeInfo>,

        // events
        add_committee_member_event: EventHandle<AddCommitteeMemberEvent>,
        remove_committee_member_event: EventHandle<RemoveCommitteeMemberEvent>,
    }

    struct DoraNodeInfo has store, copy, drop {
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,

        // events
        update_node_info_event: EventHandle<UpdateNodeInfoEvent>,
    }

    struct NodeData {
        operator: address,
        ip_public_address: vector<u8>,
        dora_public_key: vector<u8>,
        network_public_key: vector<u8>,
    }

    struct AddCommitteeEvent has drop, store {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    struct RemoveCommitteeEvent {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    struct UpdateCommitteeEvent has drop, store {
        committee_id: u64,
        old_committee_info: CommitteeInfo,
        new_committee_info: CommitteeInfo
    }

    struct AddCommitteeMemberEvent {
        committee_id: u64,
        committee_member: DoraNodeInfo
    }

    struct RemoveCommitteeMemberEvent {
        committee_id: u64,
        committee_member: DoraNodeInfo
    }

    struct UpdateNodeInfoEvent {
        committee_id: u64,
        old_node_info: DoraNodeInfo,
        new_node_info: DoraNodeInfo
    }

    struct CreateCommitteeInfoStoreEvent {
        committee_id: u64,
        committee_info: CommitteeInfo
    }

    /// Internal - create OwnerCap
    fun create_owner(owner_signer: &signer) {
        capability::create<OwnerCap>(owner_signer, &OwnerCap { } );
    }

    /// Internal - create committeeInfo store functions
    fun create_committeeInfo_store(owner_signer: &signer) {
        let (resource_account, _) = account::create_resource_account(owner_signer, SEED_COMMITTEE);
        move_to(&resource_account, CommitteeInfoStore {
            committee_map: simple_map::new(),
            node_to_committee_map: simple_map::new(),
            create_events: new_event_handle<CreateCommitteeInfoStoreEvent>(owner_signer),
            add_committee_event: new_event_handle<AddCommitteeEvent>(owner_signer),
            remove_committee_event: new_event_handle<RemoveCommitteeEvent>(owner_signer),
            update_committee_event: new_event_handle<UpdateCommitteeEvent>(owner_signer)});
    }

    /// Its Initial function which will be executed automatically while deployed packages
    fun init_module(owner_signer: &signer) {
        create_owner(owner_signer);
        create_committeeInfo_store(owner_signer);
    }

    #[view]
    /// Get the committee's dora node vector
    public fun get_committee_info(com_store_addr:address, id:u64 ):vector<NodeData> acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee= simple_map::borrow(&committee_store.committee_map, &id);
        let (addrs, dora_nodes) = simple_map::to_vec_pair(committee.map);
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
    /// Get
    public fun get_committee_id(com_store_addr:address, commitee: CommitteeInfo) : u64 acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee_map = commitee.map;
        let (addrs, _) = simple_map::to_vec_pair(committee_map);
        let node_address = vector::pop_back(&mut addrs);
        let id = *simple_map::borrow(&committee_store.node_to_committee_map, &node_address);
        id
    }

    #[view]
    /// Get the node's information
    public fun get_node_info(com_store_addr:address, id:u64, operator_address:address): NodeData acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow(&committee_store.committee_map, &id);
        let dora_node_info = simple_map::borrow(&committee.map, &operator_address);
        NodeData {
            operator: operator_address,
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

    /// This function is used to add a new committee to the store
    public entry fun upsert_committee(com_store_addr:address, owner_signer:&signer, id:u64, committee_info:CommitteeInfo) acquires CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});
        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        if (simple_map::contains_key(&committee_store.committee_map, &id)) {
            emit_event(
            &mut committee_store.add_committee_event,
            AddCommitteeEvent{
                committee_id: id,
                committee_info: committee_info},)
        } else {
            let old_committee_info = *simple_map::borrow(&committee_store.committee_map, &id);
            emit_event(
            &mut committee_store.update_committee_event,
                UpdateCommitteeEvent{
                    committee_id: id,
                    old_committee_info: old_committee_info,
                    new_committee_info: committee_info},
            )
        };
        simple_map::upsert(&mut committee_store.committee_map, id, committee_info);
    }

    /// Add the committee in bulk
    public entry fun upsert_committee_bulk(com_store_addr: address, owner_signer:&signer, ids:vector<u64>, committee_member_bulk:vector<CommitteeInfo>) acquires CommitteeInfoStore {
        assert!(vector::length(&ids) == vector::length(&committee_member_bulk), error::invalid_argument(INVALID_COMMITTEE_NUMBERS));
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            let committee_member = vector::pop_back(&mut committee_member_bulk);
            upsert_committee(com_store_addr, owner_signer, id, committee_member);
        }
    }

    /// Remove the committee from the store
    public entry fun remove_committee(com_store_addr:address, owner_signer:&signer , id:u64) acquires CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let (id, committee_info) = simple_map::remove(&mut committee_store.committee_map, &id);
        emit_event(
            &mut committee_store.remove_committee_event,
            RemoveCommitteeEvent{
                committee_id: id,
                committee_info: committee_info},)
    }

    /// Remove the committee in bulk
    public entry fun remove_committee_bulk(com_store_addr:address, owner_signer:&signer, ids:vector<u64>) acquires CommitteeInfoStore {
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            remove_committee(com_store_addr, owner_signer, id);
        }
    }

    /// Add the node to the committee
    public entry fun add_committee_member( com_store_addr:address, owner_signer:&signer, id:u64, node_addr: address, doar_node_info:DoraNodeInfo) acquires CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        let dora_node_vec = simple_map::borrow_mut(&mut committee.map, &node_addr);
        vector::push_back(dora_node_vec, doar_node_info);
        emit_event(
            &mut committee.add_committee_member_event,
            AddCommitteeMemberEvent{
                committee_id: id,
                committee_member: doar_node_info},)
    }

    /// Add dora nodes to the committee
    public entry fun add_committee_member_bulk(com_store_addr:address, owner_signer:&signer, ids:vector<u64>, node_addr_bulk: vector<address>, doar_node_infos:vector<DoraNodeInfo>) acquires CommitteeInfoStore {
        assert!(vector::length(&ids) == vector::length(&doar_node_infos), error::invalid_argument(INVALID_COMMITTEE_NUMBERS));
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            let doar_node_info = vector::pop_back(&mut doar_node_infos);
            let node_addr = vector::pop_back(&mut node_addr_bulk);
            add_committee_member(com_store_addr, owner_signer, id, node_addr, doar_node_info);
        }
    }

    /// Remove the node from the committee
    public entry fun remove_committee_member(com_store_addr:address, owner_signer:&signer, id:u64, node_addr: address) acquires CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        simple_map::remove(&mut committee.map, &node_addr);
    }

    /// The node can update its information
    /// If the node is not here, report errors
    public entry fun update_node_info(com_store_addr:address, owner_signer:&signer, id:u64, node_addr: address, old_node_info:DoraNodeInfo ,new_node_info:DoraNodeInfo) acquires CommitteeInfo, CommitteeInfoStore {
        // Only the OwnerCap capability can access it
        let _acquire = &capability::acquire(owner_signer, &OwnerCap {});

        let committee_store = borrow_global_mut<CommitteeInfoStore>(com_store_addr);
        let committee = simple_map::borrow_mut(&mut committee_store.committee_map, &id);
        let dora_node_vec = simple_map::borrow_mut(&mut committee.map, &node_addr);
        let (_,index) = vector::index_of(dora_node_vec, &old_node_info);
        let old_node_info = vector::remove(dora_node_vec, index);
        vector::push_back(dora_node_vec, new_node_info);
        emit_event(
            &mut old_node_info.update_node_info_event,
            UpdateNodeInfoEvent{
                committee_id: id,
                old_node_info: old_node_info,
                new_node_info: new_node_info},)

    }

    /// Find the node in the committee
    public fun find_node_in_committee(com_store_add:address, id:u64, node_address: address): (bool, NodeData) acquires CommitteeInfoStore {
        let committee_store = borrow_global<CommitteeInfoStore>(com_store_add);
        let committee = simple_map::borrow(&committee_store.committee_map, &id);
        if (!simple_map::contains_key(&committee.map, &node_address)) {
            return (false, NodeData {
                operator: node_address,
                ip_public_address: vector::empty(),
                dora_public_key: vector::empty(),
                network_public_key: vector::empty(),
            });
        };
        let dora_node_info = simple_map::borrow(&committee.map, &node_address);
        (true, NodeData {
            operator: node_address,
            ip_public_address: dora_node_info.ip_public_address,
            dora_public_key: dora_node_info.dora_public_key,
            network_public_key: dora_node_info.network_public_key,
        })
    }
}
