module aptos_framework::DoraNode {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::event::{emit_event, EventHandle};
    use aptos_framework::managed_coin::Capabilities;

    /// The signer is not the admin of the committee contract.
    const ENOT_ADMIN: u64 = 1;

    // requirements:
    // 1. two committee has different id
    // 2. two indentical node should not be in the same committee
    // 3. the operator
    struct CommitteeInfoStore has key, store{
        committee_map: SimpleMap<u64, CommitteeInfo>,
        node_to_committee_map: SimpleMap<address, u64>,
        // TODO Key capabilities
        // TODO events
    }

    struct CommitteeInfo has store, copy, drop{
        map: SimpleMap<address, vector<DoraNodeInfo>>,
        // admin: address,
        // TODO capabilities for authentication and authorization
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

    #[view]
    /// Get the committee's dora node vector
    public fun get_committee_info(id:u64, com_store_address:address):vector<NodeData> acquires CommitteeInfo {
        let committee = borrow_global<CommitteeInfoStore>(address);
        find_dora_nodes(id, committee)
    }

    #[view]
    /// Get the committee's ids
    public fun get_committee_ids(com_store_address:address):vector<u64> acquires CommitteeInfo {
        let committee = borrow_global<CommitteeInfoStore>(address);
        simple_map::keys(&committee.map)
    }

    #[view]
    /// Get the node's information
    public fun get_node_info(id:u64, node_address:address, com_store_address:address): NodeData acquires CommitteeInfo {
        let committee = borrow_global<CommitteeInfo>(node_address);
        // committee.map[id]
    }

    #[view]
    /// Get the committee's id for a single node
    public entry fun get_committee_id_for_node(node_address:address, com_store_address:address):u64 {
        //TODO
    }

    #[view]
    /// Get the dora node peers vector for a single node
    public fun get_peers_for_node(account_address:address, com_store_address:address):vector<NodeData> {
        //TODO
    }

    public entry fun add_committee_member(admin:&signer, node_address:address, id:u64, committee_member:SimpleMap<u64, vector<DoraNodeInfo>>) acquires CommitteeInfo {
        let committee = borrow_global_mut<CommitteeInfo>(node_address);
        verify_admin(admin, committee);
        let committee = borrow_global_mut<CommitteeInfo>(node_address);
        let dora_nodes = find_dora_nodes(id, committee);
        vector::push_back(&mut dora_nodes, committee_member);
        // simple_map::upsert(committee.map, id, committee_member);
        vector::push_back(&mut committee.map[id], committee_member);
        emit_event(
            &mut committee.add_committee_member_event,
            AddCommitteeMemberEvent{id, committee_member})
    }

    //TODO add committee bulk

    ///
    public entry fun remove_committee_member(admin:&signer, id:u64, simple_map:SimpleMap<u64, vector<DoraNodeInfo>>) acquires CommitteeInfo {
        let committee = borrow_global_mut<CommitteeInfo>(node_address);
        verify_admin(admin, committee);
    }

    /// The node can update its information
    /// If the node is not here, report errors
    public entry fun update_node_info(node:&signer, id: u64) {

    }

    fun verify_admin(admin: &signer, committee: &CommitteeInfo) {
        assert!(signer::address_of(admin) == committee.admin, error::unauthenticated(ENOT_ADMIN));
    }

    fun find_dora_nodes(target_id:u64, committee: &CommitteeInfo): vector<DoraNodeInfo> {
        let (ids, dora_nodes) = simple_map::to_vec_pair(committee.map);
        while(vector::length(&ids) > 0) {
            let id = vector::pop_back(&mut ids);
            let dora_nodes = vector::pop_back(&mut dora_nodes);
            if (id == target_id) {
                dora_nodes;
            };
            break
        }
        //TODO what to do if not find?
    }
}
