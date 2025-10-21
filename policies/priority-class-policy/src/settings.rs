use serde::{Deserialize, Serialize};
use std::collections::HashSet;

// Describe the settings your policy expects when
// loaded by the policy server.
#[derive(Serialize, Deserialize, Default, Debug)]
#[serde(default)]
pub(crate) struct Settings {
    pub allowed_priority_classes: HashSet<String>,
    pub denied_priority_classes: HashSet<String>,
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        if !self.allowed_priority_classes.is_empty() && !self.denied_priority_classes.is_empty() {
            return Err(
                "Both allowed and denied priority calls lists cannot be set at the same time"
                    .to_string(),
            );
        }
        if self.allowed_priority_classes.is_empty() && self.denied_priority_classes.is_empty() {
            return Err("The priority class lists cannot be empty".to_string());
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
}
