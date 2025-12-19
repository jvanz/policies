use serde::{Deserialize, Serialize};

// Describe the settings your policy expects when
// loaded by the policy server.
#[derive(Serialize, Deserialize, Default, Debug)]
#[serde(default, rename_all = "camelCase")]
pub(crate) struct Settings {
    pub sleep_milliseconds: u64,
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        if self.sleep_milliseconds > 0 {
            Ok(())
        } else {
            Err("sleep_milliseconds must be set and be major than 0".to_string())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rstest::*;

    use kubewarden_policy_sdk::settings::Validatable;

    #[rstest]
    #[case(0, false)]
    #[case(1, true)]
    fn validate_settings(#[case] sleep_milliseconds: u64, #[case] is_valid: bool) {
        let settings = Settings { sleep_milliseconds };

        assert_eq!(is_valid, settings.validate().is_ok());
    }
}
