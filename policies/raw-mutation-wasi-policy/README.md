# Kubewarden policy raw-mutation-wasi-policy

## Description

This is a WASI test policy that mutates raw requests.

The policy accepts requests in the following format:

```json
{
  "request": {
    "user": "tonio"
    "action": "eats",
    "resource": "banana",
  }
}
```

The policy mutates the resource to the default resource `"hay"` if the resource is contained in the list of forbidden resources.

## Settings

This policy has configurable settings:

- `forbiddenResources`: a list of resources that cannot be accessed by the user.
