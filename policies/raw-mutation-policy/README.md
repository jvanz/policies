# Kubewarden policy raw-mutation-policy

## Description

This is a waPC test policy that mutates raw requests.

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

## Settings

This policy has no configurable settings.
