# 🎥 DevSecOps Security-First Pipeline — Summit Video Demo Guide

This guide provides a step-by-step walkthrough, terminal commands, and a complete narrative script for recording a professional **3-5 minute video demonstration** of this project for your summit presentation.

---

## ⏱️ Video Demo Structure (Total Time: ~4 Minutes)

| Section | Topic | Timing | Visual Focus |
|---------|-------|--------|--------------|
| **1** | Introduction & Architecture | 0:00 - 0:45 | README Architecture Diagram / Slides |
| **2** | Shift-Left Static Scans | 0:45 - 2:00 | Local Terminal (Hadolint, Checkov, Conftest) |
| **3** | GitHub Actions CI/CD Gates | 2:00 - 3:00 | GitHub Actions Run & Artifacts |
| **4** | Runtime Detection with Falco | 3:00 - 3:45 | Kubernetes Cluster Terminal & Alert Logs |
| **5** | Wrap-up & Summary | 3:45 - 4:00 | Project Badges & Key Achievements |

---

## 🎬 Step-by-Step Recording Script

### Section 1: Introduction & Architecture (0:00 - 0:45)
*   **What to show:** Open [README.md](file:///d:/GPP/Secure-CI-CD-Pipeline-with-Container-Security-Scanning-using-Trivy-OPA-and-Falco/README.md) or show slides outlining the architecture diagram.
*   **Narrative Script:**
    > *"Hello everyone. Today, I am excited to demonstrate our Secure DevSecOps Pipeline, showcasing the power of shifting security left. Instead of testing security at the end of the deployment cycle, we've integrated five layers of defense directly into our build and deployment processes. We use Hadolint for Dockerfile linting, Trivy for container image scanning, Checkov for Infrastructure as Code checks, Open Policy Agent for custom organizational guidelines, and finally, Falco for real-time runtime monitoring in Kubernetes. Let's see it in action."*

---

### Section 2: Shift-Left Static Scans (0:45 - 2:00)
*   **What to show:** Open your VS Code terminal and execute the static scanning tools.
*   **Action 1: Hadolint**
    ```bash
    hadolint app/Dockerfile
    ```
    *Narrative:* *"First, we lint our Dockerfile using Hadolint to enforce container packaging best practices. Our hardened Dockerfile uses a pinned alpine base image, runs as a non-root user, and strips out the Alpine package manager to prevent post-exploit modifications."*
*   **Action 2: Checkov**
    ```bash
    checkov -d k8s/ --framework kubernetes
    ```
    *Narrative:* *"Second, we use Checkov to scan our Kubernetes manifests. It ensures our pod security contexts are fully locked down, enforcing non-root user IDs, dropping privileged capabilities, and validating our NetworkPolicy configuration."*
*   **Action 3: OPA/Conftest**
    ```bash
    conftest test k8s/*.yaml -p policies/ --all-namespaces
    ```
    *Narrative:* *"Third, we run custom OPA/Conftest policy checks. These Rego-based rules check organization-level policies, such as validating that our container images are pulled from our trusted company registry, verifying resource constraints, and checking for mandatory cost-center labels."*

---

### Section 3: GitHub Actions CI/CD Gates (2:00 - 3:00)
*   **What to show:** Open the GitHub Actions tab of your repository in the browser.
*   **Narrative Script:**
    > *"When code is pushed to our repository, our GitHub Actions pipeline runs these gates sequentially. Let's look at the pipeline execution. If Hadolint, Trivy, Checkov, or OPA detect a single security vulnerability or policy deviation, the pipeline immediately halts, blocking the deploy stage. For supply chain security, all third-party actions are pinned to immutable commit SHAs, and our Conftest binaries are checksum-validated upon installation. Successful runs produce detailed vulnerability and compliance reports as build artifacts."*

---

### Section 4: Runtime Monitoring with Falco (3:00 - 3:45)
*   **What to show:** Open a dual-pane terminal. Show the setup or log tail in one pane, and exec command in the other.
*   **Action 1: Watch Falco Logs**
    ```bash
    kubectl logs -n falco -l app.kubernetes.io/name=falco -f
    ```
*   **Action 2: Trigger Alert (Exec shell in pod)**
    ```bash
    kubectl exec -it $(kubectl get pods -n devsecops -o jsonpath='{.items[0].metadata.name}') -n devsecops -- /bin/sh
    ```
*   **Narrative Script:**
    > *"While the CI/CD pipeline protects our manifests before deployment, Falco guards our runtime cluster. Falco monitors system calls in real-time. If an attacker attempts to spawn an interactive shell inside our production containers, Falco's custom rule immediately triggers a warning alert. You can see the shell detection alert here with details on the namespace, container name, and process ID. This log is immediately forwarded to our SIEM for incident response."*

---

### Section 5: Wrap-up & Summary (3:45 - 4:00)
*   **What to show:** Show the final project badges or the GitHub repository home screen.
*   **Narrative Script:**
    > *"By automating security audits, enforcing policies via code, and actively monitoring running containers, we've established a complete Zero-Trust pipeline from code commit to cluster runtime. Thank you."*

---

## 🛠️ Local Demo Setup Guide

To record the Falco live demo, follow these steps to spin up the environment:

1.  **Start Local Cluster & Falco:**
    Run the bootstrap script. It will set up a local `k3d` cluster and install the Helm release for Falco with custom eBPF rules:
    ```bash
    ./scripts/setup-cluster.sh
    ```
2.  **Run Falco Threat Simulation:**
    Run the simulation script to execute a shell inside the deployment and tail Falco's system alerts:
    ```bash
    ./scripts/demo-falco.sh
    ```
3.  **Review Alert Output:**
    The log warning showing the captured intrusion attempt is stored in:
    ```
    security-logs/falco-alert-*.log
    ```
