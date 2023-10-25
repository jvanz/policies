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

The policy mutates the resource to `"hay"` if the resource is `"banana"`.
It rejects requests only if the payload is not in the expected format.

## Settings

This policy has no configurable settings.
