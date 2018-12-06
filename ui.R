#######################
# LA GBFS Map UI Code #
#######################

library(leaflet)
library(shinydashboard)

providerNames <- c('Bird','HOPR','JUMP','Lime','Lyft','Razor')
providerValues <- c('bird','hopr','jump','lime','lyft','razor')
providerHTML <- lapply(1:length(providerNames), function(x){
  lblHTML <- '<img src="%s_circle.png" height="12" width="12" style="margin: 0px 4px 2px 0px">%s'
  return(HTML(sprintf(lblHTML, providerValues[x], providerNames[x])))
})
deviceTypes <- list('Scooter'='scooter','E-Bike'='ebike','Bike'='bike')
names <- c("Lime"='lime',"JUMP"='jump',"Lyft"='lyft',"HOPR"='cyclehop',"Bird"='bird', 'Razor'='razor', 'Skip'='skip')
colors <- c('#24D000', 'pink', '#4F1397','#5DBCD2','black','red','#fcce24')

# Dashboard
dashboardPage(
  skin="black",
  dashboardHeader(title="Swarm of Scooters"),
  dashboardSidebar(
      sidebarMenu(
        checkboxGroupInput('providerGroup', label='Provider', choiceNames=providerHTML, choiceValues=providerValues, selected=providerValues),
        checkboxGroupInput('deviceGroup', label='Device Type', choices=deviceTypes, selected=deviceTypes, inline=TRUE),
        actionButton("download", "Refresh Data")),
        div(HTML("<i>This map was compiled based on data from the American Communities Survey. To see a list of
                 currently available ACS Estimates, visit <a href='https://www.socialexplorer.com/data/metadata/'>
                 Social Explorer</a>. To understand the differences between different types of ACS Estimates,
                 visit <a href='https://www.census.gov/programs-surveys/acs/guidance/estimates.html'>this ACS
                 Guidance Document</a></i>"))),
  dashboardBody(
    tags$head(tags$style(HTML('
      .main-header .logo {
        font-weight: bold;
      }
    '))),
    tags$style(type = "text/css", "#map {height: calc(100vh - 80px) !important;}"),
    leafletOutput("map"))
)

