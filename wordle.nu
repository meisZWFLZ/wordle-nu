#!/usr/bin/env nu

def paths [] {
  let cache_dir = "cache"
  let data_dir = "data"
  let cache = {
    games: $"($cache_dir)/games.json",
    boards: $"($cache_dir)/boards.json",
    # duplicates: $"($cache_dir)/duplicates.json"
  }
  let cookie = "cookie.env.toml"
  let word_list = $"($data_dir)/words.txt"
  return {cache: $cache, cookie: $cookie, word_list: $word_list}
}

# Check if two dates are the same day
def date-eq [a: datetime, b: datetime] {
  (($a | format date "%Y-%m-%d") == ($b | format date "%Y-%m-%d")) | into bool
}

def get-maybe-cached [path: path, fetch_fn: closure] {
  let today = date now
  def is-today [a: datetime] {
    date-eq $a $today
  }

  if ($path | path exists) {
    let file_data = open $path
    let date = $file_data.date | into datetime
    if (is-today $date) {
      return $file_data.data
    } 
  }
  let data = do $fetch_fn
  let file_data = {date: $today, data: $data}
  $file_data | save $path --force
  return $data
}

def print-progress [label, progress, --start, --fill-char: string = "#", --empty-char: string = "-"] {
  use std assert
  assert (0.0 <= $progress and $progress <= 1.0)
  assert (($fill_char | str length) == 1)
  assert (($empty_char | str length) == 1)
  
  def pct_str [progress] {
    $"(($progress * 100) | math round)%"
  } 
    
  def "bar make" [width] {
    
    def repeat [n: int]: string -> string {
      ignore  
      use std repeat
      $in | repeat $n | str join
    }

    let filled_width = ($width * $progress) | into int
    let empty_width = $width - $filled_width

    ($fill_char | repeat $filled_width) + ($empty_char | repeat $empty_width)
  }

  let other_width = $"($label): [] $(pct_str 1)" | str length
  let term_width: int = try {^tput cols | into int } catch { 80 }
  let inner_bar_width = [($term_width - $other_width), 40] | math min
  let bar = if $inner_bar_width >= 4 { $"[(bar make $inner_bar_width)] " } else { "" }
 
  if not $start { print -n "\u{1b}[1F" }

  print $"($label): ($bar)(pct_str $progress)"
}

def fetch-games-for-month [start, end] {
  let url = $"https://www.nytimes.com/svc/games/v1/archive/wordle/($start | format date '%Y-%m-%d')/($end | format date '%Y-%m-%d')"
  http get $url | select print_date solution id | rename date solution id
}

def fetch-games []: nothing -> table<date: string, id: int> {
  # First Wordle date
  let first = 2021-06-19
  let today = date now
  let months = ($today - $first) / 32day | math ceil 

  print-progress "Fetching Games" 0 --start
  (0..$months) | each {|i| 
    let start = $first + ($i * 32day)
    let end = $start + 31day
    let progress = $i / $months
    print-progress "Fetching Games" $progress
    {start: $start, end: $end}
    fetch-games-for-month $start $end
  } | flatten
}

def fetch-boards-for-month [cookie] {
  let games = $in
  let url = $"https://www.nytimes.com/svc/games/state/wordleV2/latests?puzzle_ids=($games.id | str join ',')"
  let dates = [($games.date | first), ($games.date | last)]

  http get $url --headers {
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "accept-language": "en-US,en;q=0.8",
      "cache-control": "no-cache",
      "pragma": "no-cache",
      "priority": "u=0, i",
      "sec-ch-ua": "\"Chromium\";v=\"140\", \"Not=A?Brand\";v=\"24\", \"Brave\";v=\"140\"",
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": "\"Windows\"",
      "sec-fetch-dest": "document",
      "sec-fetch-mode": "navigate",
      "sec-fetch-site": "none",
      "sec-fetch-user": "?1",
      "sec-gpc": "1",
      "upgrade-insecure-requests": "1",
      "cookie": $cookie
    } | get states | each { 
      let guesses = $in.game_data | get boardState | where { $in != "" }
      let status = $in.game_data | get status
      let puzzle_id = $in.puzzle_id | into int
      let game = $games | where {$in.id == $puzzle_id} | first
      let date = $game.date
      let solution = $game.solution
      return {date: $date, solution: $solution, guesses: $guesses, status: $status}
    } | sort-by date
}

export def get-games []: nothing -> table<date: string, id: int> {
  get-maybe-cached (paths).cache.games {fetch-games}
}

# Fetch Wordle responses and save to CSV files
def fetch-boards []: any -> any {
  let cookie = open (paths).cookie | get cookie
  let months = get-games | chunks 31

  print-progress "Fetching Boards" 0 --start

  $months | enumerate | each { |e|  
    let i = $e.index
    let month = $e.item

    let out = $month | fetch-boards-for-month $cookie
    
    let progress = ($i + 1) / ($months | length)
    print-progress "Fetching Boards" $progress
    
    return $out
  } | flatten | where {($in.guesses | length) > 0}
}

def get-valid-words []: nothing -> list<string> {
  open (paths).word_list | split row "\n"
}

export def get-boards []: any -> table<date: string, guesses: list<string>, status: string> {
  get-maybe-cached (paths).cache.boards {fetch-boards}
}

# Get first guesses only
export def firsts []: nothing -> table<date: string, guesses: string> {
  get-boards | select date guesses | update guesses {get 0} | rename date guess | sort
}

export def get-duplicates []: nothing -> table<guess: string, count: int, dates: list<string>> {
  let firsts = firsts
  $firsts | uniq-by guess | each { |entry| 
    let guess = $entry.guess
    let same_guesses = $firsts | where {$in.guess == $guess}
    {
      guess: $guess,
      count: ($same_guesses | length),
      dates: ($same_guesses | get date)
    } 
  } | where {$in.count > 1} | sort-by count -r
} 

export alias duplicates = get-duplicates
export alias boards = get-boards

export def "cache clear" []: nothing -> nothing {
  (paths).cache | values | each { |path|
    if ($path | path exists) {
      print $"Removing cached file: ($path)"
      rm $path
    }
  } | ignore
}

export def check [word]: any -> any {
  use std/assert

  let valid_words = get-valid-words
  def "assert wordle valid" [word]: any -> any {
    assert (($word | str length) == 5) --error-label {
      text: $"($word) must be 5 letters",
      span: (metadata $word).span
    }
    assert ($word in $valid_words) --error-label {
      text: $"($word) is not in word list for wordle",
      span: (metadata $word).span
    }
    return $word
  }
  try {
    assert wordle valid $word
  } catch {
    error make {msg: ($in.json | from json | get labels.0.text)} --unspanned
  }

  let dupes = firsts | where { ($in.guess == $word) }

  if ($dupes | length) > 0 {
    print $"Found ($dupes | length) duplicate(if ($dupes | length) > 1 {"s"}) for ($word):"
  } else {
    print $"No duplicates found for ($word)"
  }
  $dupes.date
}

export def board [date?: datetime] {
  let date = if $date == null { date now } else { $date }

  let games = get-boards | where { date-eq ($in.date | into datetime) $date }
  if ($games | length) == 0 {
    error make {msg: $"No game found for date: ($date | format date '%Y-%m-%d')"} --unspanned
  }
  let game = $games | first
  let solution = $game.solution

  def letter-color [guess: string, col: int] {
    let letter = $guess | str substring ($col..$col)

    def count [letter: string]: string -> int {
      $in | split chars | where {$in == $letter} | length
    }
    if ($solution | str contains $letter) {
      if ($solution | str substring ($col..$col)) == $letter {
        return "green"
      } else {
        let count_before_letter = $guess | str substring 0..($col - 1) | count $letter 
        let count_in_solution = $solution | count $letter

        if $count_before_letter < $count_in_solution {
          return "yellow"
        } else {
          return "gray"
        }
      }
    } else {
      return "gray"
    } 
  }

  # def "ansi format" [...args]: string -> string {
  #   $"(ansi $args)($in)(ansi reset)"
  # }
  const green_bg = {
    bg: "green"
  }
  const yellow_bg = {
    bg: "yellow"
  }
  const black_bg = {
    bg: "black"
  }
  def uppercase []:  string -> string {
    let lowers = "abcdefghijklmnopqrstuvwxyz"
    let uppers = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $in | split chars | each { |c|
      $uppers | split chars | get ($lowers | str index-of $c)
    } | str join ""
  }

  def render-row []: list<record<letter: string, color: string>> -> string {
    $in | each { |e| 
      $"(ansi (if ($e.color == "green") {
        "green"
      } else if ($e.color == "yellow") {
        "yellow"
      } else {
        "black"
      }))($e.letter | uppercase)(ansi reset)"
    } | str join ""
  }

  $game.guesses | each { |guess|
    $guess | split chars | enumerate | each { |e|
      let col = $e.index
      let letter = $e.item
      let color = letter-color $guess $col
      {letter: $letter, color: $color}
    } | render-row    
  } | str join "\n" 
}