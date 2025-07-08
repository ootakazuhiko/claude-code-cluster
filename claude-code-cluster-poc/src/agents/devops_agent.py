"""DevOps specialized agent"""

import logging
from typing import Dict, Any, List
from pathlib import Path

from .base_agent import BaseSpecializedAgent
from src.utils.logging import get_logger


logger = get_logger(__name__)


class DevOpsAgent(BaseSpecializedAgent):
    """Agent specialized in DevOps and infrastructure"""
    
    def __init__(self, agent_id: str = "devops-agent"):
        super().__init__(agent_id, ["devops", "infrastructure", "deployment", "ci", "cd"])
    
    def can_handle_task(self, task: Dict[str, Any]) -> float:
        """Check if agent can handle DevOps tasks"""
        requirements = task.get("analysis", {}).get("requirements", [])
        keywords = task.get("analysis", {}).get("keywords", [])
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        score = 0.0
        
        # Check requirements
        devops_requirements = ["devops", "infrastructure", "deployment", "ci", "cd"]
        matching_requirements = [req for req in requirements if req in devops_requirements]
        if matching_requirements:
            score += 0.8 * (len(matching_requirements) / len(devops_requirements))
        
        # Check keywords
        devops_keywords = [
            "docker", "kubernetes", "ci", "cd", "pipeline", "deployment", "infrastructure",
            "terraform", "ansible", "jenkins", "github", "actions", "build", "deploy",
            "container", "orchestration", "monitoring", "logging", "metrics", "aws",
            "azure", "gcp", "cloud", "devops", "automation", "provisioning"
        ]
        matching_keywords = [kw for kw in keywords if kw in devops_keywords]
        if matching_keywords:
            score += 0.6 * min(1.0, len(matching_keywords) / 5)
        
        # Check title and body
        devops_terms = [
            "docker", "kubernetes", "ci", "cd", "pipeline", "deployment", "build",
            "deploy", "infrastructure", "container", "automation", "monitoring"
        ]
        title_matches = sum(1 for term in devops_terms if term in title)
        body_matches = sum(1 for term in devops_terms if term in body)
        
        if title_matches > 0:
            score += 0.4 * min(1.0, title_matches / 3)
        if body_matches > 0:
            score += 0.2 * min(1.0, body_matches / 5)
        
        return min(1.0, score)
    
    def get_system_prompt_additions(self) -> str:
        """Get DevOps-specific system prompt additions"""
        return """
## DevOps and Infrastructure Focus

You are specialized in DevOps and infrastructure with expertise in:

### Core Technologies:
- **Containerization**: Docker, Podman, container orchestration
- **Orchestration**: Kubernetes, Docker Swarm, container management
- **CI/CD**: GitHub Actions, Jenkins, GitLab CI, Azure DevOps
- **Infrastructure as Code**: Terraform, CloudFormation, Pulumi
- **Configuration Management**: Ansible, Chef, Puppet
- **Cloud Platforms**: AWS, Azure, GCP, cloud-native services

### Best Practices:
- Implement Infrastructure as Code (IaC)
- Follow GitOps principles
- Use immutable infrastructure
- Implement proper monitoring and logging
- Ensure security best practices
- Automate repetitive tasks
- Use version control for infrastructure
- Implement proper backup and disaster recovery

### CI/CD Pipeline Design:
- Create efficient build pipelines
- Implement automated testing
- Use proper branching strategies
- Implement security scanning
- Use artifact management
- Implement deployment strategies (blue-green, canary)
- Monitor deployment health

### Container Best Practices:
- Use multi-stage builds
- Implement proper image layering
- Use non-root users
- Implement health checks
- Use proper resource limits
- Implement proper logging
- Use distroless images when possible

### Monitoring and Observability:
- Implement comprehensive monitoring
- Use proper logging strategies
- Implement distributed tracing
- Create meaningful dashboards
- Set up alerting
- Use metrics for decision making

### Security:
- Implement security scanning
- Use secrets management
- Follow least privilege principle
- Implement network security
- Use secure image practices
- Implement compliance checks
"""
    
    def analyze_task_requirements(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze DevOps-specific task requirements"""
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        analysis = {
            "needs_containerization": False,
            "needs_cicd": False,
            "needs_infrastructure": False,
            "needs_monitoring": False,
            "needs_deployment": False,
            "needs_automation": False,
            "complexity_factors": []
        }
        
        # Check for containerization needs
        container_terms = ["docker", "container", "image", "dockerfile", "pod", "kubernetes"]
        if any(term in title + body for term in container_terms):
            analysis["needs_containerization"] = True
            analysis["complexity_factors"].append("containerization")
        
        # Check for CI/CD needs
        cicd_terms = ["ci", "cd", "pipeline", "build", "deploy", "automation", "github", "actions"]
        if any(term in title + body for term in cicd_terms):
            analysis["needs_cicd"] = True
            analysis["complexity_factors"].append("cicd")
        
        # Check for infrastructure needs
        infra_terms = ["infrastructure", "terraform", "cloud", "aws", "azure", "gcp", "server"]
        if any(term in title + body for term in infra_terms):
            analysis["needs_infrastructure"] = True
            analysis["complexity_factors"].append("infrastructure")
        
        # Check for monitoring needs
        monitoring_terms = ["monitoring", "metrics", "logging", "alerts", "observability"]
        if any(term in title + body for term in monitoring_terms):
            analysis["needs_monitoring"] = True
            analysis["complexity_factors"].append("monitoring")
        
        # Check for deployment needs
        deployment_terms = ["deployment", "deploy", "release", "rollout", "production"]
        if any(term in title + body for term in deployment_terms):
            analysis["needs_deployment"] = True
            analysis["complexity_factors"].append("deployment")
        
        # Check for automation needs
        automation_terms = ["automation", "script", "workflow", "schedule", "cron"]
        if any(term in title + body for term in automation_terms):
            analysis["needs_automation"] = True
            analysis["complexity_factors"].append("automation")
        
        return analysis
    
    def get_relevant_files_patterns(self) -> List[str]:
        """Get file patterns relevant to DevOps"""
        return [
            "Dockerfile",
            "docker-compose.yml",
            "docker-compose.yaml",
            "*.dockerfile",
            "kubernetes/*",
            "k8s/*",
            "*.yaml",
            "*.yml",
            ".github/workflows/*",
            ".gitlab-ci.yml",
            "Jenkinsfile",
            "*.tf",
            "*.tfvars",
            "terraform/*",
            "infrastructure/*",
            "ansible/*",
            "*.ansible",
            "playbook.yml",
            "requirements.yml",
            "scripts/*",
            "deploy/*",
            "deployment/*",
            "monitoring/*",
            "prometheus/*",
            "grafana/*",
            "docker/*",
            "build/*",
            "Makefile",
            "*.mk",
            "*.sh",
            "*.ps1",
            "*.bat"
        ]
    
    def validate_implementation(self, implementation: Dict[str, Any], task: Dict[str, Any]) -> Dict[str, Any]:
        """Validate DevOps implementation"""
        changes = implementation.get("changes", [])
        validation = {
            "valid": True,
            "issues": [],
            "warnings": [],
            "suggestions": []
        }
        
        # Check for relevant files
        devops_files = [
            change for change in changes 
            if any(pattern in change.get("file_path", "") for pattern in [
                "Dockerfile", "docker-compose", ".yml", ".yaml", ".tf", ".sh",
                "Jenkinsfile", "Makefile", "workflows"
            ])
        ]
        
        if not devops_files:
            validation["warnings"].append("No DevOps-specific files found in implementation")
        
        # Check task-specific requirements
        task_analysis = self.analyze_task_requirements(task)
        
        # Validate containerization
        if task_analysis["needs_containerization"]:
            docker_files = [change for change in changes if "dockerfile" in change.get("file_path", "").lower()]
            if not docker_files:
                validation["warnings"].append("Task requires containerization but no Dockerfile found")
            else:
                # Check Dockerfile best practices
                for docker_file in docker_files:
                    content = docker_file.get("content", "")
                    if "FROM" not in content:
                        validation["issues"].append("Dockerfile missing FROM instruction")
                    if "USER" not in content:
                        validation["suggestions"].append("Consider using non-root user in Dockerfile")
        
        # Validate CI/CD
        if task_analysis["needs_cicd"]:
            cicd_files = [
                change for change in changes 
                if any(pattern in change.get("file_path", "") for pattern in [
                    "workflows", "Jenkinsfile", ".gitlab-ci", "pipeline"
                ])
            ]
            if not cicd_files:
                validation["warnings"].append("Task requires CI/CD but no pipeline files found")
        
        # Validate infrastructure
        if task_analysis["needs_infrastructure"]:
            infra_files = [change for change in changes if change.get("file_path", "").endswith(".tf")]
            if not infra_files:
                validation["warnings"].append("Task requires infrastructure but no Terraform files found")
        
        # Check for security considerations
        security_terms = ["secret", "password", "token", "key", "credential"]
        for change in changes:
            content = change.get("content", "")
            if any(term in content.lower() for term in security_terms):
                validation["suggestions"].append(f"Review security considerations in {change.get('file_path')}")
        
        return validation
    
    def get_claude_model(self) -> str:
        """Get appropriate Claude model for DevOps tasks"""
        return "claude-3-sonnet-20240229"  # Use Sonnet for complex infrastructure code
    
    def get_testing_strategy(self, task: Dict[str, Any]) -> List[str]:
        """Get DevOps-specific testing strategy"""
        strategy = [
            "Test infrastructure code syntax",
            "Validate configuration files",
            "Test deployment scripts",
            "Verify container builds",
            "Test CI/CD pipeline stages",
            "Validate security configurations"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_containerization"]:
            strategy.extend([
                "Test Docker image builds",
                "Validate container security",
                "Test container functionality",
                "Test multi-stage builds"
            ])
        
        if task_analysis["needs_cicd"]:
            strategy.extend([
                "Test pipeline syntax",
                "Validate build stages",
                "Test deployment procedures",
                "Verify artifact generation"
            ])
        
        if task_analysis["needs_infrastructure"]:
            strategy.extend([
                "Test Terraform plans",
                "Validate resource configurations",
                "Test infrastructure provisioning",
                "Verify network configurations"
            ])
        
        if task_analysis["needs_monitoring"]:
            strategy.extend([
                "Test monitoring configurations",
                "Validate metrics collection",
                "Test alerting rules",
                "Verify dashboard functionality"
            ])
        
        return strategy
    
    def get_review_criteria(self, task: Dict[str, Any]) -> List[str]:
        """Get DevOps-specific review criteria"""
        criteria = [
            "Infrastructure code follows best practices",
            "Security considerations are addressed",
            "Configuration is environment-agnostic",
            "Documentation is comprehensive",
            "Deployment procedures are reliable",
            "Monitoring and logging are implemented",
            "Resource usage is optimized"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_containerization"]:
            criteria.extend([
                "Dockerfile follows best practices",
                "Container images are optimized",
                "Security vulnerabilities are addressed",
                "Health checks are implemented"
            ])
        
        if task_analysis["needs_cicd"]:
            criteria.extend([
                "Pipeline stages are logically organized",
                "Build artifacts are properly managed",
                "Deployment strategy is appropriate",
                "Pipeline security is implemented"
            ])
        
        if task_analysis["needs_infrastructure"]:
            criteria.extend([
                "Infrastructure is properly modularized",
                "State management is configured",
                "Resource tagging is consistent",
                "Backup and recovery are considered"
            ])
        
        return criteria