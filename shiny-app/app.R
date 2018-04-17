#
# Prototype Visualization of the Park data
#

library(shiny)
library(shinythemes)
library(shinycssloaders)
library(tidyverse)
library(viridis)
library(lubridate)

ui <- fluidPage(
   theme = shinytheme("yeti"),
   
   # Application title
   titlePanel("A Day in the Park"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
        width = 2,
         selectInput("day",
                     "Day:",
                     choices = c("Friday", "Saturday", "Sunday")),
        selectInput("detailNameSelect",
                    "Show details for:",
                    choices = c()),
        selectInput("detailFromToSelect",
                    "Show connections from/to:",
                    choices = c()),
        sliderInput("detailTimeWindow", 
                    "Show time window", 
                    min = 0, max = 1, 
                    value = c(0,1))
      ),
      
      mainPanel(
        # plot with people entering leaving the park
        # TODO
        
        # Plot with small multiples of all locations
        plotOutput("allLocsPlot", width = "1300px", height = "1200px") %>% 
          withSpinner(type = 5, color = "#aaaaaa"),
        
        # Plot with selected location
        plotOutput("detailPlot", width = "1300px", height = "800px") %>% 
          withSpinner(type = 5, color = "#aaaaaa")
      )
   )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {

  # load preprocessed data
  # summaries for the overview
  df5 <- read_rds("df5.RDS")
  df15 <- read_rds("df15.RDS")
  dfdetail <- read_rds("dfdetail.RDS")
  locs <- read_rds("../data/checkin_locs.RDS")
  
  observe({
    updateSelectInput(session, "detailNameSelect",
                      choices = unique(df5$name)
    )
  })
  
  observe({
    updateSelectInput(session, "detailFromToSelect",
                      choices = unique(df5$name)
    )
  })
  
  observe({
    rng <- dfdetail %>%
      filter(day == input$day) %>%
      .$hour %>%
      range()
      
    updateSliderInput(session, "detailTimeWindow",
                      min = rng[1], max = rng[2],
                      value = rng)
  })
  
  # small multiples with all locations  
   output$allLocsPlot <- renderPlot({
     df5 %>%
       filter(day == input$day) %>%
       ggplot(aes(x, y, xend = xend, yend = yend, color = median_duration)) +
         geom_curve(aes(alpha = n)) +
         geom_rect(aes(xmin = x, xmax = x+minutes(15), 
                       ymin = 0, ymax = (n_checkedin/max(n_checkedin))*.7),
                   inherit.aes = F, fill = "black", color = NA, alpha = .5,
                   data = filter(df15, day == input$day)) +
         geom_rect(aes(xmin = x, xmax = x+minutes(15), 
                       ymin = (median_duration/max(median_duration))*-.7, ymax = 0, fill = median_duration),
                   inherit.aes = F, color = NA, alpha = .8,
                   data = filter(df15, day == input$day), show.legend = FALSE) +
         #geom_point(
        #   data = filter(df15, day == input$day),
        #  aes(x = x, y = y, size = n_checkedin, color = median_duration), inherit.aes = F) +
         facet_wrap(~ name) +
         scale_y_continuous(expand = c(.3, .3)) +
         scale_fill_viridis(option = "A") +
         scale_color_viridis(option = "A") +
         #lims(color = range(df5$duration)) +
         theme_minimal() +
         theme(panel.grid.major.y = element_blank(),
               panel.grid.minor.y = element_blank(),
               axis.text.y = element_blank(),
               legend.position = "right")
   })
   
   
   output$detailPlot <- renderPlot({
     req(input$detailNameSelect)
     req(input$detailTimeWindow)
     req(input$detailFromToSelect)
     
     minDate <- input$detailTimeWindow[1]
     maxDate <- input$detailTimeWindow[2]
     
     selId <- locs[[which(locs$name == input$detailNameSelect), "checkin_id"]]
     
     df_plot <- dfdetail %>%
       filter(day == input$day, name == input$detailNameSelect)
     
     df_highlight <- filter(df_plot,
                            (prev_checkin_id == selId | 
                              next_checkin_id == selId),
                            between(hour, minDate, maxDate)
                            )
     
     print(nrow(df_plot))
     print(nrow(df_highlight))
     
     
     df_plot %>%
       ggplot(aes(x, y, xend = xend, yend = yend, color = median_duration)) +
       geom_curve(alpha =.01, curvature = .1) +
       geom_curve(alpha = .5, curvature = .1, data = df_highlight) +
       geom_point(aes(x = x, y = y, size = n_checkedin, color = median_duration), 
                  inherit.aes = F,
                  data = df_highlight,
                  color = "black") +
       geom_point(aes(x = x, y = 0, size = n_checkedin)) +
       scale_fill_viridis(option = "B") +
       scale_color_viridis(option = "B") +
       theme_minimal() +
       theme(panel.grid.major.y = element_blank(),
             panel.grid.minor.y = element_blank(),
             axis.text.y = element_blank(),
             legend.position = "bottom")
   })
}

# Run the application 
shinyApp(ui = ui, server = server)

