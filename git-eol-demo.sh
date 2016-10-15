#!/bin/sh

settings() {
  [ "$1" ] && a="$1" || a=$(git config core.autocrlf)
  [ "$2" ] && e="$2" || e=$(git config core.eol)
  printf '%-14s  %-10s' "autocrlf=$a" "eol=$e"
}

report() {
  if [ "$1" ]; then
    change="$1"
  else
    case $(cat -ve * | grep '\^M\$$' | wc -l) in
      2) change='LF>CRLF'   ;;
      1) change='no-change' ;;
      0) change='CRLF>LF'   ;;
      *) change='UNKNOWN'   ;;
    esac
  fi

  printf '%-8s %-6s %-10s  %-8s %-6s %-9s\n' \
    "$inA" \
    "$inE" \
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
eol='native lf crlf'

printf '%-26s  %s\n' \
  'Check in files'          'Check out files'              > "$report_file"
printf '%-8s %-6s %-10s  %-8s %-6s %s\n' \
  'AUTOCRLF' 'EOL' 'COMMIT' 'AUTOCRLF' 'EOL' 'CONVERSION' >> "$report_file"

# loop through each autocrlf/eol combination
for inA in $(echo $autocrlf); do
  for inE in $(echo $eol); do
    printf '\n%52s\n' "=" | tr ' ' '='
    printf '%-15s  %s\n' 'IN:' "$(settings "$inA" "$inE")"

    git config core.autocrlf $inA
    git config core.eol $inE

    counter=$(($counter+1)) # ensure have something to commit
    printf '%-15s  %s  %4s \r\n' "$counter" "$(settings $inA $inE)" 'crlf' > "$crlf_file"
    printf '%-15s  %s  %4s \n'   "$counter" "$(settings $inA $inE)"   'lf' > "$lf_file"
    cat -ve *

    commit_response=$(git add . 2>&1)
    if echo "$commit_response" | grep 'LF will be replaced by CRLF'; then
      report_input='LF>CRLF'
    elif echo "$commit_response" | grep 'CRLF will be replaced by LF'; then
      report_input='CRLF>LF'
    elif echo "$commit_response" | grep 'conflicts'; then
      report_input='CONFLICT'
    else
      report_input='no-warning'
    fi
    git commit -m "$dt core.autocrlf=$inA core.eol=$inE"

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
