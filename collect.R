########################
# Collect the Scooties #
########################

##### Setup
library(httr)
library(generator)
library(sf)
library(here)

GeneratePoint <- function (boundary) {
  # Randomly generate a point within boundary
  #
  # Args: boundary
  #
  # Returns:
  #   An X, Y coordinate pair
  #
  x <- st_sample(boundary, 1, type="random")
  return(x[[1]])
}

GenerateBirdToken <- function () {
  # Sumbit POST request to Bird API for a token
  #
  # Args: None
  #
  # Returns:
  #   A token to be used in GET request
  #
  # Generate a random email address w/ Generator pkg
  #postEmail <- r_email_addresses(1)
  postBody <- list(email = "funkymunky28@hotmail.com")
  postURL <- "https://api.bird.co/user/login"
  postResult <- POST(postURL,
                     add_headers(.headers = c("Platform" = "ios",
                                              "Device-id" = "CDC23262-ACCF-4E88-AC74-8E550343696E")),
                     body = postBody,
                     encode = "json",
                     verbose())
  return(content(postResult, as = "parsed"))
}

BirdAPICall <- function (token, lat, lon) {
  # Sumbit GET request to Bird API for location of nearby birds
  #
  # Args: 
  #   token: String token generated from bird query
  #
  # Returns:
  #   JSON dict with information on nearby scooters
  #
  # Bird API Parameters
  getURL <- sprintf("https://api.bird.co/bird/nearby?latitude=%f&longitude=%f&radius=1000", lat, lon)
  getResult <- GET(getURL,
                   add_headers(.headers = c("Authorization" = paste0('Bird ',token$token),
                                            "Device-id" = token$id,
                                            "App-Version" = "3.0.5",
                                            sprintf("Location" = '{"latitude":%f,"longitude":%f,"altitude":500,"accuracy":100,"speed":-1,"heading":-1}', lat, lon)
                                            )),
                   #body = NULL,
                   #encode = "json",
                   verbose())
  return(getResult)
}

city_boundary <- read_sf(here('data/city_boundary/city_boundary.shp'))
pt <- GeneratePoint(city_boundary)
m <- leaflet() %>% addTiles() %>% addMarkers(data = pt)
m
#birdToken <- GenerateBirdToken()
#birdData <- BirdAPICall(birdToken)
#content(birdData, as = "parsed")

