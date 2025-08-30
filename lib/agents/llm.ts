import OpenAI from 'openai'
import Anthropic from '@anthropic-ai/sdk'

const LLM_PROVIDER = process.env.LLM_PROVIDER || 'openai'

export async function callLLM(prompt: string): Promise<string> {
  switch (LLM_PROVIDER.toLowerCase()) {
    case 'openai':
      return await callOpenAI(prompt)
    case 'anthropic':
      return await callAnthropic(prompt)
    default:
      throw new Error(`Unsupported LLM provider: ${LLM_PROVIDER}`)
  }
}

async function callOpenAI(prompt: string): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY environment variable is required')
  }

  const client = new OpenAI({ apiKey })
  const model = process.env.LLM_MODEL || 'gpt-4o'

  console.log(`🤖 Using OpenAI model: ${model}`)

  try {
    const response = await client.chat.completions.create({
      model,
      messages: [
        {
          role: 'system',
          content: 'You are an expert code reviewer with deep knowledge of software engineering best practices, security, performance, and maintainability. You specialize in iOS development with Swift and are familiar with modern development patterns.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.1,
      max_tokens: 4000
    })

    const content = response.choices[0]?.message?.content
    if (!content) {
      throw new Error('No content received from OpenAI')
    }

    return content
  } catch (error) {
    console.error('Error calling OpenAI:', error)
    throw error
  }
}

async function callAnthropic(prompt: string): Promise<string> {
  const apiKey = process.env.ANTHROPIC_API_KEY
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY environment variable is required')
  }

  const client = new Anthropic({ apiKey })
  const model = process.env.LLM_MODEL || 'claude-3-5-sonnet-20241022'

  console.log(`🤖 Using Anthropic model: ${model}`)

  try {
    const response = await client.messages.create({
      model,
      max_tokens: 4000,
      temperature: 0.1,
      system: 'You are an expert code reviewer with deep knowledge of software engineering best practices, security, performance, and maintainability. You specialize in iOS development with Swift and are familiar with modern development patterns.',
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    })

    const content = response.content[0]
    if (content.type !== 'text') {
      throw new Error('Unexpected response type from Anthropic')
    }

    return content.text
  } catch (error) {
    console.error('Error calling Anthropic:', error)
    throw error
  }
}
