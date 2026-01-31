#!/usr/bin/env -S nu --stdin

let start = date now
mut word = ""

def process_key []: any -> record<key_type: string, code: string, modifiers: list<string>> {
  {
    ...($in | select key_type code), 
    modifiers: ($in.modifiers | each {
      str replace -r "^keymodifiers\\((.*)\\)$" '$1'
    })
  }
}

while true {
  let raw = input listen -rt [key] 
  let key = $raw | process_key
  if $key.code == "esc" or ($key.code == "c" and "control" in $key.modifiers) {
    break
  }

  if $key.key_type == "char" and ($key.modifiers | length) == 0 {
    $word = $"($word)($key.code)"
  } else if $key.code == "backspace"  {
    $word = $"($word | str substring 0..-2)"
  }
  $word = $word | str substring 0..4
  $word = $word | str downcase
  $word = $word | str replace -ar "[^A-Za-z]" ""

  print -n $"(ansi -e "1K")\r($word)"

  {raw: $raw, key: $key, rawd: ($raw | describe) }| save log.json --append
}