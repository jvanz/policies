use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Default, Debug)]
#[serde(default)]
pub(crate) struct Settings {
    #[serde(rename = "allowedFlexVolumes")]
    pub(crate) allowed_flex_volumes: Vec<Driver>,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct Driver {
    pub(crate) driver: String,
}

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        Ok(())
    }
}
