# ──────────────────────────────────────────────────────────────
# Policy: Resource Limits Enforcement
# ──────────────────────────────────────────────────────────────
# Ensures every container defines both resource requests and
# limits for CPU and Memory. Prevents resource exhaustion
# attacks and noisy-neighbor problems in shared clusters.
# ──────────────────────────────────────────────────────────────
package main

# ── Deny Deployments without resource requests ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.requests. Both requests and limits must be specified.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Deployments without resource limits ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.limits. Both requests and limits must be specified.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Deployments without CPU requests ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.resources.requests
    not container.resources.requests.cpu
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.requests.cpu.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Deployments without Memory requests ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.resources.requests
    not container.resources.requests.memory
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.requests.memory.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Deployments without CPU limits ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.resources.limits
    not container.resources.limits.cpu
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.limits.cpu.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Deployments without Memory limits ──
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.resources.limits
    not container.resources.limits.memory
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Deployment '%s' does not define resources.limits.memory.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Pods without resource requests ──
deny[msg] {
    input.kind == "Pod"
    container := input.spec.containers[_]
    not container.resources.requests
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Pod '%s' does not define resources.requests.",
        [container.name, input.metadata.name]
    )
}

# ── Deny Pods without resource limits ──
deny[msg] {
    input.kind == "Pod"
    container := input.spec.containers[_]
    not container.resources.limits
    msg := sprintf(
        "RESOURCE VIOLATION: Container '%s' in Pod '%s' does not define resources.limits.",
        [container.name, input.metadata.name]
    )
}
