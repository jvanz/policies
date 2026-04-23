use guest::prelude::*;
use kubewarden_policy_sdk::wapc_guest as guest;

use k8s_openapi::api::core::v1::Namespace;

extern crate kubewarden_policy_sdk as kubewarden;
use kubewarden::{
    host_capabilities::kubernetes::GetResourceRequest, protocol_version_guest,
    request::ValidationRequest, validate_settings,
};

#[cfg(test)]
use crate::tests::mock_kubernetes_sdk::get_resource;
#[cfg(not(test))]
use kubewarden::host_capabilities::kubernetes::get_resource;

mod settings;
use settings::Settings;

const POLICY_SERVER_LABEL: &str = "admission.kubewarden.io/policy-server";

#[unsafe(no_mangle)]
pub extern "C" fn wapc_init() {
    register_function("validate", validate);
    register_function("validate_settings", validate_settings::<Settings>);
    register_function("protocol_version", protocol_version_guest);
}

fn validate(payload: &[u8]) -> CallResult {
    let validation_request: ValidationRequest<Settings> = ValidationRequest::new(payload)?;
    let namespace_name = validation_request.request.namespace.clone();

    let kube_request = GetResourceRequest {
        name: namespace_name.clone(),
        api_version: "v1".to_string(),
        kind: "Namespace".to_string(),
        field_masks: None,
        namespace: None,
        disable_cache: false,
    };

    let namespace: Namespace = get_resource(&kube_request)?;

    let policy_server = namespace
        .metadata
        .labels
        .as_ref()
        .and_then(|labels| labels.get(POLICY_SERVER_LABEL))
        .cloned();

    match policy_server {
        Some(ps) => {
            let mut object = validation_request.request.object.clone();
            let spec = object
                .get_mut("spec")
                .and_then(|v| v.as_object_mut())
                .ok_or_else(|| anyhow::anyhow!("object has no 'spec' field or it is not a map"))?;
            spec.insert("policyServer".to_string(), serde_json::Value::String(ps));
            kubewarden::mutate_request(object)
        }
        None => kubewarden::reject_request(
            Some(format!(
                "Namespace '{namespace_name}' has no '{POLICY_SERVER_LABEL}' label; \
                 cannot determine the PolicyServer for the policy"
            )),
            None,
            None,
            None,
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use k8s_openapi::apimachinery::pkg::apis::meta::v1::ObjectMeta;
    use kubewarden::{request::KubernetesAdmissionRequest, response::ValidationResponse};
    use mockall::automock;
    use serde_json::json;
    use serial_test::serial;
    use std::collections::BTreeMap;

    #[automock]
    pub mod kubernetes_sdk {
        use kubewarden::host_capabilities::kubernetes::GetResourceRequest;

        #[allow(dead_code)]
        pub fn get_resource<T: 'static>(_req: &GetResourceRequest) -> anyhow::Result<T> {
            Err(anyhow::anyhow!("not mocked"))
        }
    }

    fn make_payload(namespace: &str, current_ps: &str) -> String {
        let object = json!({
            "apiVersion": "policies.kubewarden.io/v1",
            "kind": "AdmissionPolicy",
            "metadata": { "name": "test-policy", "namespace": namespace },
            "spec": { "policyServer": current_ps },
        });
        let request = KubernetesAdmissionRequest {
            namespace: namespace.to_string(),
            object,
            ..Default::default()
        };
        let vr = ValidationRequest::<Settings> {
            settings: Settings::default(),
            request,
        };
        serde_json::to_string(&vr).unwrap()
    }

    fn make_namespace(name: &str, labels: Option<BTreeMap<String, String>>) -> Namespace {
        Namespace {
            metadata: ObjectMeta {
                name: Some(name.to_string()),
                labels,
                ..Default::default()
            },
            ..Default::default()
        }
    }

    #[test]
    #[serial]
    fn mutates_policy_server_from_namespace_label() {
        let namespace_name = "team-a";
        let expected_ps = "policyserver-team-a";

        let ns = make_namespace(
            namespace_name,
            Some(BTreeMap::from([(
                POLICY_SERVER_LABEL.to_string(),
                expected_ps.to_string(),
            )])),
        );

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        let payload = make_payload(namespace_name, "old-ps");
        let response = validate(payload.as_bytes());
        assert!(response.is_ok());
        let vr: ValidationResponse = serde_json::from_slice(&response.unwrap()).unwrap();
        assert!(vr.accepted);
        let mutated = vr.mutated_object.expect("should have mutated object");
        assert_eq!(mutated["spec"]["policyServer"], expected_ps);
    }

    #[test]
    #[serial]
    fn rejects_when_namespace_label_is_absent() {
        let namespace_name = "unlabeled-ns";

        let ns = make_namespace(namespace_name, None);

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        let payload = make_payload(namespace_name, "some-ps");
        let response = validate(payload.as_bytes());
        assert!(response.is_ok());
        let vr: ValidationResponse = serde_json::from_slice(&response.unwrap()).unwrap();
        assert!(!vr.accepted);
        assert!(vr.message.unwrap_or_default().contains(POLICY_SERVER_LABEL));
    }

    #[test]
    #[serial]
    fn errors_when_object_has_no_spec() {
        let namespace_name = "team-a";
        let expected_ps = "policyserver-team-a";

        let ns = make_namespace(
            namespace_name,
            Some(BTreeMap::from([(
                POLICY_SERVER_LABEL.to_string(),
                expected_ps.to_string(),
            )])),
        );

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        // Build a payload whose object has no "spec" field
        let object = json!({
            "apiVersion": "policies.kubewarden.io/v1",
            "kind": "AdmissionPolicy",
            "metadata": { "name": "test-policy", "namespace": namespace_name },
        });
        let request = KubernetesAdmissionRequest {
            namespace: namespace_name.to_string(),
            object,
            ..Default::default()
        };
        let vr = ValidationRequest::<Settings> {
            settings: Settings::default(),
            request,
        };
        let payload = serde_json::to_string(&vr).unwrap();

        let response = validate(payload.as_bytes());
        assert!(response.is_err(), "expected an error when spec is missing");
    }

    #[test]
    #[serial]
    fn mutates_policy_server_when_spec_exists_but_has_no_policy_server_field() {
        let namespace_name = "team-a";
        let expected_ps = "policyserver-team-a";

        let ns = make_namespace(
            namespace_name,
            Some(BTreeMap::from([(
                POLICY_SERVER_LABEL.to_string(),
                expected_ps.to_string(),
            )])),
        );

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        // Build a payload whose "spec" exists but has no "policyServer" key
        let object = json!({
            "apiVersion": "policies.kubewarden.io/v1",
            "kind": "AdmissionPolicy",
            "metadata": { "name": "test-policy", "namespace": namespace_name },
            "spec": { "module": "registry://some-module" },
        });
        let request = KubernetesAdmissionRequest {
            namespace: namespace_name.to_string(),
            object,
            ..Default::default()
        };
        let vr = ValidationRequest::<Settings> {
            settings: Settings::default(),
            request,
        };
        let payload = serde_json::to_string(&vr).unwrap();

        let response = validate(payload.as_bytes());
        assert!(response.is_ok());
        let vr: ValidationResponse = serde_json::from_slice(&response.unwrap()).unwrap();
        assert!(vr.accepted);
        let mutated = vr.mutated_object.expect("should have mutated object");
        assert_eq!(mutated["spec"]["policyServer"], expected_ps);
        // pre-existing spec fields should be preserved
        assert_eq!(mutated["spec"]["module"], "registry://some-module");
    }

    #[test]
    #[serial]
    fn errors_when_object_spec_is_not_a_map() {
        let namespace_name = "team-a";
        let expected_ps = "policyserver-team-a";

        let ns = make_namespace(
            namespace_name,
            Some(BTreeMap::from([(
                POLICY_SERVER_LABEL.to_string(),
                expected_ps.to_string(),
            )])),
        );

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        // Build a payload whose "spec" is a scalar, not a map
        let object = json!({
            "apiVersion": "policies.kubewarden.io/v1",
            "kind": "AdmissionPolicy",
            "metadata": { "name": "test-policy", "namespace": namespace_name },
            "spec": "not-a-map",
        });
        let request = KubernetesAdmissionRequest {
            namespace: namespace_name.to_string(),
            object,
            ..Default::default()
        };
        let vr = ValidationRequest::<Settings> {
            settings: Settings::default(),
            request,
        };
        let payload = serde_json::to_string(&vr).unwrap();

        let response = validate(payload.as_bytes());
        assert!(
            response.is_err(),
            "expected an error when spec is not a map"
        );
    }

    #[test]
    #[serial]
    fn rejects_when_namespace_has_other_labels_but_not_policy_server() {
        let namespace_name = "other-labels-ns";

        let ns = make_namespace(
            namespace_name,
            Some(BTreeMap::from([(
                "some-other-label".to_string(),
                "some-value".to_string(),
            )])),
        );

        let ctx = mock_kubernetes_sdk::get_resource_context();
        ctx.expect::<Namespace>()
            .times(1)
            .returning(move |_| Ok(ns.clone()));

        let payload = make_payload(namespace_name, "some-ps");
        let response = validate(payload.as_bytes());
        assert!(response.is_ok());
        let vr: ValidationResponse = serde_json::from_slice(&response.unwrap()).unwrap();
        assert!(!vr.accepted);
    }
}
