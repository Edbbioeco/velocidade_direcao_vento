# PAcotes ----

library(geobr)

library(tidyverse)

library(sf)

library(ecmwfr)

library(terra)

library(tidyterra)

library(ggview)

library(magick)

# Shapefile de REcife ----

## Baixar ----

recife <- geobr::read_municipality(code_muni = 2611606,
                                   year = 2025)

## Visualizar ----

recife

ggplot() +
  geom_sf(data = recife, color = "black")

## Coordenadas do bbox ----

recife_bbox <- recife |> sf::st_bbox()

recife_bbox

# Baixar rasters de velocidade e diração do vento ----

## Autenticar token ----

ecmwfr::wf_set_key(key = Sys.getenv("CDS_TOKEN"))
