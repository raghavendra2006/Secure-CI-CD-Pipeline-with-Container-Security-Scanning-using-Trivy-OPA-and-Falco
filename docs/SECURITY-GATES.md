# Security Gates Reference Guide

This document provides a detailed explanation of each security gate in the DevSecOps pipeline, including configuration, severity thresholds, and remediation guidance.

---

## Gate Overview

| # | Gate | Tool | Target | Fail Condition |
|---|------|------|--------|----------------|
| 1 | Dockerfile Lint | Hadolint | `app/Dockerfile` | Any warning or error |
| 2 | CVE Scan | Trivy | Built Docker image | HIGH or CRITICAL CVEs found |
| 3 | IaC Scan | Checkov | `k8s/*.yaml` | Severe misconfigurations |
| 4 | Policy Enforcement | OPA/Conftest | `k8s/*.yaml` | Any policy denial |

---

## Gate 1: Dockerfile Linting (Hadolint)

### What It Checks
Hadolint parses the Dockerfile against a set of best-practice rules derived from Docker's official guidelines.

### Common Violations

| Rule | Description | Severity |
|------|-------------|----------|
| DL3007 | Using `latest` tag in `FROM` | Warning |
| DL3002 | Last `USER` should not be `root` | Warning |
| DL3008 | Pin versions in `apt-get install` | Info |
| DL3018 | Pin versions in `apk add` | Info |
| DL3025 | Use `JSON` form for `CMD`/`ENTRYPOINT` | Warning |

### Configuration
- Config file: `.hadolint.yaml`
- Failure threshold: `warning`
- Override: Specific rules can be downgraded or ignored

### Remediation
```dockerfile
# ❌ Bad: Using latest tag
FROM node:latest

# ✅ Good: Pinned version
FROM node:18-alpine

# ❌ Bad: Running as root
# (no USER instruction)

# ✅ Good: Non-root user
RUN adduser -D appuser
USER appuser
```

---

## Gate 2: Vulnerability Scanning (Trivy)

### What It Checks
Trivy scans the built container image for:
- **OS package vulnerabilities** (Alpine APK, Debian APT)
- **Application dependency vulnerabilities** (npm, pip, etc.)
- **Known CVEs** cross-referenced against NVD, GitHub Advisory, etc.

### Configuration
```yaml
severity: HIGH,CRITICAL
exit-code: 1          # Fail pipeline
format: json          # Structured report
```

### Severity Levels

| Severity | Action | Description |
|----------|--------|-------------|
| CRITICAL | ❌ Blocks pipeline | Remote code execution, authentication bypass |
| HIGH | ❌ Blocks pipeline | Privilege escalation, data exposure |
| MEDIUM | ⚠️ Warning only | Moderate impact vulnerabilities |
| LOW | ℹ️ Info only | Minor issues |

### Remediation
1. **Update base image**: `FROM node:18-alpine` → `FROM node:20-alpine`
2. **Update dependencies**: `npm audit fix` or update `package.json`
3. **Create exceptions**: Add CVE ID to `.trivyignore` (with justification)

### Sample Report Output
```json
{
  "Results": [
    {
      "Target": "app/package-lock.json",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2024-XXXXX",
          "PkgName": "express",
          "InstalledVersion": "4.17.1",
          "FixedVersion": "4.21.0",
          "Severity": "HIGH"
        }
      ]
    }
  ]
}
```

---

## Gate 3: IaC Scanning (Checkov)

### What It Checks
Checkov performs static analysis on Kubernetes YAML manifests for:
- Missing security contexts
- Pods running as root
- Missing resource limits
- Missing readiness/liveness probes
- Overly permissive RBAC
- Secrets in plain text

### Common Checks

| Check ID | Description |
|----------|-------------|
| CKV_K8S_1 | Do not allow containers to run with added capabilities |
| CKV_K8S_8 | Liveness probe should be configured |
| CKV_K8S_9 | Readiness probe should be configured |
| CKV_K8S_12 | Memory requests should be set |
| CKV_K8S_13 | Memory limits should be set |
| CKV_K8S_20 | Containers should not run with allowPrivilegeEscalation |
| CKV_K8S_22 | Use read-only filesystem for containers where possible |
| CKV_K8S_28 | Minimize the admission of containers with NET_RAW capability |
| CKV_K8S_37 | Ensure that the seccomp profile is set to RuntimeDefault |
| CKV_K8S_40 | Do not allow containers to run as root |

### Remediation
```yaml
# ❌ Bad: No security context
spec:
  containers:
    - name: app
      image: myapp:latest

# ✅ Good: Hardened security context
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
  containers:
    - name: app
      image: myapp:1.0.0
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi
```

---

## Gate 4: Policy Enforcement (OPA/Conftest)

### What It Checks
Custom organizational policies written in Rego enforce business rules that standard scanners don't cover.

### Policy 1: Registry Restriction (`policies/registry.rego`)
**Purpose**: Prevents supply-chain attacks by ensuring all images come from a trusted source.

```
✅ PASS: trusted-registry.company.com/myapp:1.0.0
❌ DENY: docker.io/library/nginx:latest
❌ DENY: malicious-registry.com/backdoor:latest
```

### Policy 2: Resource Limits (`policies/resources.rego`)
**Purpose**: Prevents resource exhaustion (fork bombs, crypto miners) and noisy-neighbor issues.

```
✅ PASS: Both requests and limits defined for CPU and Memory
❌ DENY: Missing resources.requests
❌ DENY: Missing resources.limits
❌ DENY: Missing CPU or Memory in either section
```

### Policy 3: Mandatory Labels (`policies/labels.rego`)
**Purpose**: Enforces organizational tagging for cost allocation and governance.

```
✅ PASS: metadata.labels.cost-center = "engineering"
❌ DENY: No cost-center label present
```

### Testing Policies Locally
```bash
# Test all policies against all manifests
conftest test k8s/*.yaml -p policies/

# Test a specific policy
conftest test k8s/deployment.yaml -p policies/registry.rego

# Test with verbose output
conftest test k8s/*.yaml -p policies/ --all-namespaces
```

---

## Adding Exceptions

### Trivy Exceptions
Add CVE IDs to `.trivyignore`:
```
# Exception: No fix available, mitigated by network policy
CVE-2024-12345
```

### Checkov Exceptions
Use inline comments or `--skip-check`:
```yaml
# checkov:skip=CKV_K8S_43: Image uses digest, not tag
```

### OPA Exceptions
Modify Rego policies to include exception logic:
```rego
# Allow exception for monitoring namespace
deny[msg] {
    input.kind == "Deployment"
    not input.metadata.namespace == "monitoring"
    not input.metadata.labels["cost-center"]
    msg = "Missing cost-center label"
}
```

---

## Runtime Monitoring (Falco)

While not a pipeline gate, Falco provides the final layer of defense by monitoring live system calls in the Kubernetes cluster.

### What It Detects
- Shell access to containers (`/bin/bash`, `/bin/sh`)
- Sensitive file reads (`/etc/shadow`, SSH keys)
- Unexpected network connections
- Privilege escalation attempts
- Cryptomining activity

### Viewing Alerts
```bash
# Real-time Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# Filter for critical alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep "WARNING\|CRITICAL"
```
