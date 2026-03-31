#!/bin/bash
# Iteratively find missing modules and report them
cd /home/roger/.openclaw/workspace/claude-code
export PATH="$HOME/.bun/bin:$PATH"

for i in $(seq 1 50); do
  output=$(timeout 5 bun run src/main.tsx --help 2>&1)
  if echo "$output" | grep -q "Cannot find module"; then
    mod=$(echo "$output" | grep "Cannot find module" | sed "s/.*module '//;s/' from.*//")
    file=$(echo "$output" | grep "Cannot find module" | sed "s/.*from '//;s/'$//")
    echo "MISSING: $mod (imported from $file)"
    
    # Check if it's a local file with wrong extension
    dir=$(dirname "$file")
    base=$(echo "$mod" | sed 's/\.js$//')
    tsfile="$dir/$base.ts"
    tsxfile="$dir/$base.tsx"
    
    if [ -f "$tsfile" ]; then
      echo "  -> EXISTS as $tsfile (extension issue)"
    elif [ -f "$tsxfile" ]; then
      echo "  -> EXISTS as $tsxfile (extension issue)"
    else
      echo "  -> GENUINELY MISSING"
    fi
  elif echo "$output" | grep -q "error:"; then
    err=$(echo "$output" | grep "error:" | head -1)
    echo "OTHER ERROR: $err"
    break
  else
    echo "SUCCESS (or different error)"
    echo "$output" | head -5
    break
  fi
done
