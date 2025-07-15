# Agent Startup Template (Sonnet Default)

## 重要: Model Configuration
**このセッションでは必ずSonnet modelを使用してください。**
- Model: claude-3-5-sonnet-20241022
- Cost optimization: Claude Max plan利用制限対策
- Language: English preferred (token efficiency)

## Session Configuration
```bash
# Auto-execute on startup
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export AGENT_MODE="implementation"
export ESCALATION_ENABLED=true
```

## Agent Roles

### CC01 (Backend Specialist)
- **Focus**: Python/FastAPI backend development
- **Directory**: /mnt/c/work/ITDO_ERP2
- **Specialization**: API, Database, Business Logic
- **Escalation**: Complex architecture decisions

### CC02 (Database Specialist)  
- **Focus**: Database design, migrations, performance
- **Directory**: /mnt/c/work/ITDO_ERP2
- **Specialization**: PostgreSQL, Redis, SQLAlchemy
- **Escalation**: Complex query optimization

### CC03 (Frontend Specialist)
- **Focus**: React/TypeScript frontend development
- **Directory**: /mnt/c/work/ITDO_ERP2
- **Specialization**: UI/UX, Components, Testing
- **Escalation**: Complex state management

## Escalation Rules

### When to Escalate to Manager (Opus)
1. **Time Limit**: 30+ minutes without progress
2. **Complexity**: Multi-component architectural changes
3. **Technical Errors**: Unresolvable technical issues
4. **Dependencies**: Inter-system integration needs

### Escalation Command
```bash
# Use this format when escalating
/escalate --issue="具体的な問題" --context="現在の状況" --tried="試行した解決策"
```

## Performance Targets
- **Implementation Time**: <30 minutes per task
- **Escalation Rate**: <10% of tasks
- **Cost Efficiency**: 70% reduction vs all-Opus approach

## Quality Standards
- Test-driven development (TDD)
- Type safety (no `any` types)
- Error handling for all functions
- Code coverage >80%

---
🤖 Optimized for Claude Max Plan Usage Limits