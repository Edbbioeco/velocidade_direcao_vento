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

br <- geobr::read_country(year = 2025)

## Visualizar ----

br

ggplot() +
  geom_sf(data = br, color = "black")

## Coordenadas do bbox ----

br_bbox <- br |> sf::st_bbox()

br_bbox

# Baixar rasters de velocidade e diração do vento ----

## Autenticar token ----

ecmwfr::wf_set_key(key = Sys.getenv("CDS_TOKEN"))

## Fazer requizições ----

requisicoes <- purrr::map(
  stringr::str_pad(1:31, width = 2, pad = "0"),
  \(dia){

    list(
      dataset_short_name = "reanalysis-era5-land",
      variable = c("10m_u_component_of_wind", "10m_v_component_of_wind"),
      year = "2026",
      month = "07",
      day = dia,
      time = "12:00",
      area = c(br_bbox[2],
               br_bbox[1],
               br_bbox[4],
               br_bbox[3]),
      format = "netcdf",
      target = "era5land_vento.nc"
      )

    },
  .progress = TRUE) |>
  setNames(paste0(stringr::str_pad(1:31, width = 2, pad = "0"),
                  "-07-2026"))

requisicoes

## Criar diretório ----

dir.create("./dados_clim", showWarnings = FALSE)

## Baixar rasters ----

raster_vento <- purrr::map(
  requisicoes,
  \(requisicao){

    tryCatch({

      ecmwfr::wf_request(
        request  = requisicao,
        transfer = TRUE,
        path = paste0("./dados_clim/")
        )

      unzip(zipfile = "dados_clim/era5land_vento.zip",
            exdir = "dados_clim/era5land_vento")

      terra::rast("dados_clim/era5land_vento/data_0.nc")

      },
      error = \(e){

        NULL

      })

    },
  .progress = TRUE) |>
  setNames(paste0(stringr::str_pad(1:31, width = 2, pad = "0"),
                  "-07-2026"))
