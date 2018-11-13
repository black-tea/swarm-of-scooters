#######################
# LA GBFS Map UI Code #
#######################

library(leaflet)

# Choices for drop-downs
mode_vars <- c(
  "Car, Truck, Van" = "car_pct",
  "Public Transit" = "transit_pct",
  "Bicycle" = "bicycle_pct",
  "Walked" = "walk_pct"
)
geo_vars <- c(
  "LA City - Tract" = "city_tract",
  "LA County - Tract" = "county_tract"
)
map_color_vars <- c(
  "Single 5-Year Estimate" = "5yr_est",
  "Change over Time" = "time_change"
)

years <- c(2015,2014,2013,2012,2011,2010)


fluidPage(           
    div(class="outer",
        
        tags$head(
          # Include our custom CSS
          includeCSS("styles.css")),
        
        # If not using custom CSS, set height of leafletOutput to a number instead of percent
        leafletOutput("map", width="100%", height="100%"),
        
        # Shiny versions prior to 0.11 should use class = "modal" instead.
        absolutePanel(
          id = "controls", class = "panel panel-default", fixed = TRUE,
          draggable = TRUE, top = 60, left = "auto", right = 20, bottom = "auto",
          width = 330, height = "auto",
                      
          h3("How Does LA Get to Work?"),
                      
          selectInput("geography","Geography",geo_vars, selected = "city_tract"),
          selectInput("mode", "Commute Mode", mode_vars, selected = "car_pct"),
          selectInput("maptype", "Map Color", map_color_vars, selected = "5yr_est"),
          conditionalPanel(
              condition = "input.maptype == '5yr_est'",
              selectInput("yearview", "5-Year Estimate Ending In", years, selected = 2015)),
              conditionalPanel(
                condition = "input.maptype == 'time_change'",
                sliderInput(inputId = "yearRange",
                            label = "Select the Year Range",
                            sep = "",
                            step = 1,
                            min = 2010, max = 2015, value = c(2010,2015))),
              HTML("<i>This map was compiled based on data from the American Communities Survey. To see a list of
                     currently available ACS Estimates, visit <a href='https://www.socialexplorer.com/data/metadata/'>
                      Social Explorer</a>. To understand the differences between different types of ACS Estimates,
                     visit <a href='https://www.census.gov/programs-surveys/acs/guidance/estimates.html'>this ACS
                     Guidance Document</a></i>")
                      
        )
        
    )

)
