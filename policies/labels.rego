# ──────────────────────────────────────────────────────────────
# Policy: Mandatory Labels
# ──────────────────────────────────────────────────────────────
# Ensures all Kubernetes resources include the required
# 'cost-center' label for billing, governance, and tracking.
# ──────────────────────────────────────────────────────────────
package main

# ── Deny Deployments missing cost-center label ──
deny[msg] {
    input.kind == "Deployment"
    not input.metadata.labels["cost-center"]
    msg := sprintf(
        "LABEL VIOLATION: Deployment '%s' is missing the mandatory 'cost-center' label in metadata.labels. All resources must include a cost-center label for billing purposes.",
        [input.metadata.name]
    )
}

# ── Deny Services missing cost-center label ──
deny[msg] {
    input.kind == "Service"
    not input.metadata.labels["cost-center"]
    msg := sprintf(
        "LABEL VIOLATION: Service '%s' is missing the mandatory 'cost-center' label in metadata.labels. All resources must include a cost-center label for billing purposes.",
        [input.metadata.name]
    )
}

# ── Deny Namespaces missing cost-center label ──
deny[msg] {
    input.kind == "Namespace"
    not input.metadata.labels["cost-center"]
    msg := sprintf(
        "LABEL VIOLATION: Namespace '%s' is missing the mandatory 'cost-center' label in metadata.labels. All resources must include a cost-center label for billing purposes.",
        [input.metadata.name]
    )
}

# ── Deny Pods missing cost-center label ──
deny[msg] {
    input.kind == "Pod"
    not input.metadata.labels["cost-center"]
    msg := sprintf(
        "LABEL VIOLATION: Pod '%s' is missing the mandatory 'cost-center' label in metadata.labels. All resources must include a cost-center label for billing purposes.",
        [input.metadata.name]
    )
}
