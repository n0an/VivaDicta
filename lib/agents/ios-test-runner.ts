import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

export interface TestResult {
  success: boolean
  output: string
  testsRun: number
  testsPassed: number
  testsFailed: number
  duration: string
  failureDetails?: string[]
}

async function findBestSimulatorDestination(): Promise<string> {
  try {
    // Get iPhone simulators specifically
    const { stdout } = await execAsync('xcodebuild -scheme VivaDicta -workspace ./VivaDicta.xcodeproj/project.xcworkspace -showdestinations 2>/dev/null | grep "iOS Simulator" | grep "iPhone"')
    
    console.log('📱 Available iPhone Simulator destinations:')
    console.log(stdout.trim().split('\n').slice(0, 10).join('\n')) // Show first 10 for brevity
    
    const lines = stdout.split('\n').filter(line => line.trim())
    
    // Preferred simulator patterns in order of preference
    const preferredPatterns = [
      /iPhone 16 Pro.*OS:18\.1/,   // iPhone 16 Pro with iOS 18.1
      /iPhone 16 Pro.*OS:18\./,    // iPhone 16 Pro with any iOS 18.x
      /iPhone 16.*OS:18\.1/,       // iPhone 16 with iOS 18.1
      /iPhone 16.*OS:18\./,        // iPhone 16 with any iOS 18.x
      /iPhone 15 Pro.*OS:18\./,    // iPhone 15 Pro with iOS 18.x
      /iPhone 15.*OS:18\./,        // iPhone 15 with iOS 18.x
      /iPhone 14.*OS:18\./,        // iPhone 14 with iOS 18.x
      /iPhone 13.*OS:18\./,        // iPhone 13 with iOS 18.x
      /iPhone.*OS:18\./,           // Any iPhone with iOS 18.x
      /iPhone/                     // Any iPhone (fallback)
    ]
    
    // Try to find the best match
    for (const pattern of preferredPatterns) {
      const matchingLine = lines.find(line => pattern.test(line))
      if (matchingLine) {
        // Extract destination info from line like:
        // { platform:iOS Simulator, arch:arm64, id:XXX, OS:18.1, name:iPhone 16 Pro }
        const nameMatch = matchingLine.match(/name:([^,}]+)/)
        const osMatch = matchingLine.match(/OS:([^,}]+)/)
        
        if (nameMatch && osMatch) {
          const name = nameMatch[1].trim()
          const osVersion = osMatch[1].trim()
          const destination = `platform=iOS Simulator,name=${name},OS=${osVersion}`
          console.log(`✅ Selected: ${destination}`)
          return destination
        }
      }
    }
    
    // If no perfect match, use first available iPhone
    const firstiPhoneLine = lines[0]
    if (firstiPhoneLine) {
      const nameMatch = firstiPhoneLine.match(/name:([^,}]+)/)
      const osMatch = firstiPhoneLine.match(/OS:([^,}]+)/)
      
      if (nameMatch && osMatch) {
        const name = nameMatch[1].trim()
        const osVersion = osMatch[1].trim()
        const destination = `platform=iOS Simulator,name=${name},OS=${osVersion}`
        console.log(`✅ Fallback selected: ${destination}`)
        return destination
      }
    }
    
    // Ultimate fallback
    console.log('⚠️ Using ultimate fallback destination')
    return 'platform=iOS Simulator,name=Any iOS Simulator Device'
    
  } catch (error) {
    console.log('⚠️ Failed to detect simulators, using simple fallback')
    console.log(`Error: ${error}`)
    // Simple fallback that should work on most systems
    return 'platform=iOS Simulator,name=Any iOS Simulator Device'
  }
}

export async function runIOSTests(): Promise<TestResult> {
  console.log('🧪 Running iOS tests...')
  
  // Try to find the best available simulator
  const destination = await findBestSimulatorDestination()
  console.log(`📱 Using destination: ${destination}`)
  
  const testCommand = `xcodebuild test -scheme VivaDicta -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination "${destination}" CODE_SIGNING_ALLOWED=NO`
  
  try {
    const startTime = Date.now()
    const { stdout, stderr } = await execAsync(testCommand, {
      cwd: process.cwd(),
      timeout: 300000, // 5 minutes timeout
      maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    })
    
    const endTime = Date.now()
    const duration = `${((endTime - startTime) / 1000).toFixed(1)}s`
    
    const output = stdout + stderr
    
    // Parse test results from xcodebuild output
    const testResult = parseTestOutput(output, duration)
    
    console.log(`✅ iOS tests completed: ${testResult.testsPassed}/${testResult.testsRun} passed`)
    
    return testResult
    
  } catch (error: any) {
    console.error('❌ iOS tests failed:', error.message)
    
    const output = error.stdout + error.stderr || error.message
    const testResult = parseTestOutput(output, '0s')
    testResult.success = false
    
    return testResult
  }
}

function parseTestOutput(output: string, duration: string): TestResult {
  const lines = output.split('\n')
  
  // Look for test summary patterns
  let testsRun = 0
  let testsPassed = 0
  let testsFailed = 0
  let success = false
  const failureDetails: string[] = []
  
  // Parse xcodebuild test output
  for (const line of lines) {
    // Look for test execution summary
    if (line.includes('Test Suite') && line.includes('passed')) {
      success = true
    }
    
    if (line.includes('Test Suite') && line.includes('failed')) {
      success = false
    }
    
    // Look for individual test results
    if (line.includes('Test Case') && line.includes('passed')) {
      testsPassed++
      testsRun++
    }
    
    if (line.includes('Test Case') && line.includes('failed')) {
      testsFailed++
      testsRun++
      // Extract failure details
      const failureMatch = line.match(/Test Case.*failed.*\((.*)\)/)
      if (failureMatch) {
        failureDetails.push(failureMatch[1])
      }
    }
    
    // Look for Testing framework results
    if (line.includes('Testing') && line.includes('passed')) {
      const passedMatch = line.match(/(\d+) passed/)
      if (passedMatch) {
        testsPassed = parseInt(passedMatch[1])
        testsRun += testsPassed
        success = true
      }
    }
    
    if (line.includes('Testing') && line.includes('failed')) {
      const failedMatch = line.match(/(\d+) failed/)
      if (failedMatch) {
        testsFailed = parseInt(failedMatch[1])
        testsRun += testsFailed
        success = false
      }
    }
    
    // Collect failure details
    if (line.includes('failed') && line.includes('error:')) {
      failureDetails.push(line.trim())
    }
  }
  
  // If no specific test counts found, assume basic success/failure based on output
  if (testsRun === 0) {
    if (output.includes('TEST SUCCEEDED') || output.includes('All tests passed') || success) {
      testsRun = 1
      testsPassed = 1
      success = true
    } else if (output.includes('TEST FAILED') || output.includes('failed') || output.includes('error')) {
      testsRun = 1
      testsFailed = 1
      success = false
      failureDetails.push('Test execution failed - check logs for details')
    } else {
      // Default case
      testsRun = 1
      testsPassed = 1
      success = true
    }
  }
  
  return {
    success,
    output,
    testsRun,
    testsPassed,
    testsFailed,
    duration,
    failureDetails: failureDetails.length > 0 ? failureDetails : undefined
  }
}
