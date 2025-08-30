import { z } from 'zod'
import { generateObject } from 'ai'
import { getLLMModel } from './llm'
import { PRContext } from './pr-context'

// Zod schema for type-safe LLM responses
const reviewSchema = z.object({
  summary: z.string().describe('A brief overview of the changes and overall assessment'),
  fileAnalyses: z.array(
    z.object({
      path: z.string().describe('The file path'),
      analysis: z.string().describe('Analysis of what this file does and changes made')
    })
  ).describe('Analysis of each changed file'),
  overallSuggestions: z.array(z.string()).describe('Overall suggestions for the PR')
})

export type CodeReviewResponse = z.infer<typeof reviewSchema>

export async function generateCodeReview(prContext: PRContext): Promise<CodeReviewResponse> {
  const prompt = buildCodeReviewPrompt(prContext)
  
  console.log('🤖 Calling LLM for code review...')
  console.log(`\n\n\n\n\n--------------------------------`)
  console.log(`Review prompt:\n${prompt}`)
  console.log(`--------------------------------\n\n\n\n\n`)

  // Obtain the configured LLM model (OpenAI or Anthropic, etc.)
  const modelInfo = getLLMModel()

  try {
    // Use ai-sdk's generateObject to parse strictly into the schema we declared above.
    const result = await generateObject({
      model: modelInfo,
      schema: reviewSchema,
      schemaName: "review",
      schemaDescription: "Code review feedback in JSON",
      prompt
    })

    return result.object
  } catch (error) {
    console.error('Error calling LLM with generateObject:', error)
    
    // Fallback response with the new schema structure
    return {
      summary: 'Error generating AI review. The AI service encountered an issue.',
      fileAnalyses: [],
      overallSuggestions: ['Please review the code manually due to AI service error.']
    }
  }
}



function buildCodeReviewPrompt(prContext: PRContext): string {
  const changedFilesPrompt = prContext.changedFiles.map(f => 
    `\n### File: ${f.filename}
Status: ${f.status}
Changes: +${f.additions} -${f.deletions}

\`\`\`${getFileExtension(f.filename)}
${f.content}
\`\`\``
  ).join('\n')

  return `You are an expert code reviewer. Return valid JSON only, with the structure:
{
  "summary": "string",
  "fileAnalyses": [
    { "path": "string", "analysis": "string" }
  ],
  "overallSuggestions": ["string"]
}

PR Title: ${prContext.title}
PR Description: ${prContext.description || 'No description provided'}
Author: ${prContext.author}
Target Branch: ${prContext.targetBranch}
Source Branch: ${prContext.sourceBranch}

Commits:
${prContext.commits.map(c => `- ${c.message} (${c.author})`).join('\n')}

Changed Files:
${changedFilesPrompt}

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

