<p align="center">
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white"/>
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
  <img src="https://img.shields.io/badge/OWASP-000000?style=for-the-badge&logo=owasp&logoColor=white"/>
  <img src="https://img.shields.io/badge/Security-FF0000?style=for-the-badge&logo=hackthebox&logoColor=white"/>
</p>

# xntscan

This security scanning tool provides comprehensive security analysis for web applications, with support for scanning projects and generating detailed reports on potential vulnerabilities.

## Features

The tool supports scanning any directory path with comprehensive security checks based on OWASP and NIST guidelines.

## Usage

```
./security-scan.sh -p /path/to/your/project
```

## Options
- `-p, --path PATH` - Specify the project directory to scan
- `-o, --output PATH` - Output directory for results
- `-h, --help` - Show help message

## Installation

Requires the following tools to be installed:
- gitleaks
- semgrep
- trivy
- jq
- checkov (for infrastructure scanning)
- nodejsscan (for Python-based static analysis)
- bearer (for privacy scanning)

## Scanning Process

The tool performs the following security checks:
1. Gitleaks for secrets detection
2. Trivy for file system and configuration scanning
3. Semgrep for code analysis
4. Infrastructure scanning with Checkov
5. NPM audit for dependency vulnerabilities
6. Knip for dead code detection
7. Nodejsscan for security analysis
8. Bearer for data flow analysis

## Output

The tool generates detailed reports in JSON format for all scan results, including:
- Gitleaks for secrets detection
- Trivy for dependencies and misconfigurations
- Semgrep for code analysis
- Bearer for data flow analysis
- NPM audit for known vulnerabilities
- Knip for dead code detection

## Reports

The tool generates a comprehensive report in the output directory with severity scoring based on industry standards (CVSS).

## Requirements
- gitleaks: for detecting hardcoded secrets
- trivy: for container and file system scanning
- semgrep: for static code analysis
- jq: for JSON report processing
- checkov: for infrastructure as code (IaC) scanning
- nodejsscan: for static application security testing
- bearer: for data flow analysis
- knip: for dead code detection

## Additional Features

The tool also supports:
- Entry point mapping for applications
- Environment variable usage analysis
- Docker image vulnerability scanning
- NPM audit for dependencies
- Bearer for data flow analysis
- Knip for dead code detection

## Security Tools Matrix

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

## Upload to DefectDojo

To upload scan results to DefectDojo, use the upload-to-dojo.sh script:

```
./upload-to-dojo.sh -o /path/to/output/directory -e ENGAGEMENT_ID
```

### Options
- `-o, --output-dir PATH` - Path to the output directory with scan results
- `-e, --engagement ID` - DefectDojo Engagement ID
- `-v, --verbose` - Enable verbose output to show skipped files and successful uploads
- `-h, --help` - Show help message

The script will upload all available scan results to DefectDojo, including:
- Gitleaks scan results
- Trivy scan results (file system and configuration)
- Semgrep scan results (various security checks)
- NPM audit results
- NodeJSScan results
- Bearer CLI results
- Knip results

When using the verbose flag (`-v`), the script will show detailed information about:
- Files that were successfully uploaded
- Files that were skipped (empty, null, or missing files)
- Upload failures
- Summary of the upload process

## License

This tool is provided under the MIT License.
