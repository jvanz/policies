use serde::{Deserialize, Serialize};
use std::collections::HashSet;

// Describe the settings your policy expects when
// loaded by the policy server.
#[derive(Serialize, Deserialize, Default, Debug)]
#[serde(default)]
pub(crate) struct Settings {
    pub allowed_priority_classes: HashSet<String>,
    pub denied_priority_classes: HashSet<String>,
    pub default_priority_class: Option<String>,
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        if !self.allowed_priority_classes.is_empty() && !self.denied_priority_classes.is_empty() {
            return Err(
                "Both allowed and denied priority class lists cannot be set at the same time"
                    .to_string(),
            );
        }
        if self.allowed_priority_classes.is_empty() && self.denied_priority_classes.is_empty() {
            return Err("The priority class lists cannot be empty".to_string());
        }
        if let Some(default_pc) = &self.default_priority_class {
            if default_pc.is_empty() {
                return Err("The default priority class cannot be an empty string".to_string());
            }
            if !self.allowed_priority_classes.is_empty()
                && !self.allowed_priority_classes.contains(default_pc)
            {
                return Err(format!(
                    "The default priority class '{}' is not in the allowed priority classes list",
                    default_pc
                ));
            }
            if !self.denied_priority_classes.is_empty()
                && self.denied_priority_classes.contains(default_pc)
            {
                return Err(format!(
                    "The default priority class '{}' cannot be defined in the denied priority classes list",
                    default_pc
                ));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kubewarden_policy_sdk::settings::Validatable;

    #[test]
    fn validate_empty_settings() {
        let settings = Settings {
            ..Default::default()
        };
        assert!(settings.validate().is_err());
    }

    #[test]
    fn validate_both_settings() {
        let settings = Settings {
            allowed_priority_classes: HashSet::from([
                "high-priority".to_string(),
                "low-priority".to_string(),
            ]),
            denied_priority_classes: HashSet::from([
                "high-priority".to_string(),
                "low-priority".to_string(),
            ]),
            ..Default::default()
        };
        assert!(settings.validate().is_err());
    }

    #[test]
    fn validate_allowlist_settings() {
        let settings = Settings {
            allowed_priority_classes: HashSet::from([
                "high-priority".to_string(),
                "low-priority".to_string(),
            ]),
            default_priority_class: Some("low-priority".to_string()),
            ..Default::default()
        };
        assert!(settings.validate().is_ok());
    }

    #[test]
    fn validate_denylist_settings() {
        let settings = Settings {
            denied_priority_classes: HashSet::from([
                "high-priority".to_string(),
                "low-priority".to_string(),
            ]),
            ..Default::default()
        };
        assert!(settings.validate().is_ok());
    }

    #[test]
    fn default_priority_class_should_be_in_allowed_list() {
        let settings = Settings {
            allowed_priority_classes: HashSet::from(["high-priority".to_string()]),
            default_priority_class: Some("low-priority".to_string()),
            ..Default::default()
        };
        assert!(settings.validate().is_err());
        assert_eq!(
            settings.validate().unwrap_err(),
            "The default priority class 'low-priority' is not in the allowed priority classes list"
        );
    }

    #[test]
    fn default_priority_class_should_not_be_in_denied_list() {
        let settings = Settings {
            denied_priority_classes: HashSet::from(["high-priority".to_string()]),
            default_priority_class: Some("high-priority".to_string()),
            ..Default::default()
        };
        assert!(settings.validate().is_err());
        assert_eq!(
            settings.validate().unwrap_err(),
            "The default priority class 'high-priority' cannot be defined in the denied priority classes list",
        );
    }

    #[test]
    fn validate_empty_default_priority_class() {
        let settings = Settings {
            denied_priority_classes: HashSet::from(["high-priority".to_string()]),
            default_priority_class: Some("".to_string()),
            ..Default::default()
        };
        assert_eq!(
            settings.validate().expect_err("Missing validation error"),
            "The default priority class cannot be an empty string"
        );
    }
}
