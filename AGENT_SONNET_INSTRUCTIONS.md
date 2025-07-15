# Agent Instructions - Sonnet Model Default

## 🚨 CRITICAL: Model Configuration
**必ずSonnet modelを使用してください - Claude Max plan利用制限対策**
- Model: claude-3-5-sonnet-20241022
- Language: English preferred (token efficiency)
- Session: Keep under 30 minutes per task

## CC01 Backend Specialist (Sonnet)
```
IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)

**ITDO_ERP2 Backend Development Session**

**Directory**: /mnt/c/work/ITDO_ERP2
**Current Focus**: Issue #137 - Department Management Enhancement
**Model**: claude-3-5-sonnet-20241022

**Priority Tasks**:
1. Issue #137 status verification (single execution)
2. Efficient implementation plan using existing information
3. Progress tracking with TodoWrite
4. TDD approach for code quality

**Escalation Rules**:
- Time limit: 30+ minutes
- Complex architecture decisions
- Multi-component changes
- Technical blockers

**Next Action**: Check Issue #137 details and start implementation.
```

## CC02 Database Specialist (Sonnet)
```
IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)

**ITDO_ERP2 Database Development Session**

**Directory**: /mnt/c/work/ITDO_ERP2
**Focus**: PR #97 Role Service completion
**Model**: claude-3-5-sonnet-20241022

**Action**: Verify PR #97 completion status and report within 5 minutes.

**Escalation**: Contact Manager (Opus) if complex database optimization needed.
```

## CC03 Frontend Specialist (Sonnet)
```
IMPORTANT: Use Sonnet Model Only (claude-3-5-sonnet-20241022)

**ITDO_ERP2 Frontend Development Session**

**Directory**: /mnt/c/work/ITDO_ERP2
**Focus**: Issue #138 - UI Component Enhancement
**Model**: claude-3-5-sonnet-20241022

**Environment**:
- React 18 + TypeScript 5 + Vite
- Testing: Vitest + React Testing Library
- Styling: Tailwind CSS
- Type safety: No `any` types

**Task**: Analyze Issue #138 implementation status and identify next steps (5 minutes).

**Escalation**: Contact Manager (Opus) for complex state management decisions.
```

## Manager (Opus) Escalation Template
```
**Manager Session - Opus Model**

**Context**: Escalation from Agent {AGENT_ID}
**Issue**: {ISSUE_DESCRIPTION}
**Tried**: {ATTEMPTED_SOLUTIONS}
**Model**: claude-3-opus-20240229

**Action**: Provide strategic solution and implementation guidance.
```

## Cost Optimization Metrics
- **Target**: 70% cost reduction vs all-Opus approach
- **Agent Tasks**: 95% Sonnet usage
- **Manager Tasks**: 5% Opus usage for complex decisions
- **Success Rate**: >90% task completion without escalation

---
🤖 Optimized for Claude Max Plan Efficiency