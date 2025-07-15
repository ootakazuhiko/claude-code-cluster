#!/bin/bash

# Agent Startup Script - Sonnet Model Default
# Usage: ./start-agent-sonnet.sh [CC01|CC02|CC03]

set -e

AGENT_ID="${1:-CC01}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source configuration
source "${SCRIPT_DIR}/agent-config/sonnet-default.sh" "${AGENT_ID}"

# Display agent instructions
echo "📋 Agent Instructions for ${AGENT_ID}:"
echo "================================================"

case "${AGENT_ID}" in
    "CC01")
        echo "IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)"
        echo ""
        echo "**ITDO_ERP2 Backend Development Session**"
        echo "**Directory**: ${PROJECT_DIR}"
        echo "**Current Focus**: Issue #137 - Department Management Enhancement"
        echo "**Model**: claude-3-5-sonnet-20241022"
        echo ""
        echo "**Priority Tasks**:"
        echo "1. Issue #137 status verification (single execution)"
        echo "2. Efficient implementation plan using existing information"
        echo "3. Progress tracking with TodoWrite"
        echo "4. TDD approach for code quality"
        echo ""
        echo "**Escalation Rules**:"
        echo "- Time limit: 30+ minutes"
        echo "- Complex architecture decisions"
        echo "- Multi-component changes"
        echo "- Technical blockers"
        echo ""
        echo "**Next Action**: Check Issue #137 details and start implementation."
        ;;
    "CC02")
        echo "IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)"
        echo ""
        echo "**ITDO_ERP2 Database Development Session**"
        echo "**Directory**: ${PROJECT_DIR}"
        echo "**Focus**: PR #97 Role Service completion"
        echo "**Model**: claude-3-5-sonnet-20241022"
        echo ""
        echo "**Action**: Verify PR #97 completion status and report within 5 minutes."
        echo ""
        echo "**Escalation**: Contact Manager (Opus) if complex database optimization needed."
        ;;
    "CC03")
        echo "IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)"
        echo ""
        echo "**ITDO_ERP2 Frontend Development Session**"
        echo "**Directory**: ${PROJECT_DIR}"
        echo "**Focus**: Issue #138 - UI Component Enhancement"
        echo "**Model**: claude-3-5-sonnet-20241022"
        echo ""
        echo "**Environment**:"
        echo "- React 18 + TypeScript 5 + Vite"
        echo "- Testing: Vitest + React Testing Library"
        echo "- Styling: Tailwind CSS"
        echo "- Type safety: No 'any' types"
        echo ""
        echo "**Task**: Analyze Issue #138 implementation status and identify next steps (5 minutes)."
        echo ""
        echo "**Escalation**: Contact Manager (Opus) for complex state management decisions."
        ;;
    *)
        echo "Unknown agent ID: ${AGENT_ID}"
        echo "Usage: $0 [CC01|CC02|CC03]"
        exit 1
        ;;
esac

echo "================================================"
echo "✅ Agent ${AGENT_ID} ready for Sonnet-optimized development"
echo "📊 Cost optimization: Claude Max plan compliant"
echo "🔺 Escalation available: Use 'escalate' function when needed"