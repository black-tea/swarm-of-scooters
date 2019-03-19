#######################
# LA GBFS Map UI Code #
#######################

library(leaflet)
library(shinydashboard)

# Setup
providerNames <- c('Bird','HOPR','JUMP','Lime','Lyft','Razor')
providerValues <- c('bird','hopr','jump','lime','lyft','razor')
providerHTML <- lapply(1:length(providerNames), function(x){
  lblHTML <- '<img src="%s_circle.png" height="12" width="12" style="margin: 0px 4px 2px 0px">%s'
  return(HTML(sprintf(lblHTML, providerValues[x], providerNames[x])))})
deviceTypes <- list('Scooter'='scooter','E-Bike'='ebike','Bike'='bike')

# Dashboard
dashboardPage(
  skin="black",
  dashboardHeader(title="Swarm of Scooters"),
  dashboardSidebar(
      sidebarMenu(
        uiOutput('citySelect'),
        uiOutput('providerSelect'),
        checkboxGroupInput('deviceGroup', label='Device Type', choices=deviceTypes, selected=deviceTypes, inline=TRUE),
        actionButton("download", "Refresh Data")),
        HTML("<div style='padding-left:15px; padding-right:15px'><i>This map shows the current location of dockless
             devices in cities throughout the U.S. based on publicly-available GBFS feeds.
             Read more about the project <a href='https://medium.com/p/55a2afca46b1'>
             here</a>.</i></div>")),
  dashboardBody(
    tags$head(tags$style(HTML('
      .main-header .logo {
        font-weight: bold;}'))),
    tags$style(type = "text/css", "#map {height: calc(100vh - 80px) !important;}"),
    leafletOutput("map"))
)

