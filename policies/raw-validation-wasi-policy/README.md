[![Kubewarden Policy Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-policies.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#policy-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

# Kubewarden policy raw-validation-wasi-policy

## Description

This is a WASI test policy that validates raw requests.

The policy accepts requests in the following format:

```json
{
  "request": {
    "user": "tonio"
    "action": "eats",
    "resource": "hay",
  }
}
```

and validates that:

- `user` is in the list of valid users
- `action` is in the list of valid actions
- `resource` is in the list of valid resources

## Settings

This policy has configurable settings:

- `validUsers`: a list of valid users. Cannot be empty.
- `validActions`: a list of valid actions.Cannot be empty.
- `validResources`: a list of valid resources. Cannot be empty.
