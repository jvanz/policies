use k8s_openapi::api::{
    admissionregistration::v1::ServiceReference, networking::v1::IngressServiceBackend,
};

/// This struct represents the details of a service.
///
/// We cannot use types from k8s_openapi because they cannot be used
/// inside of a HashSet due to missing traits
///
/// Note: `port_name` is not being tracked, since this is not used by
/// the ServiceReference struct used inside of (Validating|Mutating)WebhookConfiguration
#[derive(Debug, Default, Hash, Eq, PartialEq, Clone)]
pub(crate) struct ServiceDetails {
    pub name: String,
    pub namespace: String,
    pub port_number: Option<i32>,
}

impl From<ServiceReference> for ServiceDetails {
    fn from(service_reference: ServiceReference) -> Self {
        ServiceDetails {
            name: service_reference.name,
            namespace: service_reference.namespace,
            port_number: service_reference.port,
        }
    }
}

impl From<&ServiceReference> for ServiceDetails {
    fn from(service_reference: &ServiceReference) -> Self {
        ServiceDetails {
            name: service_reference.name.clone(),
            namespace: service_reference.namespace.clone(),
            port_number: service_reference.port,
        }
    }
}

impl ServiceDetails {
    pub(crate) fn from_service_backend(
        namespace: &str,
        service_backend: &IngressServiceBackend,
    ) -> Self {
        ServiceDetails {
            name: service_backend.name.clone(),
            namespace: namespace.to_string(),
            port_number: service_backend.port.as_ref().and_then(|port| port.number),
        }
    }
}
