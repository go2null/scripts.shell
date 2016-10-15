#!/bin/sh

date_time() {
  sleep 1
  date +'%Y%m%d-%H%M%S'
}

settings() {
  [ "$1" ] && a="$1" || a=$(git config core.autocrlf)
  [ "$2" ] && e="$2" || e=$(git config core.eol)
  printf '%-14s  %-10s' "autocrlf=$a" "eol=$e"
}

report() {
  if [ "$1" ]; then
    change="$1"
  elif ! grep -zP '\r\n' "$crlf_file" >/dev/null; then
    change='CRLF->LF'
  elif grep -zP '\r\n' "$lf_file" >/dev/null; then
    change='LF->CRLF'
  else
    change='no-change'
  fi

  printf '%-8s %-6s %-10s  %-8s %-6s %-9s\n' \
    "$set_a" \
    "$set_e" \
    "$report_input" \
    "$(git config core.autocrlf)" \
    "$(git config core.eol)"      \
    "$change"
}

dir='git-eol-demo'
crlf_file='crlf.bat'
lf_file='lf.sh'
report_file="../$dir.txt"
rm -rf "$dir"
mkdir "$dir"
cd "$dir"
git init

# in case not set globally
git config user.name  'Git EOL'
git config user.email 'git.eol@example.com'

# in case user has it set to 'true'
git config core.safecrlf warn

autocrlf='false input true'
eol='native crlf lf'

printf '%-26s  %s\n' \
  'Check in files'          'Check out files'             > "$report_file"
printf '%-8s %-6s %-10s  %-8s %-6s %s\n' \
  'AUTOCRLF' 'EOL' 'COMMIT' 'AUTOCRLF' 'EOL' 'CONVERSION' >> "$report_file"

# loop through each autocrlf/eol combination
for set_a in $(echo $autocrlf); do
  for set_e in $(echo $eol); do
    printf '\n%52s\n' "=" | tr ' ' '='
    printf '%-15s  %s\n' 'IN:' "$(settings "$set_a" "$set_e")"

    git config core.autocrlf $set_a
    git config core.eol $set_e

    dt="$(date_time)" # ensure have something to commit
    printf '%-15s  %s  %4s \r\n' "$dt" "$(settings $set_a $set_e)" 'crlf' > "$crlf_file"
    printf '%-15s  %s  %4s \n'   "$dt" "$(settings $set_a $set_e)"   'lf' > "$lf_file"
    cat -ve *

    git add .
    commit_response=$(git commit -m "$dt core.autocrlf=$set_a core.eol=$set_e" 2>&1 | head -1)
    if echo "$commit_response" | grep 'LF will be replaced by CRLF'; then
      report_input='LF->CRLF'
    elif echo "$commit_response" | grep 'CRLF will be replaced by LF'; then
      report_input='CRLF->LF'
    elif echo "$commit_response" | grep 'conflicts'; then
      report_input='CONFLICT'
    else
      report_input='no-warning'
    fi

    for outA in $(echo $autocrlf); do
      for outE in $(echo $eol); do
        git config core.autocrlf $outA
        git config core.eol $outE
        printf '\n%-15s  %s\n' 'OUT:' "$(settings)"

        rm -f * # -f as if previous reset fails, then files wouldn't exist
        if git reset --hard HEAD >/dev/null; then
          cat -ve *
          report >> "$report_file"
        else
          report 'CONFLICT' >> "$report_file"
        fi
      done
    done
  done
done

grep -v 'no-warning.*no-change' "$report_file" | grep '[A-Z\>-]'
