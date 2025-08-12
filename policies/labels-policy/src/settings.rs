use std::collections::HashSet;

use criteria_policy_base::{kubewarden_policy_sdk as kubewarden, settings::BaseSettings};
use regex::Regex;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub(crate) struct Settings(pub(crate) BaseSettings);

// It's not possible to use the Default in the derive macro because we cannot
// set a #[default] attribute to enum item that is no unit enums.
impl Default for Settings {
    fn default() -> Self {
        Settings(BaseSettings::ContainsAnyOf {
            values: HashSet::new(),
        })
    }
}

// Regex used to validate the labels name:
// - Optional DNS subdomain prefix (lowercase, digits, '-', '.'), ending with '/'
// - Name segment: 1-63 chars, starts/ends with alphanumeric, allows '-', '_', '.' in between, case-insensitive for the name segment as per Kubernetes spec.
const LABELS_NAME_REGEX: &str = r"^([a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*/)?[a-zA-Z0-9]([a-zA-Z0-9_.-]{0,61}[a-zA-Z0-9])?$";

impl kubewarden::settings::Validatable for Settings {
    fn validate(&self) -> Result<(), String> {
        // this will fail if the annotations key list is empty
        self.0.validate()?;

        let labels = self.0.values();

        // Validate that the annotations names are valid.
        let labels_name_regex = Regex::new(LABELS_NAME_REGEX).unwrap();
        let invalid_label: Vec<String> = labels
            .iter()
            .filter_map(|label| {
                //     // Check total length
                //     if label.len() > 253 {
                //         return Some(format!("{label} (key too long)"));
                //     }
                //     if labels_name_regex.is_match(label) {
                //         return None;
                //     }
                //     Some(label.to_string())
                // })
                // .collect();

                if let Some(idx) = label.rfind('/') {
                    let (prefix, name) = label.split_at(idx);
                    let name = &name[1..]; // skip the '/'
                    if prefix.len() > 253 {
                        return Some(format!("{label} (prefix too long)"));
                    }
                    if name.len() > 63 {
                        return Some(format!("{label} (name too long)"));
                    }
                    if label.len() > 253 {
                        return Some(format!("{label} (key too long)"));
                    }
                } else if label.len() > 63 {
                    return Some(format!("{label} (name too long)"));
                }
                if !labels_name_regex.is_match(label) {
                    return Some(label.to_string());
                }
                None
            })
            .collect();

        if !invalid_label.is_empty() {
            return Err(format!(
                "Invalid annotation names: {}",
                invalid_label.join(", "),
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use kubewarden::settings::Validatable;
    use rstest::rstest;

    #[rstest]
    // Valid label keys
    #[case::valid_simple(vec!["my-label".to_string()], true)]
    #[case::valid_dot(vec!["my.label".to_string()], true)]
    #[case::valid_underscore(vec!["my_label".to_string()], true)]
    #[case::valid_dns_prefix(vec!["example.com/my-label".to_string()], true)]
    #[case::valid_multiple_prefix(vec!["foo.bar.baz/qux".to_string()], true)]
    #[case::valid_short(vec!["a/b".to_string()], true)]
    #[case::valid_alphanumeric(vec!["abc123".to_string()], true)]
    #[case::valid_max_length(vec![format!("{}","a".repeat(243) + "/b")], true)]
    #[case::valid_prefix_max_length(vec![format!("{}.com/abc", "a".repeat(243))], true)]
    #[case::valid_mixed(vec!["abc.def-ghi_jkl".to_string()], true)]
    // Invalid label keys
    #[case::invalid_empty(vec!["".to_string()], false)]
    #[case::invalid_leading_slash(vec!["/my-label".to_string()], false)]
    #[case::invalid_missing_key(vec!["example.com/".to_string()], false)]
    #[case::invalid_leading_dash(vec!["-my-label".to_string()], false)]
    #[case::invalid_prefix_leading_dash(vec!["example.com/-my-label".to_string()], false)]
    #[case::invalid_trailing_dash(vec!["example.com/my-label-".to_string()], false)]
    #[case::invalid_space(vec!["example.com/my label".to_string()], false)]
    #[case::invalid_at_symbol(vec!["example.com/my@label".to_string()], false)]
    #[case::invalid_uppercase_prefix(vec!["Example.com/my-label".to_string()], false)]
    #[case::invalid_double_dot_prefix(vec!["example..com/my-label".to_string()], false)]
    #[case::invalid_name_too_long(vec![format!("a{}", "b".repeat(63))], false)]
    #[case::invalid_prefix_too_long(vec![format!("{}.com/abc", "a".repeat(254))], false)]
    fn test_validation(#[case] variables: Vec<String>, #[case] is_ok: bool) {
        let settings = Settings(BaseSettings::ContainsAllOf {
            values: variables
                .iter()
                .map(|v| v.to_string())
                .collect::<HashSet<String>>(),
        });
        assert_eq!(settings.validate().is_ok(), is_ok);
    }
}
