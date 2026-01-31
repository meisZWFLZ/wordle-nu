# Wordle Data Utility

Retrieves data from NYT api and processes it.
Offers tools for duplicate first words.

## Getting Started
1. Clone repo
2. Create a `cookie.env.toml` file and put the following inside
  ```toml
  cookie="<cookies>"
  ```
3. Run `use wordle.nu`

## Example Usage
```nu
> wordle duplicates | first 3 | table --expand --theme ascii_rounded
.----------------------------------------.
| # | guess | count |       dates        |
| 0 | scare |     4 | .----------------. |
|   |       |       | | 0 | 2024-05-19 | |
|   |       |       | | 1 | 2024-07-01 | |
|   |       |       | | 2 | 2024-07-03 | |
|   |       |       | | 3 | 2024-07-09 | |
|   |       |       | '----------------' |
| 1 | heart |     3 | .----------------. |
|   |       |       | | 0 | 2025-06-11 | |
|   |       |       | | 1 | 2025-06-16 | |
|   |       |       | | 2 | 2025-06-22 | |
|   |       |       | '----------------' |
| 2 | trace |     3 | .----------------. |
|   |       |       | | 0 | 2024-05-15 | |
|   |       |       | | 1 | 2025-05-23 | |
|   |       |       | | 2 | 2025-06-19 | |
|   |       |       | '----------------' |
'----------------------------------------'
```

## Subcommands
```nu
# Import module
use wordle.nu

# Print wordle board for date (defaults to today)
wordle board [date]

# Checks if word has ever been used before as a starting word
wordle check <word>

# Returns a list of all words that have been used as a first guess
wordle firsts

# Returns a list of all the boards that have been played
wordle boards

# Returns a list of all the words that have been played more than once as a first guess.
# Ordered by number of usages
# Also includes the dates they were used on.
wordle duplicates

# Clears the cache for the nyt API data
wordle cache clear
```