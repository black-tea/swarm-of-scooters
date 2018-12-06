###########################
# LA GBFS Map Server Code #
###########################

library(httr)
library(sf)
library(leaflet)
library(jsonlite)
library(tidyverse)
library(data.table)
library(units)
library(htmltools)

### Functions
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
                'cyclehop' = 'https://gbfs.hopr.city/api/gbfs/5/free_bike_status',
                'bird' = 'https://mds.bird.co/gbfs/los-angeles/free_bikes',
                'lime' = 'https://lime.bike/api/partners/v1/gbfs/los_angeles/free_bike_status.json',
                'lyft' = 'https://s3.amazonaws.com/lyft-lastmile-production-iad/lbs/lax/free_bike_status.json',
                'jump' = 'https://la.jumpbikes.com/opendata/free_bike_status.json',
                'spin' = 'https://staging.spin.pm/api/gbfs/v1/los_angeles/free_bike_status',
                'razor' = 'url',
                'wheels' = 'https://la-gbfs.getwheelsapp.com/free_bike_status.json')
  r <- GET(url)
  df <- jsonlite::fromJSON(content(r, as='text'), flatten=TRUE)
  rdf <- df$data$bikes
  
  # Support for paginated endpoints (lime)
  if(!is.null(df$max_page)){
    
    lastpg <- df$max_page
    dflist <- vector(mode = 'list', length = lastpg + 1)
    
    for(i in seq(1, lastpg)){
      print(i)
      paginatedurl <- paste0(url, "?page=", i)
      page <- GET(paginatedurl)
      df <- jsonlite::fromJSON(content(page, as='text'), flatten=TRUE)
      dflist[[i+1]] <- df$data$bikes
    }
    rdf <- rbindlist(dflist)
    rdf <- rdf %>% mutate(lon = as.double(lon), lat = as.double(lat))
  }
  print(providerName)
  print(rdf)
  

  # format data, if exists
  if(is.data.frame(rdf)){
    
    # reformat vehicle type
    if(providerName=='jump'){
      rdf <- rdf %>% mutate(vehicle_type=if_else(jump_vehicle_type=='bike','ebike', 'scooter'))
    } else if(providerName=='bird'){
      rdf <- rdf %>% mutate(vehicle_type='scooter')
    } else if(providerName=='lime'){
      print('limeplaceholderlogic')
    } else if(providerName=='cyclehop'){
      rdf <- rdf %>% mutate(vehicle_type=if_else(is_ebike==1,'ebike','bike'))
    }
    # TODO: add lyft & other providers
    
    # format as sf df
    bikes <- rdf %>%
      st_as_sf(coords = c('lon','lat')) %>%
      mutate(provider = providerName) %>%
      select(provider, vehicle_type) %>%
      st_set_crs(4326)
    return(bikes)
    }
}

### Load Data
neighborhoods <- st_read('data/la_neighborhoods/la_city.shp')
cityBoundary <- neighborhoods %>% mutate(city = 'Los Angeles') %>% group_by(city) %>% summarize(do_union=TRUE)
names(cityBoundary$geometry) <- NULL
providerlist <- c('jump','lime','cyclehop','bird','lyft')

### Server
server <- function(input, output) {
  
  # Dockless Vehicles
  allbikes <- reactive({
    input$download
    withProgress(message="Fetching Data...",{
      percentage <- 0
      allbikes <- lapply(providerlist, function(x) {
        percentage <<- percentage + 1/length(providerlist)*100
        incProgress(1/length(providerlist), detail = toString(x))
        getDocklessDevices(x);
      })
    })
    allbikes <- do.call('rbind', allbikes)
    return(allbikes)
  })
  # Refresh Fetch
  observeEvent(input$download, {allbikes()})
  
  # Filter bikes by Company
  filteredBikes <- reactive({
    bikes <- allbikes() %>%
      filter(provider %in% input$providerGroup) %>%
      filter(vehicle_type %in% input$deviceGroup)})

  neighborhoodCt <- reactive({
    ct <- filteredBikes() %>%
      st_join(neighborhoods, join=st_within, left=FALSE) %>%
      count(Name) %>%
      st_set_geometry(NULL)
    neighborhoodCt <- neighborhoods %>%
      left_join(ct, by='Name') %>%
      select(-Descriptio) %>%
      replace_na(list(n=0)) %>%
      mutate(area = st_area(.)) %>%
      mutate(area = units::set_units(st_area(.), mi^2)) %>%
      mutate(density = n/area)
    return(neighborhoodCt)
  })
  
  # Map
  output$map <- renderLeaflet({
    
    map <- leaflet(options(leafletOptions(preferCanvas = TRUE))) %>%
      addProviderTiles(providers$CartoDB.Positron, options = providerTileOptions(
        minZoom=10,
        maxZoom=18,
        updateWhenZooming=FALSE,
        updateWhenIdle=TRUE)) %>%
      setView(lng=-118.329327, lat=34.0546143, zoom=13)
    map
    })
  
  # Add bikes to map
  observe( {
    bikes <- filteredBikes()
    leafletProxy("map") %>%
      clearMarkers()
    
    if(nrow(bikes) > 1){
      print('hi')
      print(bikes)
      print(nrow(bikes))
      pal <- colorFactor(c('#24D000', 'red', '#f36396','#5DBCD2','black'),
                       domain=c('lime', 'jump', 'lyft','cyclehop','bird'),
                       ordered=TRUE)
      leafletProxy("map") %>%
        #clearMarkers() %>%
        addCircleMarkers(data = bikes,
                         radius = 2,
                         weight = 1,
                         stroke = TRUE,
                         opacity = 1,
                         fillOpacity = 0.9,
                         color = pal(bikes$provider),
                         fillColor = pal(bikes$provider),
                         label = bikes$provider,
                         group = "Devices")
  }})
  
  # Hide markers at high zoom levels  
  observe({
    if(!is.null(input$map_zoom)){
      if(input$map_zoom < 13){
        
        neighborhoodCt <- neighborhoodCt()
        binpal <- colorBin("Purples", neighborhoodCt$density, 6, pretty = FALSE)
        
        labels <- sprintf(
          "<strong>%s</strong><br/>%g devices",
          neighborhoodCt$Name, neighborhoodCt$n
        ) %>% lapply(htmltools::HTML)
        
        leafletProxy("map") %>%
          clearShapes() %>%
          hideGroup("Devices") %>%
          #addPolygons(data=cityBoundary, fill=FALSE, color='#444444', weight=2, group="Bounday") %>%
          addPolygons(data = neighborhoodCt,
                      weight = 1,
                      opacity = 1,
                      color = "white",
                      fillColor = ~binpal(density),
                      fillOpacity = 0.7,
                      label = labels,
                      labelOptions = labelOptions(
                        style = list("font-weight" = "normal", padding = "3px 8px"),
                        textsize = "15px",
                        direction = "auto"),
                      highlightOptions = highlightOptions(color = "white", weight=4, bringToFront=TRUE)) #%>%
          #addPolygons(data=cityBoundary, fill=FALSE, color='#444444', weight=2, group="Bounday")
      
      } else {
        bikes <- filteredBikes()
        print(nrow(bikes))
        leafletProxy("map") %>%
          clearShapes() %>%
          showGroup("Devices")}
    }})
}