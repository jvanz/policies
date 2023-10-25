use serde::Deserialize;

use crate::settings::Settings;

#[derive(Deserialize)]
pub(crate) struct RawValidationRequest {
    pub(crate) request: Request,
    pub(crate) settings: Settings,
}

#[derive(Deserialize)]
pub(crate) struct Request {
    pub(crate) user: String,
    pub(crate) resource: String,
    pub(crate) action: String,
}
