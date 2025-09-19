# Create Command

You are given the following context:
$ARGUMENTS

## Instructions

You task is to create a new custom command that we can use with Claude Code.

Anytime you are asked to create a new command, create it at the following path:

```
.claude/commands/
  - <command-name>.md
```

Please format the command as follows:

```
# <command-name>

You are given the following context:
$ARGUMENTS

<command-here>
```
