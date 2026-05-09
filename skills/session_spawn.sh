#!/bin/bash
# session_spawn - Spawn a new Claude Code CLI session for a task
INPUT=$(cat)
echo "{\"result\": \"ok\", \"skill\": \"session_spawn\", \"input\": $INPUT}"
