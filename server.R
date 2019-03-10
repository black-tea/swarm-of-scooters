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
createProviderLegend <- function(selectedCity, providerList) {
  
  # Filter providers based on checkbox
  providerList <- providerList %>% filter(city == selectedCity) %>% select(provider_name, provider)
  cityProviderValues <- unique(providerList$provider)
  cityProviderNames <- unique(providerList$provider_name)
  
  # Generate HTML for selected providers
  providerHTML <- lapply(1:length(cityProviderNames), function(x){
    lblHTML <- '<img src="%s_circle.png" height="12" width="12" style="margin: 0px 4px 2px 0px">%s'
    return(HTML(sprintf(lblHTML, cityProviderValues[x], cityProviderNames[x])))
  })
  
  # Return HTML and list of providers
  return(list('providerHTML'=providerHTML, 'providerValues'=cityProviderValues, 'providerNames'=cityProviderNames))
}

getDocklessDevices <- function (provider, url) {
  ## Sumbit GET request to Provider API for location of dockless devices
  rdf <- callAPI(url)
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
      st_as_sf(coords = c('lon','lat')) %>%
      mutate(provider = provider) %>%
      select(provider, vehicle_type) %>%
      st_set_crs(4326)
    return(bikes)
    }
}

callAPI <- function (url) {
  ## Sumbit GET request to Provider API for location of dockless devices
  print("calling API")
  r <- GET(url)
  df <- jsonlite::fromJSON(content(r, as='text', encoding = "UTF-8"), flatten=TRUE)
  print("Printing df")
  # print(df)
  rdf <- df$data$bikes
  print("length of rdf")
  print(length(rdf))
  
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
  print("about to return rdf")
  return(rdf)
}


### Load Data
# Get systems list from GitHub
systems <- read_csv('https://raw.githubusercontent.com/black-tea/scooties/master/data/systems.csv')

# Select providers from systems list
providerlist <- systems %>%
  dplyr::select(provider) %>%
  dplyr::distinct()

# Create named vector for cities & remove dups
cities <- setNames(as.character(systems$city), systems$city_name)
cities <- cities[!duplicated(cities)]

# Neighborhood data
neighborhoods <- st_read('data/la_neighborhoods/la_city.shp')

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
    print("allbikes reactive triggered")
    input$download
    systemsR <- systemsR()
    if(!is.null(systemsR)){
      urls <- systemsR$gbfs_freebike_url
      print(urls)
      cityProviders <- systemsR$provider
      withProgress(message="Fetching Data...", {
        percentage <- 0
        print("percentage")
        allbikes <- mapply(function(x,y) {
          percentage <<- percentage + 1/length(cityProviders)*100
          incProgress(1/length(cityProviders), detail=toString(x))
          getDocklessDevices(x, y)
        }, cityProviders, urls, SIMPLIFY=FALSE)
      })
      print("done with download!")
      allbikes <- do.call('rbind', allbikes)
      print("result of allbikes")
      print(nrow(allbikes))
      return(allbikes)
    } else {return(NULL)}
  })
  
  # Refresh Fetch
  observeEvent(input$download, {allbikes()})
  
  # Circle radius changes at map zoom == 13
  radius <- reactive({ifelse(input$map_zoom<13,1,2)})
  zoomOutThreshold <- reactiveVal()
  observeEvent(input$map_zoom, {
    ifelse(input$map_zoom<13, zoomOutThreshold(TRUE), zoomOutThreshold(FALSE)) 
  })
  
  # Filter bikes by Company
  filteredBikes <- reactive({
    
    if(is.null(allbikes()))
      return()
    
    bikes <- allbikes() %>%
      filter(provider %in% input$providerGroup) %>%
      filter(vehicle_type %in% input$deviceGroup)
    
    return(bikes)
    })

  # Count devices in each neighborhood
  neighborhoodCt <- reactive({
    
    if(is.null(allbikes()))
      return()
    
    ct <- filteredBikes() %>%
      sf::st_join(neighborhoods, join=st_within, left=FALSE) %>%
      count(Name) %>%
      sf::st_set_geometry(NULL)
    
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
    
    providerLegend <- createProviderLegend(input$citychoice, systems)
    checkboxGroupInput('providerGroup',
                       label='Provider',
                       choiceNames=providerLegend$providerHTML,
                       choiceValues=providerLegend$providerValues,
                       selected=providerLegend$providerValues)
  })
  
  # Map
  output$map <- renderLeaflet({
    
    map <- leaflet(options(leafletOptions(preferCanvas = TRUE))) %>%
      addProviderTiles(providers$CartoDB.Positron, options = providerTileOptions(
        maxZoom=18,
        updateWhenZooming=FALSE,
        updateWhenIdle=TRUE)) %>%
      setView(lng=-118.329327, lat=34.0546143, zoom=12)
    
    map
    })
  
  # New observer to zoom with change of city
  observeEvent(input$citychoice, {
    print("observing event: input$citychoice")
    # Get systems for new city & exit if no bikes
    new_bikes <- allbikes()
    print(nrow(new_bikes))
    if(is.null(new_bikes)||nrow(new_bikes)<1){
      return()}
    
    # Resize map bounds to extent
    bbox <- unname(st_bbox(new_bikes)) # fitBounds won't accept named vectors, so unname
    if(input$citychoice == "la_region"){
      leafletProxy("map") %>% setView(lng=-118.329327, lat=34.0546143, zoom=12)
    } else {
      leafletProxy("map") %>% fitBounds(bbox[1], bbox[2], bbox[3], bbox[4])
      }
  })
  
  # Add bikes to map
  observeEvent(filteredBikes(), {
    bikes <- filteredBikes()
    radius <- radius()
    pal <- colorFactor(c('#24D000', '#F36396', '#4F1397','#5DBCD2','#000000','#FF5503'),
                       domain=c('lime','jump','lyft','cyclehop','bird','spin'),
                       ordered=TRUE)
    
    if(nrow(bikes) > 1 && !is.null(bikes)){
      leafletProxy("map") %>%
        clearMarkers() %>%
        addCircleMarkers(data=bikes,
                         radius=radius,
                         stroke=FALSE,
                         fillOpacity=0.9,
                         fillColor=pal(bikes$provider),
                         label=bikes$provider,
                         group="Devices")
  } else {leafletProxy("map") %>% clearMarkers()}})
  
  # Change  
  observeEvent(c(zoomOutThreshold(),filteredBikes()),{
    
    radius <- radius()
    bikes <- filteredBikes()
    
    if(is.null(bikes)){
      showNotification(paste0("No available devices in ",
                              names(which(cities == input$citychoice))),
                       type = "warning",
                       duration = 10)
      return()}
    
    neighborhoodCt <- neighborhoodCt()
    pal <- colorFactor(c('#24D000', '#F36396', '#4F1397','#5DBCD2','#000000','#FF5503'),
                       domain=c('lime', 'jump', 'lyft','cyclehop','bird','spin'),
                       ordered=TRUE)

      if(input$map_zoom < 13){
        
        labels <- sprintf(
          "<strong>%s</strong><br/>%g devices",
          neighborhoodCt$Name, neighborhoodCt$n
        ) %>% lapply(htmltools::HTML)
        
        leafletProxy("map") %>%
          clearShapes() %>%
          clearMarkers() %>%
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
                                                          weight=4,
                                                          opacity=1,
                                                          bringToFront=TRUE))
      
      } else {leafletProxy("map") %>% clearShapes()}

    if(nrow(bikes) > 1 && !is.null(bikes)){
      leafletProxy("map") %>%
        addCircleMarkers(data=bikes,
                         radius=radius,
                         stroke=FALSE,
                         fillOpacity=0.9,
                         fillColor=pal(bikes$provider),
                         label=bikes$provider,
                         group="Devices")}

    })
}