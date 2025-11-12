use crate::account_config::CORE_CODE_ADDRESS;
use move_core_types::value::{serialize_values, MoveStruct, MoveValue};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct FunnelNodeRegistryConfig {
    funnel_nodes: Vec<SocketAddr>,
}

impl FunnelNodeRegistryConfig {
    pub fn new(funnel_nodes: Vec<SocketAddr>) -> Self {
        Self { funnel_nodes }
    }

    pub fn serialize_into_move_values(&self) -> Vec<Vec<u8>> {
        let funnel_nodes_vec_move_value = self
            .funnel_nodes
            .iter()
            .map(|node_socket_addr| {
                MoveValue::Struct(MoveStruct::new(vec![MoveValue::vector_u8(
                    node_socket_addr.to_string().into_bytes(),
                )]))
            })
            .collect::<Vec<MoveValue>>();
        let arguments = vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Vector(funnel_nodes_vec_move_value),
        ];
        serialize_values(&arguments)
    }
}
