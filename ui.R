#######################
# LA GBFS Map UI Code #
#######################

library(leaflet)
library(shinyWidgets)

names <- c("Lime","JUMP","Lyft","HOPR","Bird")
colors <- c('#24D000', 'red', 'purple','#5DBCD2','black') 

fluidPage(           
    div(class="outer",
        
        tags$head(
          # Include our custom CSS
          includeCSS("styles.css")),
        
        # If not using custom CSS, set height of leafletOutput to a number instead of percent
        leafletOutput("map", width="100%", height="100%"),
        
        absolutePanel(
          id="controls", class="panel panel-default", fixed=TRUE,
          draggable=TRUE, top=60, left="auto", right=20, bottom="auto",
          width=330, height="auto",
                      
          h3("Scooters & Bikes in LA"),
                      
          checkboxGroupInput('providerGroup', label='Filter by Company', inline=TRUE, 
                             choices = list('Lime'='lime',
                                            'Bird'='bird',
                                            'JUMP'='jump',
                                            'Lyft'='lyft',
                                            'HOPR'='cyclehop'),
                             selected = c('lime','jump','lyft','cyclehop','bird')),

          actionButton("download", "Refresh now"),
          
          lapply(1:length(names), function(x) {
            print(x)
            n <- length(names)
            col <- colors[x]
            #col <- gplots::col2hex(rainbow(n)[x])
            css_col <- paste0("#variable div.checkbox:nth-child(",x,") span{color: ", col,"; font-size: 16px; font-weight: bold}")
            tags$style(type="text/css", css_col)
          }),
          checkboxGroupButtons(inputId = "Id033", 
                               label = "Company", choices = names, direction = "vertical"),
          awesomeCheckboxGroup(inputId = "Id022", 
                               label = "Company", choices = names, selected = "A"),
          checkboxGroupInput("variable", "Company", 
                             choices = names, selected = names),
          materialSwitch(inputId="Id054", value=TRUE,
                         label="Bird", right=TRUE,
                         status="primary"),
          div()

          # ,HTML("<i>This map was compiled based on data from the American Communities Survey. To see a list of
          #        currently available ACS Estimates, visit <a href='https://www.socialexplorer.com/data/metadata/'>
          #         Social Explorer</a>. To understand the differences between different types of ACS Estimates,
          #        visit <a href='https://www.census.gov/programs-surveys/acs/guidance/estimates.html'>this ACS
          #        Guidance Document</a></i>")
                      
        )
        
    )

)
