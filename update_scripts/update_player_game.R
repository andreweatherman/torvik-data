library(tidyverse)
library(withr)
library(arrow)

update_player_game <- function(year = current_season(), stat = "all") {
  suppressWarnings({
    withr::local_options(HTTPUserAgent='toRvik Package')
    if (!(is.numeric(year) && nchar(year) == 4 && year >=
          2008)) {
      cli::cli_abort("Enter a valid year as a number. Data only goes back to 2008!")
    }
    if (!(is.character(stat) && stat %in% c("box", "shooting", "adv", "all"))) {
      cli::cli_abort("Please input a valid stat command ('box,' 'shooting', or 'adv')")
    }
    curl::curl_download(paste0('https://barttorvik.com/', year, '_all_advgames.json.gz'), 'games.json')
    if (stat == "box") {
      names <- c(
        "date", "player", "exp", "team", "opp", "result", "min", "pts", "two_m", "two_a", "three_m",
        "three_a", "ftm", "fta", "oreb", "dreb", "ast", "tov", "stl", "blk", "pf", "id", "game_id"
      )
      x <- jsonlite::fromJSON('games.json') %>%
        dplyr::as_tibble() %>%
        dplyr::select(1, 49, 51, 48, 6, 5, 9, 34, 24:29, 35, 36, 37, 38, 39, 40, 43, 52, 7)
      colnames(x) <- names
      x <- x %>%
        dplyr::mutate(
          date = lubridate::ymd(date),
          across(c(7:16), as.numeric),
          reb = oreb + dreb, .after = dreb,
          result = case_when(
            result == "1" ~ "W",
            TRUE ~ "L"
          ),
          year = year
        ) %>%
        dplyr::mutate(
          fgm = two_m + three_m,
          fga = two_a + three_a,
          .after = three_a
        ) %>%
        dplyr::relocate(year, .after = date)
    }
    if (stat == "shooting") {
      names <- c(
        "date", "player", "exp", "team", "opp", "result", "min", "pts", "usg", "efg", "ts", "dunk_m", "dunk_a",
        "rim_m", "rim_a", "mid_m", "mid_a", "two_m", "two_a", "three_m", "three_a", "ftm", "fta", "id", "game_id"
      )
      x <- jsonlite::fromJSON('games.json') %>%
        dplyr::as_tibble() %>%
        dplyr::select(1, 49, 51, 48, 6, 5, 9, 34, 11:13, 18:29, 52, 7)
      colnames(x) <- names
      x <- x %>%
        dplyr::mutate(
          date = lubridate::ymd(date),
          across(c(7:24), as.numeric),
          fg = (two_m + three_m) / (two_a + three_a) * 100, .before = efg,
          result = case_when(
            result == "1" ~ "W",
            TRUE ~ "L"
          ),
          year = year
        ) %>%
        dplyr::relocate(year, .after = date)
    }
    if (stat == "adv") {
      names <- c(
        "date", "player", "exp", "team", "opp", "result", "min", "pts", "usg", "ortg", "or_pct", "dr_pct",
        "ast_pct", "to_pct", "stl_pct", "blk_pct", "bpm", "obpm", "dbpm", "net", "poss", "id", "game_id"
      )
      x <- jsonlite::fromJSON('games.json') %>%
        dplyr::as_tibble() %>%
        dplyr::select(1, 49, 51, 48, 6, 5, 9, 34, 11, 10, 14:17, 41:42, 30:33, 44, 52, 7)
      colnames(x) <- names
      x <- x %>% dplyr::mutate(
        date = lubridate::ymd(date),
        across(c(7:22), as.numeric),
        result = case_when(
          result == "1" ~ "W",
          TRUE ~ "L"
        ),
        year = year, .after = date
      )
    }
    if(stat=='all') {
      names <- c("date", "player", "exp", "team", "opp", "result", "min", "pts", "two_m", "two_a", "three_m",
                 "three_a", "ftm", "fta", "oreb", "dreb", "ast", "tov", "stl", "blk", "pf", "ortg", "usg", "efg", "ts", "dunk_m", "dunk_a",
                 "rim_m", "rim_a", "mid_m", "mid_a", "or_pct", "dr_pct", "ast_pct", "to_pct", "stl_pct", "blk_pct", "bpm", "obpm", "dbpm",
                 "net", "poss", "id", "game_id")
      x <- jsonlite::fromJSON('games.json') %>%
        dplyr::as_tibble() %>%
        dplyr::select(1, 49, 51, 48, 6, 5, 9, 34, 24:29, 35, 36, 37, 38, 39, 40, 43, 10:13, 18:23, 14:17, 41:42, 30:33, 44, 52, 7 )
      colnames(x) <- names
      x <- x %>%
        dplyr::mutate(across(c(7:43), as.numeric),
                      date=lubridate::ymd(date),
                      result=case_when(result=="1"~"W",
                                       TRUE~"L"),
                      fg_pct = (two_m + three_m) / (two_a + three_a) * 100, .before = efg)
    }
    unlink('games.json')
    return(x)
  })
}

# run function for each stat type
box <- update_player_game(year=2023, stat='box')  |> mutate(across(21:25, as.numeric))
shooting <- update_player_game(year=2023, stat='shooting')
adv <- update_player_game(year=2023, stat='adv')
all <- update_player_game(year = 2023, stat='all')

# list the df and names of files
to_save <- list(box, shooting, adv, all)
names <- c('box','shooting', 'advanced', 'all')

# set wd
setwd('~/torvik-data')

# # load .parquet files with all data
# complete_all <- arrow::read_parquet('player_game/all.parquet')
# complete_box <- arrow::read_parquet('player_game/box.parquet')
# complete_shooting <- arrow::read_parquet('player_game/shooting.parquet')
# complete_adv <- arrow::read_parquet('player_game/advanced.parquet')
#
# # update complete .parquet files
# complete_all <- bind_rows(complete_all, all)
# complete_box <- bind_rows(complete_box, box)
# complete_shooting <- bind_rows(complete_shooting, shooting)
# complete_adv <- bind_rows(complete_adv, adv)
#
# # save complete as .parquet
# complete_save <- list(complete_all, complete_box, complete_shooting, complete_adv)
# complete_names <- c('all', 'box', 'shooting', 'advanced')
#
# map2(
#   .x = complete_save,
#   .y = complete_names,
#   .f = function(x, y) {
#     arrow::write_parquet(x, sink = paste0('player_game/', y, '.parquet'))
#   }
# )


# save as .parquet
map2(
  .x = to_save,
  .y = names,
  .f = function(x, y) {
    arrow::write_parquet(x, sink = paste0('player_game/2023/', y, '_2023.parquet'))
  }
)

# push to github
system('git pull')
system('git add .')
system("git commit -m '[VM PUSH] update player game stats'")
system('git push')
