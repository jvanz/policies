# Open Policy Agent utility

This folder contains the entry point for Open Policy Agent policies.

Since Open Policy Agent policies have to produce a `RawReviewResponse`
object, this utility library contains the Rego entry point that
generates such `RawReviewResponse`, based on whether the `deny` query
inside the package `validation` (defined by the policy
itself) is evaluated to `true`.

If `deny` evaluates to true, the produced `RawReviewResponse` will
reject the request. Otherwise, it will be accepted.
