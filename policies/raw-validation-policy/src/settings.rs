use crate::LOG_DRAIN;

use serde::{Deserialize, Serialize};
use slog::info;

// Describe the settings your policy expects when
// loaded by the policy server.
#[derive(Serialize, Deserialize, Default, Debug)]
#[serde(default, rename_all = "camelCase")]
pub(crate) struct Settings {
    pub(crate) valid_users: Vec<String>,
    pub(crate) valid_actions: Vec<String>,
    pub(crate) valid_resources: Vec<String>,
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        info!(LOG_DRAIN, "starting settings validation");

        if self.valid_users.is_empty() {
            return Err("valid_users cannot be empty".to_string());
        }

        if self.valid_actions.is_empty() {
            return Err("valid_actions cannot be empty".to_string());
        }

        if self.valid_resources.is_empty() {
            return Err("valid_resources cannot be empty".to_string());
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kubewarden_policy_sdk::settings::Validatable;

    #[test]
    fn validate_settings() {
        let settings = Settings {
            valid_users: vec!["tonio".to_string(), "wanda".to_string()],
            valid_actions: vec!["eats".to_string(), "likes".to_string()],
            valid_resources: vec!["banana".to_string(), "hay".to_string()],
        };

        assert!(settings.validate().is_ok());
    }

    #[test]
    fn reject_settings() {
        let settings = Settings {
            valid_users: vec![],
            valid_actions: vec![],
            valid_resources: vec![],
        };

        assert!(settings.validate().is_err());
    }
}
