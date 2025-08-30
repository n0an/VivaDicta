import { callLLM } from './llm'
import { PRContext } from './pr-context'

export interface CodeReviewResponse {
  summary: string
  files: Array<{
    filename: string
    summary: string
    suggestions: string[]
  }>
  overallSuggestions: string[]
}

export async function generateCodeReview(prContext: PRContext): Promise<CodeReviewResponse> {
  const prompt = buildCodeReviewPrompt(prContext)
  
  console.log('🤖 Calling LLM for code review...')
  const response = await callLLM(prompt)
  
  try {
    return JSON.parse(response)
  } catch (error) {
    console.error('Error parsing LLM response:', error)
    console.error('Raw response:', response)
    
    // Fallback response
    return {
      summary: 'Error parsing AI response. The AI provided feedback but it could not be properly formatted.',
      files: [],
      overallSuggestions: ['Please review the code manually due to AI parsing error.']
    }
  }
}

function buildCodeReviewPrompt(prContext: PRContext): string {
  return `You are an expert code reviewer. Please provide a comprehensive code review for this Pull Request.

**PR Information:**
- Title: ${prContext.title}
- Description: ${prContext.description || 'No description provided'}
- Author: ${prContext.author}
- Target Branch: ${prContext.targetBranch}
- Source Branch: ${prContext.sourceBranch}

**Recent Commits:**
${prContext.commits.map(c => `- ${c.message} (${c.author})`).join('\n')}

**Changed Files:**
${prContext.changedFiles.map(f => 
  `\n### File: ${f.filename}
Status: ${f.status}
Changes: +${f.additions} -${f.deletions}

\`\`\`${getFileExtension(f.filename)}
${f.content}
\`\`\``
).join('\n')}

Please provide your review in the following JSON format:

{
  "summary": "A brief overview of the changes and overall assessment",
  "files": [
    {
      "filename": "path/to/file",
      "summary": "What this file does and changes made",
      "suggestions": ["Specific suggestion 1", "Specific suggestion 2"]
    }
  ],
  "overallSuggestions": ["Overall suggestion 1", "Overall suggestion 2"]
}

Focus on:
- Code quality and best practices
- Potential bugs or issues
- Performance considerations
- Security concerns
- Maintainability and readability
- Swift/iOS specific best practices (since this is an iOS app)
- Architecture and design patterns

Provide constructive, actionable feedback. Be thorough but concise.`
}

function getFileExtension(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase()
  
  const extensionMap: { [key: string]: string } = {
    'swift': 'swift',
    'ts': 'typescript',
    'tsx': 'typescript',
    'js': 'javascript',
    'jsx': 'javascript',
    'json': 'json',
    'md': 'markdown',
    'yml': 'yaml',
    'yaml': 'yaml'
  }
  
  return extensionMap[ext || ''] || ''
}
