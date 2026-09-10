# Pacotes ----

library(geobr)

library(tidyverse)

library(sf)

library(ecmwfr)

library(terra)

library(tidyterra)

library(ggview)

library(magick)

# Shapefile do Brasil ----

## Baixar ----

br <- geobr::read_state(year = 2025)

## Visualizar ----

br

ggplot() +
  geom_sf(data = br, color = "black")

## Coordenadas do bbox ----

br_bbox <- br |> sf::st_bbox()

br_bbox
