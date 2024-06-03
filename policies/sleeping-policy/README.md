[![Kubewarden Policy Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-policies.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#policy-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

**WARNING:** this policy is meant for testing purposes only. Regular Kubewarden
users **should not use it!!!**

# Kubewarden policy sleeping-policy

## Description

This policy simulates a policy that takes a long time to evaluate an incoming request.
The policy will sleep for a user defined interval and then it will accept the request.

The purpose of this policy is to test Kubewarden's protection mechanisms against
policies that are taking a long time to be evaluated.

## Settings

This policy has just one mandatory setting:

* `sleepMilliseconds`: the amount of time the policy will wait before accepting
  the request. Expressed in milliseconds.

The value provided inside of the settings can be overridden by adding a special
annotation to the resource being evaluated.

The annotation name is `kubewarden.sleep_duration_milliseconds` had takes the
number of milliseconds to sleep as value.

For example, the following object will cause the policy to sleep 8 seconds:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  annotations:
    kubewarden.sleep_duration_milliseconds: 8000
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    ports:
    - containerPort: 80
```
