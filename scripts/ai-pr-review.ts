#!/usr/bin/env tsx

import { runAIFlow } from '../lib/agents/flow-runner'

async function main() {
  try {
    console.log('🤖 Starting AI PR Review Agent...')
    await runAIFlow()
    console.log('✅ AI PR Review completed successfully')
  } catch (error) {
    console.error('❌ AI PR Review failed:', error)
    process.exit(1)
  }
}

main()
