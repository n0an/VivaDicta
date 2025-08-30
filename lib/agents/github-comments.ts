import { Octokit } from '@octokit/rest'

const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
})

export async function createOrUpdatePRComment(
  prNumber: number,
  body: string,
  commentId: string
): Promise<void> {
  const owner = process.env.GITHUB_REPOSITORY?.split('/')[0]
  const repo = process.env.GITHUB_REPOSITORY?.split('/')[1]
  
  if (!owner || !repo) {
    throw new Error('GITHUB_REPOSITORY environment variable not found')
  }
  
  try {
    // Look for existing comment
    const { data: comments } = await octokit.rest.issues.listComments({
      owner,
      repo,
      issue_number: prNumber
    })
    
    const existingComment = comments.find(comment => 
      comment.body?.includes(`<!-- ${commentId} -->`)
    )
    
    const commentBody = `${body}\n\n<!-- ${commentId} -->`
    
    if (existingComment) {
      // Update existing comment
      await octokit.rest.issues.updateComment({
        owner,
        repo,
        comment_id: existingComment.id,
        body: commentBody
      })
      console.log(`✅ Updated existing comment #${existingComment.id}`)
    } else {
      // Create new comment
      const { data: newComment } = await octokit.rest.issues.createComment({
        owner,
        repo,
        issue_number: prNumber,
        body: commentBody
      })
      console.log(`✅ Created new comment #${newComment.id}`)
    }
  } catch (error) {
    console.error('❌ Error creating/updating PR comment:', error)
    throw error
  }
}

export async function getPRComments(prNumber: number) {
  const owner = process.env.GITHUB_REPOSITORY?.split('/')[0]
  const repo = process.env.GITHUB_REPOSITORY?.split('/')[1]
  
  if (!owner || !repo) {
    throw new Error('GITHUB_REPOSITORY environment variable not found')
  }
  
  const { data: comments } = await octokit.rest.issues.listComments({
    owner,
    repo,
    issue_number: prNumber
  })
  
  return comments
}
