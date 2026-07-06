# ──────────────────────────────────────────────────────────────
# Policy: Registry Restriction
# ──────────────────────────────────────────────────────────────
# Ensures all container images originate from the trusted
# corporate registry. Prevents supply-chain attacks by blocking
# images from untrusted sources (Docker Hub, quay.io, etc.).
# ──────────────────────────────────────────────────────────────
package main

import future.keywords.in

# Trusted registry prefix
trusted_registry := "trusted-registry.company.com/"

# ── Deny Deployments with untrusted images ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not startswith(container.image, trusted_registry)
    msg := sprintf(
        "REGISTRY VIOLATION: Container '%s' uses untrusted image '%s'. All images must originate from '%s'.",
        [container.name, container.image, trusted_registry]
    )
}

# ── Deny Pods with untrusted images ──
deny[msg] {
    input.kind == "Pod"
    container := input.spec.containers[_]
    not startswith(container.image, trusted_registry)
    msg := sprintf(
        "REGISTRY VIOLATION: Container '%s' uses untrusted image '%s'. All images must originate from '%s'.",
        [container.name, container.image, trusted_registry]
    )
}

# ── Also check init containers ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.initContainers[_]
    not startswith(container.image, trusted_registry)
    msg := sprintf(
        "REGISTRY VIOLATION: Init container '%s' uses untrusted image '%s'. All images must originate from '%s'.",
        [container.name, container.image, trusted_registry]
    )
}
