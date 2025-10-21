use std::collections::HashSet;

use guest::prelude::*;
use k8s_openapi::api::core::v1 as apicore;
use kubewarden_policy_sdk::wapc_guest as guest;
use lazy_static::lazy_static;
extern crate kubewarden_policy_sdk as kubewarden;
use kubewarden::{logging, protocol_version_guest, request::ValidationRequest, validate_settings};
use slog::{error, o, warn, Logger};

use settings::Settings;
mod settings;

lazy_static! {
    static ref LOG_DRAIN: Logger = Logger::root(
        logging::KubewardenDrain::new(),
        o!("policy" => "priority-class-policy")
    );
}

#[no_mangle]
pub extern "C" fn wapc_init() {
    register_function("validate", validate);
    register_function("validate_settings", validate_settings::<Settings>);
    register_function("protocol_version", protocol_version_guest);
}

fn validate(payload: &[u8]) -> CallResult {
    let validation_request: ValidationRequest<Settings> = ValidationRequest::new(payload)?;
    match validation_request.extract_pod_spec_from_object() {
        Ok(Some(pod_spec)) => {
            match validate_pod_priority_class(
                pod_spec,
                validation_request.settings.allowed_priority_classes,
                validation_request.settings.denied_priority_classes,
            ) {
                Ok(_) => kubewarden::accept_request(),
                Err(err) => kubewarden::reject_request(Some(err.to_owned()), None, None, None),
            }
        }
        Ok(None) => {
            warn!(LOG_DRAIN, "no PodSpec found");
            kubewarden::accept_request()
        }
        Err(err) => {
            error!(LOG_DRAIN, "Priority class policy failed to extract PodSpec from the request"; "err" => %err);
            kubewarden::reject_request(
                Some(format!(
                    "Priority class policy failed to extract PodSpec from the request : {err}"
                )),
                None,
                None,
                None,
            )
        }
    }
}

fn validate_pod_priority_class(
    pod: apicore::PodSpec,
    allowed_priority_classes: HashSet<String>,
    denied_priority_classes: HashSet<String>,
) -> Result<(), String> {
    if pod.priority_class_name.is_none() {
        return Ok(());
    }
    let priority_class_name = pod.priority_class_name.as_ref().unwrap();

    if !denied_priority_classes.is_empty() {
        if denied_priority_classes.contains(priority_class_name) {
            return Err(format!(
                "Priority class \"{priority_class_name}\" is denied"
            ));
        }
    } else if !allowed_priority_classes.contains(priority_class_name) {
        return Err(format!(
            "Priority class \"{priority_class_name}\" is not allowed"
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::validate_pod_priority_class;
    use rstest::rstest;
    use std::collections::HashSet;

    use k8s_openapi::api::core::v1::PodSpec;

    #[rstest]
    #[case(Some("low-priority".to_string()), HashSet::from(["high-priority".to_string(), "low-priority".to_string()]), HashSet::new(), true)]
    #[case(Some("no-priority".to_string()), HashSet::from(["high-priority".to_string(), "low-priority".to_string()]),HashSet::new(), false)]
    #[case(Some("no-priority".to_string()), HashSet::new(), HashSet::from(["high-priority".to_string(), "low-priority".to_string()]), true)]
    #[case(Some("low-priority".to_string()), HashSet::new(), HashSet::from(["high-priority".to_string(), "low-priority".to_string()]), false)]
    #[case(None, HashSet::from(["high-priority".to_string(), "low-priority".to_string()]),HashSet::new(), true)]
    fn test_pod_validation(
        #[case] pod_priority_class: Option<String>,
        #[case] allowed_classes: HashSet<String>,
        #[case] denied_classes: HashSet<String>,
        #[case] should_succeed: bool,
    ) {
        let pod = PodSpec {
            priority_class_name: pod_priority_class,
            ..Default::default()
        };
        let result = validate_pod_priority_class(pod, allowed_classes, denied_classes);
        assert_eq!(result.is_ok(), should_succeed);
    }
}
