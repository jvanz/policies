[![Kubewarden Policy Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-policies.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#policy-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

> This is a policy that demonstrates the new context aware feature of Kubewarden
> (available since release 1.6.0)
>
> ⚠️ Being a showcase policy, there's a little surprise inside of the codebase.
> Keep reading till the end.

This policy propagates a list of annotations from a Kubernetes Namespace to 
become labels of all the Pods that are created under it.

The Namespace annotations that begin with the `propagate.` prefix are then
applied to all the Pods created inside of the Namespace. Pod labels are
created without the `propagate.` prefix.

## Example

Assuming the `test` Namespace has the following annotations:

* `propagate.hello` with value `world`
* `cost-center` with value `123-a`

When a Pod is created inside of the `test` Namespace, the following labels
are going to be added to it:

* `hello` with value `world`

## Security demo

For security reasons, context aware policies must declare what kind of
Kubernetes resources they are going to access.

Kubernetes operators have to review the list of accessed resources and
use that to:

1. Ensure the policy does not access resources that are not related with its
  core business
2. Use this information to fill the `contextAwareResources` field of the
  `ClusterAdmissionPolicy` resource that enforces the policy

This policy declares it needs to access only to Kubernetes Pod resources.
However, something changes when the policy is ran with the following
settings:

```yaml
evil: true
```

The policy will try to access Kubernetes Secret objects. This is done to
demonstrate how the Kubewarden runtime is able to detect this behavior
and prevent the policy to access resources it cannot read.

This can be demoed using the kwctl command:

```console
kwctl run --allow-context-aware \
  --request-path test_data/pod_creation_mising_labels.json \
  --settings-json '{"evil": true}' \
  annotated-policy.wasm
```

This produces an output similar to the following one:

```console
2023-03-16T13:25:21.262572Z  WARN kwctl::run: Policy has been granted access to the Kubernetes resources mentioned by its metadata
2023-03-16T13:25:21.263227Z  WARN kwctl::run: The loaded kubeconfig connects to a server using an IP address instead of a FQDN. This is usually done by minikube, k3d and other local development solutions host="0.0.0.0"
2023-03-16T13:25:21.263261Z  WARN kwctl::run: Due to a limitation of rustls, certificate validation cannot be performed against IP addresses, the certificate validation will be made against `kubernetes.default.svc`
🦹: going to steal secrets
2023-03-16T13:25:21.341578Z ERROR policy_evaluator::runtimes::wapc: Policy tried to access a Kubernetes resource it doesn't have access to policy="context-aware-policy" resource_requested="v1/Secret" resources_allowed={ContextAwareResource { api_version: "v1", kind: "Namespace" }}
{"uid":"1299d386-525b-4032-98ae-1949f69f9cfc","allowed":true,"patchType":"JSONPatch","patch":"W3sib3AiOiJhZGQiLCJwYXRoIjoiL21ldGFkYXRhL2xhYmVscyIsInZhbHVlIjp7ImhlbGxvIjoid29ybGQifX0seyJvcCI6ImFkZCIsInBhdGgiOiIvYXBpVmVyc2lvbiIsInZhbHVlIjoidjEifSx7Im9wIjoiYWRkIiwicGF0aCI6Ii9raW5kIiwidmFsdWUiOiJQb2QifV0=","auditAnnotations":null,"warnings":null}
```

As you can see the policy tried to access a Kubernetes Secret, but kwctl blocked
that attempt and reported it back to the user.

The final outcome of the policy evaluation is still a success. That's because
the policy silently hid the error, hoping its misbehaviour would go unnoticed.
