# security/policies/container-security.rego
# Nimbus Analytics Container Security Policies
# Open Policy Agent (OPA) rules for enforcing container security best practices

package container.security

# Default deny - containers must explicitly meet security requirements
default allow = false

# Allow containers that pass all security checks
allow {
    not deny[_]
}

# CRITICAL SECURITY VIOLATIONS - These will block deployment

# Rule 1: Deny privileged containers
# Privileged containers have dangerous access to host system
deny[msg] {
    input.SecurityContext.privileged == true
    msg := sprintf("CRITICAL: Container '%s' runs in privileged mode, granting dangerous host access", [input.name])
}

# Rule 2: Deny root user execution
# Running as root (UID 0) provides unnecessary privileges
deny[msg] {
    input.SecurityContext.runAsUser == 0
    msg := sprintf("CRITICAL: Container '%s' runs as root user (UID 0). Use non-privileged user (UID > 0)", [input.name])
}

# Rule 3: Require read-only root filesystem
# Prevents runtime file modifications and malware installation
deny[msg] {
    input.SecurityContext.readOnlyRootFilesystem != true
    msg := sprintf("HIGH: Container '%s' allows filesystem modifications. Enable read-only root filesystem", [input.name])
}

# Rule 4: Deny dangerous Linux capabilities
# Certain capabilities provide excessive privileges
dangerous_capabilities := [
    "SYS_ADMIN",      # System administration capabilities
    "NET_ADMIN",      # Network administration capabilities  
    "SYS_TIME",       # System time modification
    "SYS_MODULE",     # Kernel module loading
    "DAC_OVERRIDE",   # Discretionary access control override
    "SYS_PTRACE",     # Process tracing capabilities
    "SYS_CHROOT",     # Change root directory
    "AUDIT_WRITE",    # Audit subsystem write access
    "SETUID",         # Set user ID capabilities
    "SETGID"          # Set group ID capabilities
]

deny[msg] {
    capability := input.SecurityContext.capabilities.add[_]
    capability in dangerous_capabilities
    msg := sprintf("HIGH: Container '%s' requests dangerous capability '%s'", [input.name, capability])
}

# Rule 5: Deny host network access
# Containers should not share host network namespace
deny[msg] {
    input.hostNetwork == true
    msg := sprintf("HIGH: Container '%s' uses host network mode, bypassing network isolation", [input.name])
}

# Rule 6: Deny host PID namespace
# Containers should not access host process namespace
deny[msg] {
    input.hostPID == true
    msg := sprintf("HIGH: Container '%s' uses host PID namespace, exposing host processes", [input.name])
}

# Rule 7: Deny host IPC namespace  
# Containers should not share host inter-process communication
deny[msg] {
    input.hostIPC == true
    msg := sprintf("HIGH: Container '%s' uses host IPC namespace, compromising isolation", [input.name])
}

# Rule 8: Require resource limits
# Prevent resource exhaustion attacks
deny[msg] {
    not input.resources.limits.memory
    msg := sprintf("MEDIUM: Container '%s' lacks memory limits, risking resource exhaustion", [input.name])
}

deny[msg] {
    not input.resources.limits.cpu
    msg := sprintf("MEDIUM: Container '%s' lacks CPU limits, risking resource exhaustion", [input.name])
}

# Rule 9: Deny host port binding
# Direct host port binding bypasses service mesh/load balancer controls
deny[msg] {
    port := input.ports[_]
    port.hostPort
    msg := sprintf("MEDIUM: Container '%s' binds to host port %d, bypassing traffic controls", [input.name, port.hostPort])
}

# Rule 10: Require specific user ranges (Nimbus policy)
# Nimbus Analytics requires UIDs in range 1000-65534 for non-root execution
deny[msg] {
    uid := input.SecurityContext.runAsUser
    uid != null
    uid < 1000
    msg := sprintf("MEDIUM: Container '%s' uses UID %d. Nimbus policy requires UID >= 1000", [input.name, uid])
}

# WARNINGS - These won't block deployment but should be addressed

# Warning 1: Missing health checks
warn[msg] {
    not input.healthcheck
    msg := sprintf("WARNING: Container '%s' lacks health check configuration", [input.name])
}

# Warning 2: Latest tag usage
warn[msg] {
    contains(input.image, ":latest")
    msg := sprintf("WARNING: Container '%s' uses 'latest' tag. Use specific version tags for reproducibility", [input.name])
}

# Warning 3: Missing resource requests
warn[msg] {
    not input.resources.requests
    msg := sprintf("WARNING: Container '%s' lacks resource requests. This affects scheduling decisions", [input.name])
}

# Warning 4: Excessive memory limits
warn[msg] {
    memory_str := input.resources.limits.memory
    memory_int := to_number(trim_suffix(memory_str, "Mi"))
    memory_int > 4096
    msg := sprintf("WARNING: Container '%s' requests %s memory. Consider if this is necessary", [input.name, memory_str])
}

# NIMBUS-SPECIFIC SECURITY POLICIES

# Nimbus Rule 1: Analytics containers must run as nimbus user (UID 1001)
deny[msg] {
    startswith(input.name, "nimbus-analytics")
    input.SecurityContext.runAsUser != 1001
    msg := sprintf("NIMBUS POLICY: Analytics container '%s' must run as nimbus user (UID 1001)", [input.name])
}

# Nimbus Rule 2: Data processing containers require additional restrictions
deny[msg] {
    contains(input.name, "data-processor")
    count(input.SecurityContext.capabilities.drop) == 0
    msg := sprintf("NIMBUS POLICY: Data processor '%s' must drop ALL capabilities", [input.name])
}

# Nimbus Rule 3: Web-facing containers must have specific port configuration
deny[msg] {
    contains(input.name, "web")
    port := input.ports[_]
    not port.containerPort in [80, 8080, 3000, 8443]
    msg := sprintf("NIMBUS POLICY: Web container '%s' uses non-standard port %d", [input.name, port.containerPort])
}

# Nimbus Rule 4: Production containers must have restart policies
deny[msg] {
    input.environment == "production"
    not input.restartPolicy
    msg := sprintf("NIMBUS POLICY: Production container '%s' must specify restart policy", [input.name])
}

# Nimbus Rule 5: Secrets must be injected, not embedded
deny[msg] {
    env_var := input.env[_]
    regex.match("(?i)(password|secret|key|token|credential)", env_var.name)
    env_var.value  # Direct value instead of valueFrom
    msg := sprintf("NIMBUS POLICY: Container '%s' has hardcoded secret in environment variable '%s'", [input.name, env_var.name])
}

# COMPLIANCE REQUIREMENTS

# SOX Compliance: Financial data processing containers
sox_containers := ["analytics-api", "data-processor", "reporting"]

deny[msg] {
    input.name in sox_containers
    not input.SecurityContext.readOnlyRootFilesystem
    msg := sprintf("SOX COMPLIANCE: Financial container '%s' must use read-only filesystem", [input.name])
}

# GDPR Compliance: Data processing containers must have specific configurations
gdpr_required_labels := ["data-classification", "retention-policy", "privacy-impact"]

warn[msg] {
    contains(input.name, "data")
    label := gdpr_required_labels[_]
    not input.metadata.labels[label]
    msg := sprintf("GDPR COMPLIANCE: Data container '%s' missing required label '%s'", [input.name, label])
}

# SECURITY SCORING SYSTEM

# Calculate security score (0-100)
security_score = score {
    violations := count(deny)
    warnings := count(warn)
    
    # Start with perfect score
    base_score := 100
    
    # Subtract points for violations
    violation_penalty := violations * 20
    warning_penalty := warnings * 5
    
    # Calculate final score
    score := base_score - violation_penalty - warning_penalty
}

# Security level classification
security_level = level {
    score := security_score
    score >= 90
    level := "EXCELLENT"
} else = level {
    score := security_score
    score >= 75
    level := "GOOD"
} else = level {
    score := security_score
    score >= 60
    level := "ACCEPTABLE"
} else = level {
    score := security_score
    level := "NEEDS_IMPROVEMENT"
}

# Generate comprehensive security assessment
security_assessment = assessment {
    assessment := {
        "container_name": input.name,
        "security_score": security_score,
        "security_level": security_level,
        "violations": count(deny),
        "warnings": count(warn),
        "critical_issues": [msg | deny[msg]; contains(msg, "CRITICAL")],
        "high_issues": [msg | deny[msg]; contains(msg, "HIGH")],
        "medium_issues": [msg | deny[msg]; contains(msg, "MEDIUM")],
        "nimbus_policy_violations": [msg | deny[msg]; contains(msg, "NIMBUS POLICY")],
        "compliance_issues": [msg | deny[msg]; contains(msg, "COMPLIANCE")],
        "recommendation": recommendation
    }
}

# Security recommendations based on assessment
recommendation = rec {
    security_score >= 90
    rec := "Container meets excellent security standards. Ready for production deployment."
} else = rec {
    security_score >= 75  
    rec := "Container meets good security standards. Address warnings before production."
} else = rec {
    security_score >= 60
    rec := "Container has acceptable security. Address high-priority issues before deployment."
} else = rec {
    rec := "Container fails security requirements. Must address all violations before deployment."
}
