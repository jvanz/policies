# Unique ingress host

This is a Gatekeeper policy that prevents the creation of Ingress resources
with duplicated hosts.

The policy is a 1:1 copy of [this one](https://open-policy-agent.github.io/gatekeeper-library/website/validation/uniqueingresshost/),
it's meant to show how Kubewarden supports Gatekeeper policies that make use of
context aware data (also called
["replicating data"](https://open-policy-agent.github.io/gatekeeper/website/docs/sync/)
by Gatekeeper).
