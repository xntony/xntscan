# Security Scanning Tools Matrix

| Tool | Scan Performed | Description |
|------|---------------|-------------|
| Gitleaks | Secrets Detection | Scans for hardcoded secrets in source code |
| Trivy FS | File System Scanning | Scans for vulnerabilities in project dependencies and OS packages |
| Trivy Config | Misconfiguration Detection | Scans for security misconfigurations |
| Semgrep (JWT) | JWT and Secrets | Scans for JWT handling issues and hardcoded secrets |
| Semgrep (Node.js) | Input Validation | Checks for Node.js best practices and OWASP Top 10 |
| Semgrep (SQL Injection) | Injection Detection | Scans for SQL/NoSQL injection vulnerabilities |
| Semgrep (Additional) | Command Injection and Path Traversal | Additional security checks for command injection and path traversal |
| Trivy Image | Container Scanning | Scans Docker images for vulnerabilities |
| NPM Audit | Dependency Scanning | Scans NPM packages for known vulnerabilities |
| Checkov | Infrastructure as Code Scanning | Scans for misconfigurations in infrastructure code |
| NodeJSScan | Static Analysis | Static analysis for Node.js applications |
| Bearer | Data Flow Analysis | Scans for data flow issues and privacy concerns |
| Knip | Dead Code Detection | Detects unused code and dependencies |
| Semgrep (Business Logic) | Business Logic Flaws | Checks for business logic and security misconfigurations |