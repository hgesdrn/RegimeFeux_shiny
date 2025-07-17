library(shiny)
library(leaflet)
library(sf)
library(dplyr)
library(ggplot2)
library(geojsonio)

# Charger les données depuis .geojson et sf
zones_sf <- geojsonio::geojson_read("./Data/zones_styled.geojson", what = "sp") %>% 
  st_as_sf()

qc_contour <- readRDS("./Data/Province_contourSimp_wgs84.rds")

zone_centroids <- st_point_on_surface(zones_sf) %>%
  select(ZONE_ID)

ui <- fluidPage(
  titlePanel(NULL),
  tags$style(HTML("
    .header-title {
      background-color: #2C3E50;
      color: white;
      padding: 20px;
      font-size: 22px;
      font-weight: bold;
      text-align: left;
      text-transform: uppercase;
      border-radius: 0px;
      margin-bottom: 20px;
      box-shadow: 2px 2px 8px rgba(0,0,0,0.2);
    }
    .box-style {
      background-color: #f9f9f9;
      border: 1px solid #ccc;
      border-radius: 8px;
      padding: 20px;
      box-shadow: 2px 2px 8px rgba(0,0,0,0.1);
      height: 700px;
      overflow-y: auto;
    }
  ")),
  div("RÉGIMES DE FEUX AU QUÉBEC", class = "header-title"),
  fluidRow(
    column(3,
           div(class = "box-style",
               htmlOutput("info_text", height = "60px"),
               tags$hr(style = "border-top: 1px solid #aaa; margin-top: 20px; margin-bottom: 20px;"),
               plotOutput("barplot", height = "540px")
           )
    ),
    column(9,
           div(class = "box-style",
               leafletOutput("map", height = "640px")
           )
    )
  )
)

server <- function(input, output, session) {
  
  zone_bounds <- st_bbox(zones_sf)
  selected_zone <- reactiveVal(NULL)
  
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("CartoDB.Positron") %>%
      setView(lng = mean(c(zone_bounds$xmin, zone_bounds$xmax)),
              lat = mean(c(zone_bounds$ymin, zone_bounds$ymax)),
              zoom = 6) %>%
      addPolygons(
        data = qc_contour,
        color = "#000000",
        weight = 1,
        fill = FALSE
      ) %>%
      # Utiliser addPolygons avec les attributs du geojson
      addPolygons(
        data = zones_sf,
        layerId = ~ZONE_ID,
        fillColor = ~Couleur_hex,
        fillOpacity = 0.6,
        color = "black",
        weight = 1,
        label = ~ZONE_ID,
        labelOptions = labelOptions(
          style = list("font-weight" = "bold"),
          textOnly = TRUE,
          direction = "center"
        ),
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#666",
          bringToFront = TRUE
        )
      ) %>%
      addLabelOnlyMarkers(data = zone_centroids,
                          label = ~ZONE_ID,
                          labelOptions = labelOptions(noHide = TRUE,
                                                      direction = 'center',
                                                      textOnly = TRUE,
                                                      style = list(
                                                        "font-weight" = "bold",
                                                        "font-size" = "20px"
                                                      )))
  })
  
  observeEvent(input$map_shape_click, {
    zone_id <- input$map_shape_click$id
    selected <- zones_sf %>% filter(ZONE_ID == zone_id)
    selected_zone(selected)
  })
  
  output$info_text <- renderUI({
    z <- selected_zone()
    if (is.null(z)) {
      HTML("<b>Zone sélectionnée :</b><br><b>Cycle de feu :</b>")
    } else {
      HTML(paste0("<b>Zone sélectionnée :</b> ", z$ZONE_ID,
                  "<br><b>Cycle de feu :</b> ", z$CYCLE_FEU, " ans"))
    }
  })
  
  output$barplot <- renderPlot({
    if (is.null(selected_zone())) {
      ggplot(data.frame(x = "Aucune zone sélectionnée", y = 0), aes(x = x, y = y)) +
        geom_bar(stat = "identity", fill = "gray80") +
        labs(x = "Zone", y = "Superficie (km² x 1000)", title = "Sélectionnez une zone") +
        ylim(0, 100) +
        theme_minimal() +
        theme(
          axis.title.x = element_text(size = 16, face = "bold"),
          axis.title.y = element_text(size = 16, face = "bold"),
          axis.text.x = element_text(size = 12),
          axis.text.y = element_text(size = 12),
          plot.title = element_text(size = 18, face = "bold", hjust = 0.5)
        )
    } else {
      z <- selected_zone()
      ggplot(z, aes(x = ZONE_ID, y = SUPERFICIE / 1000)) +
        geom_bar(stat = "identity", fill = z$Couleur_hex) +
        labs(x = "Zone", y = "Superficie (km² x 1000)") +
        ylim(0, 100) +
        theme_minimal() +
        theme(
          axis.title.x = element_text(size = 16, face = "bold"),
          axis.title.y = element_text(size = 16, face = "bold"),
          axis.text.x = element_text(size = 12),
          axis.text.y = element_text(size = 12)
        )
    }
  })
  
}

shinyApp(ui, server)
