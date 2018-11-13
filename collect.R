###########################
# LA GBFS Map Server Code #
###########################

library(httr)
library(sf)
library(leaflet)
library(jsonlite)
library(tidyverse)

getDocklessDevices <- function (providerName) {
  # Sumbit GET request to Provider API for location of dockless devices
  #
  # Args: 
  #   providerName: Name of provider
  #
  # Returns:
  #   sf df with dockless devices
  #
  # API Parameters
  url <- switch(providerName,
                'bird' = birdURL,
                'lime' = 'https://lime.bike/api/partners/v1/gbfs/los_angeles/free_bike_status.json',
                'lyft' = 'https://s3.amazonaws.com/lyft-lastmile-production-iad/lbs/lax/free_bike_status.json',
                'jump' = 'https://la.jumpbikes.com/opendata/free_bike_status.json')
  r <- GET(url)
  rdf <- jsonlite::fromJSON(content(r, as='text'), flatten=TRUE)
  bikes <- rdf$data$bikes %>%
    st_as_sf(coords = c('lon','lat')) %>%
    mutate(provider = providerName) %>%
    select(provider, bike_id, name)
  
  # build in handling of pagination
  return(bikes)
}

#bikes <- getDocklessDevices('jump')

# All dockless devices
allbikes <- lapply(c('lyft','jump'), getDocklessDevices)
bikesdf <- do.call('rbind', allbikes)

# UI Ideas
# have total count

# also
# setup options to drill-down filtering on sidebar
# use color function from 

# Create a palette that maps factor levels to colors
pal <- colorFactor(c("navy", "red"), domain = c("ship", "pirate"))

m <- leaflet() %>%
         addProviderTiles(providers$CartoDB.Positron) %>%
         addCircleMarkers(data = bikesdf,
                    label = bikesdf$provider,
                    popup = bikesdf$bike_id,
                    clusterOptions = markerClusterOptions())
m


