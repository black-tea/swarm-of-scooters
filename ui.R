#######################
# LA GBFS Map UI Code #
#######################

library(leaflet)
library(shinyWidgets)
library(shinydashboard)

providerNames <- c('Bird','HOPR','JUMP','Lime','Lyft','Razor')
providerIcons <- c('bird_circle','hopr_circle','jump_circle','lime_circle','lyft_circle','razor_circle')
providerValues <- c('bird','hopr','jump','lime','lyft','razor')
# providerHTML <- lapply(1:length(providers), function(x){
#   return(HTML(paste0(toString(providers[x],'<img src='))))
# })
deviceTypes <- list('Scooter'='scooter','E-Bike'='ebike','Bike'='bike')
choiceNames <- list(HTML('Lime<img src="lime_circle.png" height="12" width="12" style="margin: 0px 0px 2px 4px">'),
                    HTML('Bird<img src="bird_circle.png" height="12" width="12" style="margin: 0px 0px 2px 4px">'),
                    HTML('HOPR<img src="hopr_circle.png" height="12" width="12" style="margin: 0px 0px 2px 4px">'),
                    HTML('Lyft<img src="lyft_circle.png" height="12" width="12" style="margin: 0px 0px 2px 4px">'),
                    HTML('Razor<img src="razor_circle.png" height="12" width="12" style="margin: 0px 0px 2px 4px">'))
choiceValues <- c(2,3,4,5,6)
names <- c("Lime"='lime',"JUMP"='jump',"Lyft"='lyft',"HOPR"='cyclehop',"Bird"='bird', 'Razor'='razor', 'Skip'='skip')
colors <- c('#24D000', 'pink', '#4F1397','#5DBCD2','black','red','#fcce24')
lapply(1:length(names), function(x) {
  n <- length(names)
  col <- colors[x]
  css_col <- paste0("variable div.checkbox:nth-child(",x,") span{color: ", col,"; font-size: 16px; font-weight: bold}")
  tags$style(type="text/css", css_col)
})

dashboardPage(
  skin="black",
  dashboardHeader(title="Swarm of Scooters"),#, titleWidth = 300),
  dashboardSidebar(
      sidebarMenu(
        checkboxGroupInput('test', label='Provider', choiceNames=choiceNames, choiceValues=choiceValues),
        checkboxGroupInput('providerGroup', label='Provider', choices=names, selected=names),
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

