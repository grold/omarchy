#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

brain_dir="$test_home/.gemini/antigravity/brain"
mkdir -p "$brain_dir/session-1/.system_generated/logs"
mkdir -p "$brain_dir/session-2/.system_generated/logs"

today=$(date +%Y-%m-%d)
yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

cat >"$brain_dir/session-1/.system_generated/logs/transcript.jsonl" <<EOF
{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","created_at":"${yesterday}T10:00:00Z"}
{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"${yesterday}T10:00:05Z"}
{"step_index":2,"source":"USER_EXPLICIT","type": "USER_INPUT","created_at":"${today}T08:00:00Z"}
EOF

cat >"$brain_dir/session-2/.system_generated/logs/transcript.jsonl" <<EOF
{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","created_at":"${today}T09:00:00Z"}
EOF

result=$(HOME="$test_home" "$ROOT/bin/omarchy-agent-usage-agy")

RESULT_JSON="$result" TODAY="$today" YESTERDAY="$yesterday" run_node_test <<'JS'
const data = JSON.parse(process.env.RESULT_JSON)
const today = process.env.TODAY
const yesterday = process.env.YESTERDAY

assert(data.id === 'agy', 'id is agy')
assert(data.name === 'Antigravity', 'name is Antigravity')
assert(data.totalPrompts === 3, 'totalPrompts counts all USER_INPUT entries')
assert(data.todayPrompts === 2, 'todayPrompts only counts today entries')
assert(data.todaySessions === 2, 'todaySessions counts unique sessions active today')
assert(data.totalSessions === 2, 'totalSessions counts all session directories')
assert(data.activeDates.includes(today) && data.activeDates.includes(yesterday), 'activeDates includes both days')
assert(data.activeDays === 2, 'activeDays is 2')

const todayDay = data.recentDays.find(d => d.date === today)
const yesterdayDay = data.recentDays.find(d => d.date === yesterday)
assert(todayDay && todayDay.messageCount === 2, 'recentDays has 2 for today')
assert(yesterdayDay && yesterdayDay.messageCount === 1, 'recentDays has 1 for yesterday')
JS
