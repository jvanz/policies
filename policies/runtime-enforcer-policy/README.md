[![Kubewarden Policy Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-policies.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#policy-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

## Runtime-enforcer policy

This policy is designed to enforce constraints on runtime enforcer. This
enforces that workload can only be deployed when its runtime enforcer
policy specified via "security.rancher.io/policy" label.

## Configuration

Currently there is no configurable options at this time.

## Behavior

This policy checks the container label of supported workloads to see if
a runtime-enforcer policy is specified:

- Pod
- ReplicaSet
- Deployment
- StatefulSet
- DaemonSet
- Job
- CronJob

## Deployment

This policy requires extra permission to read WorkloadPolicy resource of
runtime-enforcer.  Before deploying this policy, update the policy
server's permission to include security.rancher.io workloadpolicies. 

```
policyServer:
  permissions:
    # Make sure that you keep the existing permissions, then add the
    # below resource:
    - apiGroup: "security.rancher.io"
      resources:
        - workloadpolicies
```

Deploy the policy as a `ClusterAdmissionPolicy` with the `contextAwareResources`
field properly set. Use the following command to scaffold the policy:

```console
kwctl scaffold manifest --type ClusterAdmissionPolicy --allow-context-aware <policy name>
```
