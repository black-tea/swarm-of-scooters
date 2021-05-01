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
library(lwgeom)

### Functions
createProviderLegend <- function(selectedCity, providerList, providerCounts) {
  
  # Filter providers based on checkbox
  providerList <- providerList %>%
    dplyr::filter(city == selectedCity) %>%
    dplyr::select(provider_name, provider) %>%
    dplyr::distinct()
  
  # Join to df of device counts
  if(!is.null(providerCounts)){
    providerList <- providerList %>%
      dplyr::left_join(providerCounts, by='provider') %>%
      replace(is.na(.), 0)
    
    # Extract counts
    cityProviderCounts <- providerList$n
  } else {
    # If no devices in a city, create vector of length n w/ value = 0
    cityProviderCounts <- rep(0, length(providerList$provider))
  }
    
  # Convert df to lists
  cityProviderValues <- providerList$provider
  cityProviderNames <- providerList$provider_name
  
  # Generate HTML for selected providers
  providerHTML <- lapply(1:length(cityProviderNames), function(x){
    lblHTML <- '<img src="%s_circle.png" height="12" width="12" style="margin: 0px 4px 2px 0px">%s (%d)'
    return(HTML(sprintf(lblHTML, cityProviderValues[x], cityProviderNames[x], cityProviderCounts[x])))
  })
  
  # Return HTML and list of providers
  return(list('providerHTML'=providerHTML, 'providerValues'=cityProviderValues, 'providerNames'=cityProviderNames))
}

getDocklessDevices <- function (provider, url) {
  ## Sumbit GET request to Provider API for location of dockless devices
  rdf <- try(callAPI(url))
  # print(rdf)
  # format data, if exists
  if(is.data.frame(rdf)){
    # reformat vehicle type
    if(provider=='jump'){
      rdf <- rdf %>% mutate(vehicle_type=if_else(jump_vehicle_type=='bike','ebike', 'scooter'))
    } else if(provider %in% c('bird','wheels','razor','skip','wind')){
      rdf <- rdf %>% mutate(vehicle_type='scooter')
    } else if(provider=='lime'){
      print('limeplaceholderlogic')
    } else if(provider=='cyclehop'){
      rdf <- rdf %>% mutate(vehicle_type=if_else(is_ebike==1,'ebike','bike'))
    } else if(provider=='lyft'){
      rdf <- rdf %>% mutate(vehicle_type=if_else(type=='electric_scooter','scooter','ebike'))
    } 
    # TODO: add SPIN
    
    # format as sf df
    bikes <- rdf %>%
      sf::st_as_sf(coords = c('lon','lat')) %>%
      dplyr::mutate(provider = provider) %>%
      dplyr::select(provider, vehicle_type) %>%
      sf::st_set_crs(4326)
    return(bikes)
    }
}

callAPI <- function (url) {
  ## Sumbit GET request to Provider API for location of dockless devices
  print(sprintf("Calling API for %s",url))
  r <- GET(url)
  df <- jsonlite::fromJSON(content(r, as='text', encoding = "UTF-8"), flatten=TRUE)
  rdf <- df$data$bikes %>% mutate(lon = as.double(lon), lat = as.double(lat))
  
  # Support for non-standard format (skip)
  if(is.null(rdf))
    rdf <- df$bikes
  
  # Support for paginated endpoints (lime)
  if(!is.null(df$max_page) && length(rdf) > 0){
    
    lastpg <- df$max_page
    dflist <- vector(mode = 'list', length = lastpg + 1)
    
    for(i in seq(1, lastpg)){
      paginatedurl <- paste0(url, "?page=", i)
      page <- GET(paginatedurl)
      df <- jsonlite::fromJSON(content(page, as='text'), flatten=TRUE)
      dflist[[i+1]] <- df$data$bikes}
    rdf <- rbindlist(dflist)
    rdf <- rdf %>% mutate(lon = as.double(lon), lat = as.double(lat))}
  return(rdf)
}

# Filter bikes based on user input
filterBikes <- function(bikes, providers, devicetypes){
  
  if(is.null(bikes))
    return()
  
  filteredBikes <- bikes %>%
    filter(provider %in% providers) %>%
    filter(vehicle_type %in% devicetypes)
  
  return(filteredBikes)
}


### Load Data
# Get systems list from GitHub
systems <- read_csv('https://raw.githubusercontent.com/kevinamezaga/swarm-of-scooters/master/data/systems.csv')
providerColors <- read_csv('https://github.com/kevinamezaga/swarm-of-scooters/blob/master/data/provider_colors.csv')

# Select providers from systems list
providerlist <- systems %>%
  dplyr::select(provider) %>%
  dplyr::distinct()

# Create named vector for cities & remove dups
cities <- setNames(as.character(systems$city), systems$city_name)
cities <- cities[!duplicated(cities)]

# Neighborhoods
neighborhoods <- st_read('data/neighborhoods/la_city.shp')
nyc_neighborhoods <- st_read('data/neighborhoods/new_york.shp')
# print(neighborhoods)
# print(nyc_neighborhoods)

### Server
server <- function(input, output) {
  
  # Reactive for selected city choice
  selectedCityR <- reactive({
    if(!is.null(input$citychoice) & length(input$citychoice)>1){
      return(input$citychoice)
    } else {
      return(NULL)}
    })
  
  # Reactive to get all the systems for the selected city
  systemsR <- reactive({
    if(!is.null(input$citychoice)){
      return(systems <- systems %>% dplyr::filter(city == input$citychoice))
    } else {return(NULL)}})
  
  # Dockless Vehicles
  allbikes <- reactive({
    
    # Reactive triggered if user hits "Refresh Data"
    input$download
    systemsR <- systemsR()
    
    if(is.null(systemsR))
      return()
    
    # Get provider & GBFS URL
    urls <- systemsR$gbfs_freebike_url
    cityProviders <- systemsR$provider
    
    # Get data w/ Progress Bar
    withProgress(message="Fetching Data...", {
      percentage <- 0
      allbikes <- mapply(function(x,y) {
        percentage <<- percentage + 1/length(cityProviders)*100
        incProgress(1/length(cityProviders), detail=toString(x))
        getDocklessDevices(x, y)
      }, cityProviders, urls, SIMPLIFY=FALSE)
    })

    # Combine lists and return
    allbikes <- do.call('rbind', allbikes)
    return(allbikes)
  })
  
  # Summarize Device Counts by Provider
  bikeCt <- reactive({
    
    if(is.null(allbikes()))
      return()
    
    bikeCt <- allbikes() %>%
      dplyr::count(provider) %>%
      sf::st_set_geometry(NULL)
    
    return(bikeCt)
  })
  
  # Circle radius changes at map zoom == 13
  radius <- reactive({ifelse(input$map_zoom<13,1,2)})
  zoomOutThreshold <- reactiveVal()
  observeEvent(input$map_zoom, {
    ifelse(input$map_zoom<13, zoomOutThreshold(TRUE), zoomOutThreshold(FALSE)) 
  })
  
  # Filter bikes by Company & Device Type
  filteredBikes <- reactive({

    if(is.null(allbikes()))
      return()

    filteredBikes <- allbikes() %>%
      filter(provider %in% input$providerGroup) %>%
      filter(vehicle_type %in% input$deviceGroup)

    return(filteredBikes)
    })

  # Count devices in each neighborhood
  neighborhoodCt <- reactive({

    bikes <- filteredBikes()
    if(is.null(bikes))
      return()
    
    # If input$providerGroup is null, run it on the entire allbikes()
    if(is.null(input$providerGroup))
      bikes <- allbikes()

    # Count devices
    ct <- bikes %>%
      sf::st_join(neighborhoods, join=st_within, left=FALSE) %>%
      sf::st_set_geometry(NULL) %>%
      dplyr::count(`Name`) 

    # Join device count to neighborhood shp
    neighborhoodCt <- neighborhoods %>%
      dplyr::left_join(ct, by='Name') %>%
      dplyr::select(-Descriptio) %>%
      tidyr::replace_na(list(n=0)) %>%
      dplyr::mutate(area = st_area(.)) %>%
      dplyr::mutate(area = units::set_units(st_area(.), mi^2)) %>%
      dplyr::mutate(density = n/area)

    return(neighborhoodCt)
  })
  
  # Create City Select input, set default city to LA
  output$citySelect <- renderUI({
    
    selectizeInput(inputId='citychoice',
                   label='City',
                   choices=cities,
                   selected="la_region",
                   multiple=FALSE)
  })
  
  # Create Company Checkbox Filter
  output$providerSelect <- renderUI({
    
    if(is.null(input$citychoice))
      return()
    
    bikeCt <- bikeCt()
    
    providerLegend <- createProviderLegend(input$citychoice, systems, bikeCt)
    checkboxGroupInput('providerGroup',
                       label='Provider',
                       choiceNames=providerLegend$providerHTML,
                       choiceValues=providerLegend$providerValues,
                       selected=providerLegend$providerValues)
  })
  
  # Map
  output$map <- renderLeaflet({
    
    # Intial map view set to LA
    map <- leaflet(options(leafletOptions(preferCanvas = TRUE))) %>%
      addProviderTiles(providers$CartoDB.Positron, options = providerTileOptions(
        maxZoom=18,
        updateWhenZooming=FALSE,
        updateWhenIdle=TRUE)) %>%
      setView(lng=-118.329327, lat=34.0546143, zoom=12)
    
    return(map)
    })

  
  # New observer to zoom with change of city
  observeEvent(input$citychoice, {
    
    # Get systems for new city
    new_bikes <- allbikes()
    
    # Display warning message if no bikes in City
    if(is.null(new_bikes)||nrow(new_bikes)<1){
      showNotification(paste0("No available devices in ",
                              names(which(cities == input$citychoice))),
                       type = "warning",
                       duration = 10)
      return()
    }

    # fitBounds won't accept named vectors, so unname
    bbox <- unname(st_bbox(new_bikes))

    # Resize map bounds to extent
    if(input$citychoice == "la_region"){
      leafletProxy("map") %>% setView(lng=-118.329327, lat=34.0546143, zoom=12)
    } else {
      leafletProxy("map") %>% fitBounds(bbox[1], bbox[2], bbox[3], bbox[4])
    }
  })
  
  # Observer to focus on map points
  observeEvent(c(zoomOutThreshold(),
                 input$download,
                 input$providerGroup,
                 input$deviceGroup), {
    
    if(is.null(input$map_zoom))
      return()
    
    # Get bikes & circle radius, based on map zoom
    bikes <- filteredBikes()
    radius <- radius()
    
    if(nrow(bikes)<1||is.null(bikes))
      return()

    # Create color palette
    pal <- colorFactor(providerColors$color,
                       providerColors$provider,
                       ordered=TRUE)
    
    # Add devices to map
    leafletProxy("map") %>%
      clearMarkers() %>%
      addCircleMarkers(data=bikes,
                       radius=radius,
                       stroke=FALSE,
                       fillOpacity=0.9,
                       fillColor=pal(bikes$provider),
                       label=bikes$provider,
                       group="Devices")
  })
  
  # Observer focused on neighborhood boundaries
  observeEvent(c(zoomOutThreshold(),
                 input$download,
                 input$providerGroup,
                 input$deviceGroup), {

    if(is.null(input$map_zoom))
      return()
    
    if(input$map_zoom > 12)
      return()

    # Get updated neighborhood counts
    neighborhoodCt <- neighborhoodCt()
    
    if(is.null(neighborhoodCt))
      return()
    
    # Create neighborhood label
    labels <- sprintf(
      "<strong>%s</strong><br/>%g devices",
      neighborhoodCt$Name, neighborhoodCt$n
    ) %>% lapply(htmltools::HTML)

    # Add neighborhood layer on top of map
    leafletProxy("map") %>%
      clearShapes() %>%
      addPolygons(data = neighborhoodCt,
                  weight = 0.1,
                  opacity = .01,
                  fillOpacity = 0,
                  label = labels,
                  labelOptions = labelOptions(
                    style = list("font-weight" = "normal", padding = "3px 8px"),
                    textsize = "15px",
                    direction = "auto"),
                  highlightOptions = highlightOptions(color="#8F9DAA",
                                                      weight=3,
                                                      opacity=1,
                                                      bringToFront=TRUE))




    })
}