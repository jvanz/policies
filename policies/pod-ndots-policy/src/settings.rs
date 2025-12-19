use serde::{Deserialize, Serialize};

// Describe the settings your policy expects when
// loaded by the policy server.
#[derive(Serialize, Deserialize, Default, Debug, Clone)]
pub(crate) struct Settings {
    #[serde(default = "default_ndots")]
    pub ndots: usize,
}

fn default_ndots() -> usize {
    1
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        Ok(())
    }
}
