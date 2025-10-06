# Create Skill

Use this skill when you need to create a new skill for the skill library, either from scratch or based on a completed workflow.

## When to Create a New Skill

Create a new skill when:
- A user explicitly asks: "create a skill for [task]"
- After completing a workflow, user says: "save that as a skill" or "create a skill from what we just did"
- You notice a pattern that would benefit from documentation
- An existing skill needs a variant that's significantly different

## Skill Creation Flow

### 1. Determine skill type and gather information

**From Scratch:**
- Ask clarifying questions if needed
- Identify the core problem being solved
- Determine decision points and variations

**From Completed Workflow:**
- Review the conversation history
- Extract the key steps performed
- Note any decisions made and why
- Capture any errors encountered and how they were resolved

### 2. Create the skill file

Follow this template structure:

~~~~md
# [Skill Name - Use Title Case]

Use this skill when [specific, clear trigger scenario].

## Related Skills

- See [`related-skill-1.md`](./related-skill-1.md) if [specific condition]
- See [`related-skill-2.md`](./related-skill-2.md) for [specific relationship]

## Skill Flow

- Example query: "[real example from user or realistic example]"
- Notes:
  - [Critical information that applies to all paths]
  - [Important conventions or requirements]
  - [Any manual steps or things AI cannot do]

### 1. [Decision Point or First Step]

[If there's a decision to make, present options clearly:]

**Option A** if:
- [Condition 1]
- [Condition 2]

→ Continue with **Path A** (steps 2A-NA)

**Option B** if:
- [Condition 1]
- [Condition 2]

→ Continue with **Path B** (steps 2B-NB)

[If no decision needed, go straight to the step:]

Location: `path/to/file.ext`

~~~language
// Actual code example from the workflow
// Or realistic example if creating from scratch
~~~

## Path A: [Descriptive Name]

### 2A. [Step Name]

Location: `path/to/file.ext`

~~~language
// Code for this step
~~~

### 3A. [Next Step Name]

[Continue numbering...]

## Path B: [Descriptive Name]

### 2B. [Step Name]

[Parallel structure to Path A]
~~~~

### 3. Update the skill index

Location: `.claude/skills/CLAUDE.md`

Add to `## Skill List`:

~~~markdown
- [`skill-file-name.md`](./skill-file-name.md): [Brief description of what the skill does]
~~~

Add to `## Skill Directory`:

~~~markdown
### [Skill Name]

For [brief description of purpose].

- Skill file: [`skill-file-name.md`](./skill-file-name.md)
- Related queries:
  - "[Example query 1]"
  - "[Example query 2]"
  - "[Example query 3]"
~~~