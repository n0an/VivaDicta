import { Octokit } from '@octokit/rest'

const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
})

export interface PRContext {
  number: number
  title: string
  description: string | null
  author: string
  targetBranch: string
  sourceBranch: string
  commits: Array<{
    sha: string
    message: string
    author: string
  }>
  changedFiles: Array<{
    filename: string
    status: string
    additions: number
    deletions: number
    content: string
  }>
}

export async function getPRContext(): Promise<PRContext | null> {
  const prNumber = getPRNumber()
  if (!prNumber) {
    console.log('No PR number found in environment')
    return null
  }

  const owner = process.env.GITHUB_REPOSITORY?.split('/')[0]
  const repo = process.env.GITHUB_REPOSITORY?.split('/')[1]
  
  if (!owner || !repo) {
    throw new Error('GITHUB_REPOSITORY environment variable not found')
  }

  try {
    // Get PR details
    const { data: pr } = await octokit.rest.pulls.get({
      owner,
      repo,
      pull_number: prNumber
    })

    // Get PR commits
    const { data: commits } = await octokit.rest.pulls.listCommits({
      owner,
      repo,
      pull_number: prNumber
    })

    // Get changed files
    const { data: files } = await octokit.rest.pulls.listFiles({
      owner,
      repo,
      pull_number: prNumber
    })

    // Get file contents for changed files
    const changedFiles = await Promise.all(
      files
        .filter(file => shouldIncludeFile(file.filename))
        .map(async (file) => {
          try {
            const content = await getFileContent(owner, repo, file.filename, pr.head.sha)
            return {
              filename: file.filename,
              status: file.status,
              additions: file.additions,
              deletions: file.deletions,
              content: content || ''
            }
          } catch (error) {
            console.warn(`Could not fetch content for ${file.filename}:`, error)
            return {
              filename: file.filename,
              status: file.status,
              additions: file.additions,
              deletions: file.deletions,
              content: `[Content could not be retrieved: ${error}]`
            }
          }
        })
    )

    return {
      number: prNumber,
      title: pr.title,
      description: pr.body,
      author: pr.user?.login || 'unknown',
      targetBranch: pr.base.ref,
      sourceBranch: pr.head.ref,
      commits: commits.map(commit => ({
        sha: commit.sha,
        message: commit.commit.message,
        author: commit.commit.author?.name || 'unknown'
      })),
      changedFiles
    }
  } catch (error) {
    console.error('Error fetching PR context:', error)
    throw error
  }
}

function getPRNumber(): number | null {
  // Try to get PR number from GITHUB_EVENT_PATH
  if (process.env.GITHUB_EVENT_PATH) {
    try {
      const fs = require('fs')
      const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'))
      return event.pull_request?.number || null
    } catch (error) {
      console.warn('Could not parse GitHub event:', error)
    }
  }
  
  // Try to get from GITHUB_REF for pull request events
  if (process.env.GITHUB_REF?.startsWith('refs/pull/')) {
    const match = process.env.GITHUB_REF.match(/refs\/pull\/(\d+)\//)
    return match ? parseInt(match[1]) : null
  }
  
  return null
}

async function getFileContent(
  owner: string,
  repo: string,
  path: string,
  ref: string
): Promise<string | null> {
  try {
    const { data } = await octokit.rest.repos.getContent({
      owner,
      repo,
      path,
      ref
    })
    
    if ('content' in data && data.content) {
      return Buffer.from(data.content, 'base64').toString('utf-8')
    }
    
    return null
  } catch (error) {
    if (error.status === 404) {
      // File might be deleted or renamed
      return null
    }
    throw error
  }
}

function shouldIncludeFile(filename: string): boolean {
  // Skip files that are too large or not useful for review
  const excludePatterns = [
    /node_modules\//,
    /\.lock$/,
    /package-lock\.json$/,
    /yarn\.lock$/,
    /\.png$/,
    /\.jpg$/,
    /\.jpeg$/,
    /\.gif$/,
    /\.svg$/,
    /\.ico$/,
    /\.woff/,
    /\.ttf$/,
    /\.eot$/,
    /\.DS_Store$/,
    /\.git/,
    /\.xcuserstate$/,
    /\.xcworkspacedata$/,
    /\.resolved$/,
    /Pods\//,
    /build\//,
    /DerivedData\//
  ]
  
  return !excludePatterns.some(pattern => pattern.test(filename))
}
