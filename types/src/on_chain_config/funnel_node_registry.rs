use crate::account_config::CORE_CODE_ADDRESS;
use move_core_types::value::{serialize_values, MoveStruct, MoveValue};
use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct FunnelNodeRegistryConfig {
    funnel_nodes: Vec<Url>,
}

impl FunnelNodeRegistryConfig {
    pub fn new(funnel_nodes: Vec<Url>) -> Self {
        Self { funnel_nodes }
    }

    pub fn serialize_into_move_values(&self) -> Vec<Vec<u8>> {
        let funnel_nodes_vec_move_value: Vec<MoveValue> = self
            .funnel_nodes
            .iter()
            .map(|node_endpoint_url| {
                MoveValue::Struct(MoveStruct::new(vec![MoveValue::vector_u8(
                    node_endpoint_url.to_string().into_bytes(),
                )]))
            })
            .collect();
        let arguments = vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Vector(funnel_nodes_vec_move_value),
        ];
        serialize_values(&arguments)
    }
}
