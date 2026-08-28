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
      area = c(recife_bbox[2],
               recife_bbox[1],
               recife_bbox[4],
               recife_bbox[3]),
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
