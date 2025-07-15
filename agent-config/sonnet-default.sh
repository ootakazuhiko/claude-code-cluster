#!/bin/bash

# Agent Default Configuration: Sonnet Model
# Claude Max Plan利用制限対策として、エージェントは常時Sonnetを使用

# Model Configuration
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export CLAUDE_AGENT_MODE="sonnet"
export ESCALATION_THRESHOLD=30  # minutes
export MANAGER_CALL_ENABLED=true

# Cost Optimization Settings
export CLAUDE_LANGUAGE="en"  # English for token efficiency
export CLAUDE_CONTEXT_MODE="minimal"
export CLAUDE_SESSION_TIMEOUT=3600  # 1 hour

# Agent Identification
export AGENT_ID="${1:-CC01}"
export AGENT_SPECIALIZATION="${2:-general}"

# Escalation Configuration
export ESCALATION_TRIGGERS="time_limit,complexity,error,dependency"
export MANAGER_MODEL="claude-3-opus-20240229"

# Performance Monitoring
export PERFORMANCE_LOG="/tmp/claude-agent-${AGENT_ID}.log"
export COST_TRACKING_ENABLED=true

# Session Initialize
echo "🤖 Agent ${AGENT_ID} initialized with Sonnet model"
echo "📊 Specialization: ${AGENT_SPECIALIZATION}"
echo "⏱️ Escalation threshold: ${ESCALATION_THRESHOLD} minutes"
echo "🚀 Ready for distributed development"

# Function for escalation
escalate() {
    local issue="$1"
    local context="$2"
    local tried="$3"
    
    echo "🔺 ESCALATION: Agent ${AGENT_ID} -> Manager (Opus)"
    echo "Issue: ${issue}"
    echo "Context: ${context}"
    echo "Tried: ${tried}"
    echo "Time: $(date)"
    
    # Log escalation event
    echo "$(date): ESCALATION - ${issue}" >> "${PERFORMANCE_LOG}"
}

# Export escalation function
export -f escalate

# Verification
echo "✅ Agent configuration completed"
echo "Model: ${CLAUDE_MODEL}"
echo "Ready for task execution"