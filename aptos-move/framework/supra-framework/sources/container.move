module supra_framework::container {

    use std::vector;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use supra_framework::system_addresses;

    struct AddressToContainerMap has key, store {
        address_container_map: SimpleMap<address, ContainerMetadata>,
    }

    //TODO: Add more fields for container metadata if needed
    struct ContainerMetadata has copy, drop, store {
        /// The unique identifier of the supra container
        container_indentifier: u64,
        /// The addresses of modules in the container
        Module_adresses: vector<address>,
        /// The address of the customer asset reciver
        customer_asset_reciver: address,
        /// The address of the supra coin reciver
        supra_coin_reciver: address
    }

    /// Initialize the container metadata storage
    public fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        if (!exists<AddressToContainerMap>(@supra_framework)) {
            move_to<AddressToContainerMap>(
                supra_framework,
                AddressToContainerMap {
                    address_container_map: simple_map::new(),
                }
            );
        }
    }

    /// Add a new container metadata to the storage
    public fun AddContainerMetadata(supra_framework: &signer, address: address, container_metadata: ContainerMetadata) acquires AddressToContainerMap {
        system_addresses::assert_supra_framework(supra_framework);
        let container = borrow_global_mut<AddressToContainerMap>(@supra_framework);
        simple_map::upsert(&mut container.address_container_map, address, container_metadata);
    }

    /// Add one module address to the container metadata
    public fun AddModuleToContainer(supra_framework: &signer, address: address, module_address: address) acquires AddressToContainerMap {
        system_addresses::assert_supra_framework(supra_framework);
        assert(exists<AddressToContainerMap>(@supra_framework), 1);
        let container = borrow_global_mut<AddressToContainerMap>(@supra_framework);
        let container_metadata = simple_map::borrow_mut(&mut container.address_container_map, &address);
        vector::insert(container_metadata.Module_adresses, module_address);
    }

    #[view]
    public fun GetContainerMetadata(supra_framework: &signer, address: address): ContainerMetadata acquires AddressToContainerMap {
        system_addresses::assert_supra_framework(supra_framework);
        assert(exists<AddressToContainerMap>(address), 1);
        let container = borrow_global<AddressToContainerMap>(@supra_framework);
        *simple_map::borrow(&container.address_container_map, &address)
    }

    public fun UpdateContainerMetadata(supra_framework: &signer, address: address, container_metadata: ContainerMetadata) acquires ContainerMetadata {
        system_addresses::assert_supra_framework(supra_framework);
        let container_metadata = borrow_global_mut<ContainerMetadata>(address);
        //DO IT in a nicer way
        *container_metadata = container_metadata;
    }
}
