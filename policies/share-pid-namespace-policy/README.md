# share-pid-namespace-policy

This policy will reject pods that have pod configured to share process namespace.
In other words, this policy rejects Pod that have `spec.shareProcessNamespace` set to `true`. 

## Settings

This policy has no configurable settings. 

## Example

Considering the policy applied with the following definition:

```yaml
apiVersion: policies.kubewarden.io/v1
kind: ClusterAdmissionPolicy
metadata:
  annotations:
    io.kubewarden.policy.category: Resource validation
    io.kubewarden.policy.severity: medium
  name: share-pid-namespace-policy
spec:
  module: ghcr.io/kubewarden/policies/share-pid-namespace-policy:v0.1.0
  settings: {}
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    operations: ["CREATE"]
  - apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["replicationcontrollers"]
    operations: ["CREATE", "UPDATE"]
  - apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources:  [ "deployments", "replicasets", "statefulsets", "daemonsets" ]
    operations: ["CREATE", "UPDATE"]
  - apiGroups: ["batch"]
    apiVersions: ["v1"]
    resources:["jobs", "cronjobs ]
    operations: ["CREATE", "UPDATE"]
  mutating: false
  ```

Pods with the `shareProcessNamespace` will be rejected:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  shareProcessNamespace: true
  containers:
  - name: nginx
    image: nginx:1.14.2
    ports:
    - containerPort: 80
```
