import { openai, createOpenAI } from '@ai-sdk/openai'
import { anthropic, createAnthropic } from '@ai-sdk/anthropic'
import type { LanguageModel } from 'ai'

const LLM_PROVIDER = process.env.LLM_PROVIDER || 'openai'

/**
 * Returns the configured LLM model instance for use with AI SDK's generateObject
 */
export function getLLMModel(): LanguageModel {
  switch (LLM_PROVIDER.toLowerCase()) {
    case 'openai':
      return getOpenAIModel()
    case 'anthropic':
      return getAnthropicModel()
    default:
      throw new Error(`Unsupported LLM provider: ${LLM_PROVIDER}`)
  }
}

function getOpenAIModel(): LanguageModel {
  const apiKey = process.env.OPENAI_API_KEY
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY environment variable is required')
  }

  const modelName = process.env.LLM_MODEL || 'gpt-4o'
  console.log(`🤖 Using OpenAI model: ${modelName}`)
  
  // Create OpenAI provider with API key
  const openaiProvider = createOpenAI({
    apiKey: apiKey
  })
  
  return openaiProvider(modelName)
}

function getAnthropicModel(): LanguageModel {
  const apiKey = process.env.ANTHROPIC_API_KEY
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY environment variable is required')
  }

  const modelName = process.env.LLM_MODEL || 'claude-opus-4-1-20250805'
  console.log(`🤖 Using Anthropic model: ${modelName}`)
  
  // Create Anthropic provider with API key
  const anthropicProvider = createAnthropic({
    apiKey: apiKey
  })
  
  return anthropicProvider(modelName)
}

// Legacy function for backward compatibility - can be removed after migration
export async function callLLM(prompt: string): Promise<string> {
  console.warn('⚠️  callLLM is deprecated. Use getLLMModel() with generateObject instead.')
  
  // This is a simplified fallback that maintains existing behavior
  // but doesn't provide the type safety benefits of generateObject
  const model = getLLMModel()
  
  // For now, we'll throw an error to force migration to the new pattern
  throw new Error('callLLM is deprecated. Please migrate to using getLLMModel() with generateObject for type-safe responses.')
}
