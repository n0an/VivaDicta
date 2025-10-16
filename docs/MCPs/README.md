# MCP Tools Used in VivaDicta

This directory contains documentation for Model Context Protocol (MCP) servers used in this project. MCP servers extend Claude Code's capabilities by providing additional tools and integrations.

## Active MCP Servers

### Peekaboo MCP
- **Purpose**: macOS screenshot capture, image analysis, and system inspection
- **Docs**: [Peekaboo_README.md](./Peekaboo_README.md)
- **Repository**: https://github.com/steipete/Peekaboo
- **Configuration**: `~/.config/claude-code/config.json`

**Available Tools:**
- `mcp__peekaboo__image` - Capture screenshots with optional AI analysis
  - Supports background capture mode (non-intrusive)
  - Can target specific apps or windows
  - Multiple output formats (PNG, JPEG, Base64)
- `mcp__peekaboo__analyze` - Analyze existing image files
  - AI-powered image understanding
  - Text extraction and OCR
- `mcp__peekaboo__list` - List system items
  - Running applications
  - Application windows
  - Server status

**Primary Use Cases:**
- iOS Simulator screenshot capture for documentation
- Automated visual verification in testing workflows
- UI element detection and analysis
- Non-intrusive development monitoring

**Related Skills:**
- [ios-simulator-screenshot.md](../../.claude/skills/ios-simulator-screenshot.md)

**Related Commands:**
- `/screenshot` - Capture and optionally analyze simulator screenshots

**AI Provider Configuration:**
- Supports multiple AI providers for image analysis
- Configured via `PEEKABOO_AI_PROVIDERS` environment variable
- Available providers: Anthropic Claude, OpenAI, Ollama

---

### Linear Server MCP
- **Purpose**: Linear issue and project management
- **Repository**: https://github.com/linear/linear-mcp
- **Configuration**: `~/.config/claude-code/config.json`

**Available Tools:**
- Issue management: `list_issues`, `get_issue`, `create_issue`, `update_issue`
- Comments: `list_comments`, `create_comment`
- Projects: `list_projects`, `get_project`, `create_project`, `update_project`
- Teams: `list_teams`, `get_team`
- Users: `list_users`, `get_user`
- Labels: `list_issue_labels`, `create_issue_label`
- Status: `list_issue_statuses`, `get_issue_status`
- Cycles: `list_cycles`
- Documentation: `search_documentation`

**Primary Use Cases:**
- Create and manage Linear issues from Claude Code
- Track development tasks and bugs
- Update issue status and assignments
- Project planning and organization

**Configuration Notes:**
- Auto-assigns issues to user (Anton Novoselov) by default
- Integrated with VivaDicta development workflow

---

### Context7 MCP
- **Purpose**: Up-to-date library documentation and code examples
- **Configuration**: `~/.config/claude-code/config.json`

**Available Tools:**
- `mcp__context7__resolve-library-id` - Find library IDs
- `mcp__context7__get-library-docs` - Fetch library documentation

**Primary Use Cases:**
- Get current documentation for any programming library
- Access code examples and API references
- Stay updated with latest library versions

---

### DeepWiki MCP
- **Purpose**: GitHub repository documentation and analysis
- **Configuration**: `~/.config/claude-code/config.json`

**Available Tools:**
- `mcp__deepwiki__read_wiki_structure` - Get documentation topics
- `mcp__deepwiki__read_wiki_contents` - View repository documentation
- `mcp__deepwiki__ask_question` - Ask questions about repositories

**Primary Use Cases:**
- Understand third-party library implementations
- Research GitHub repository architectures
- Get context-aware answers about dependencies

---

### Apple Developer (Sosumi) MCP
- **Purpose**: Apple Developer documentation and Human Interface Guidelines
- **Configuration**: `~/.config/claude-code/config.json`

**Available Tools:**
- `mcp__sosumi__searchAppleDocumentation` - Search Apple docs
- `mcp__sosumi__fetchAppleDocumentation` - Fetch documentation by path

**Primary Use Cases:**
- Access Apple Developer documentation
- Reference Human Interface Guidelines
- Look up SwiftUI, UIKit, and iOS framework APIs

---

## Configuration

MCP servers are configured in `~/.config/claude-code/config.json`. Each server requires:
- Command to run the server
- Arguments and environment variables
- Optional authentication credentials

Example configuration structure:
```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["-y", "@steipete/peekaboo-mcp"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "anthropic/claude-opus-4,openai/gpt-4.1"
      }
    }
  }
}
```

## Adding New MCP Servers

When adding a new MCP server:
1. Add documentation to this directory
2. Update this README with server details
3. Document available tools and use cases
4. Create skills/commands if applicable
5. Note configuration requirements

## Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [Anthropic MCP Documentation](https://docs.anthropic.com/en/docs/mcp)
- [MCP Servers Registry](https://github.com/modelcontextprotocol/servers)
