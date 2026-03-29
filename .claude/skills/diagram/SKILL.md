---
name: diagram
description: Create ASCII diagrams representing component architecture, data flow, or codebase structure
disable-model-invocation: true
---

# diagram

You are given the following context:
$ARGUMENTS

## Instructions

Create a clear ASCII diagram representing the requested component, model, or codebase structure. The user wants to visualize architecture, relationships, or flow.

### Guidelines:
1. Use ASCII box drawing characters for clean visuals
2. Include labels and arrows to show relationships
3. Keep diagrams readable and well-aligned
4. Add legend if needed for clarity
5. Focus on the specific component/area requested

### Diagram Types:
- **Architecture diagrams**: Show layers, components, and their relationships
- **Flow diagrams**: Illustrate data flow or process sequences
- **Class/Model diagrams**: Display properties, methods, and relationships
- **Component diagrams**: Show how modules interact
- **State diagrams**: Represent state transitions

### ASCII Characters to Use:
- Boxes: `┌ ┐ └ ┘ ─ │ ├ ┤ ┬ ┴ ┼`
- Arrows: `→ ← ↑ ↓ ↔ ⇒ ⇐`
- Connectors: `+ - | / \`
- Alternative boxes: `+---+` style if Unicode isn't supported

### Example Format:
```
┌─────────────┐
│  Component  │
└──────┬──────┘
       ↓
┌──────┴──────┐
│   Service   │
└─────────────┘
```

Analyze the codebase structure first, then create the most appropriate diagram type for what's being asked. Include a brief description of what the diagram represents.

Save resulting diagram and explanations in some file in the project
