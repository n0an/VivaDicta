# AI PR Review System for VivaDicta

This repository includes an AI-powered Pull Request review system that automatically analyzes code changes and provides detailed feedback when PRs are opened or updated.

## Features

🤖 **Automated Code Reviews**: AI analyzes your Swift/iOS code changes and provides detailed feedback
📝 **PR Comments**: Reviews are posted as comments directly on your Pull Requests
🔍 **Multi-Language Support**: Works with Swift, TypeScript, and other languages in your codebase
⚡ **Fast Feedback**: Get code reviews within minutes of opening a PR

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure AI Provider

You need to set up either OpenAI or Anthropic API access:

#### Option A: OpenAI (Recommended)
1. Get an API key from [OpenAI](https://platform.openai.com/)
2. Add it to your GitHub repository secrets as `OPENAI_API_KEY`

#### Option B: Anthropic
1. Get an API key from [Anthropic](https://console.anthropic.com/)
2. Add it to your GitHub repository secrets as `ANTHROPIC_API_KEY`
3. Set the repository variable `LLM_PROVIDER` to `anthropic`

### 3. Repository Configuration

1. **GitHub Secrets**: Go to your repository Settings > Secrets and variables > Actions
   - Add `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` (depending on your choice)

2. **Repository Variables** (Optional):
   - `LLM_PROVIDER`: Set to `openai` (default) or `anthropic`
   - `LLM_MODEL`: Override the default model (e.g., `gpt-4o`, `claude-3-5-sonnet-20241022`)

### 4. Test the Setup

1. Create a new branch
2. Make some code changes
3. Open a Pull Request to the `main` branch
4. Watch the AI review appear in the PR comments!

## How It Works

1. **Trigger**: The system activates when you open or update a PR targeting the `main` branch
2. **Analysis**: The AI analyzes all changed files, commit messages, and PR context
3. **Review**: Generates a comprehensive code review focusing on:
   - Code quality and best practices
   - Potential bugs or issues
   - Performance considerations
   - Security concerns
   - Swift/iOS specific recommendations
4. **Comment**: Posts the review as a comment on your PR

## File Structure

```
├── .github/workflows/ai-agent.yml    # GitHub Actions workflow
├── scripts/ai-pr-review.ts           # Main entry point
├── lib/agents/                       # AI agent modules
│   ├── flow-runner.ts                # Orchestrates the review process
│   ├── code-review.ts                # Generates code reviews
│   ├── github-comments.ts            # Manages PR comments
│   ├── pr-context.ts                 # Gathers PR information
│   └── llm.ts                        # AI provider interface
├── package.json                      # Dependencies
├── tsconfig.json                     # TypeScript configuration
└── ai-config.example                 # Environment variables example
```

## Customization

### Review Focus Areas

The AI reviews focus on:
- **Swift/iOS Best Practices**: Architecture patterns, memory management, threading
- **Code Quality**: Readability, maintainability, DRY principles
- **Security**: Input validation, data handling, permissions
- **Performance**: Efficient algorithms, memory usage, UI responsiveness
- **Testing**: Test coverage and quality (when tests are present)

### Excluded Files

The system automatically excludes:
- Binary files (images, frameworks)
- Generated files (Xcode user data, build artifacts)
- Dependencies (node_modules, Pods)
- Large files that would exceed token limits

## Troubleshooting

### Common Issues

1. **No review appears**: Check that you have the required API key set in repository secrets
2. **Review fails**: Check the Actions tab for detailed error logs
3. **Incomplete reviews**: Very large PRs might hit token limits - consider breaking them into smaller PRs

### Debugging

1. Go to Actions tab in your GitHub repository
2. Click on the failed workflow run
3. Check the "AI Agent PR Review" job logs for detailed error information

## Cost Considerations

- **OpenAI**: Approximately $0.01-0.10 per review depending on PR size
- **Anthropic**: Similar pricing structure
- Costs scale with the amount of code changed in each PR

## Contributing

To modify the AI review behavior:
1. Edit the prompt in `lib/agents/code-review.ts`
2. Adjust file filtering in `lib/agents/pr-context.ts`
3. Customize comment formatting in `lib/agents/flow-runner.ts`

## Support

If you encounter issues:
1. Check the GitHub Actions logs
2. Verify your API keys are correctly set
3. Ensure your repository has the necessary permissions for Actions
