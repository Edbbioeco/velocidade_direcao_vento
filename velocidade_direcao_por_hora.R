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

# Baixar rasters de velocidade e diração do vento ----

## Autenticar token ----

ecmwfr::wf_set_key(key = Sys.getenv("CDS_TOKEN"))

## Fazer requizições ----

requisicoes <- purrr::map(
  sprintf("%02d:00", 0:23),
  \(hora){

    list(
      dataset_short_name = "reanalysis-era5-land",
      variable = c("10m_u_component_of_wind", "10m_v_component_of_wind"),
      year = "2026",
      month = "08",
      day = "03",
      time = hora,
      area = c(br_bbox[2],
               br_bbox[1],
               br_bbox[4],
               br_bbox[3]),
      format = "netcdf",
      target = paste0("era5land_vento_", hora, ".nc")
    )

  },
  .progress = TRUE) |>
  setNames(paste0("03-08-2026 ",
                  sprintf("%02dh00", 0:23)))

requisicoes

## Baixar rasters ----

dir_tmp <- tempdir()

raster_vento <- purrr::map2(
  requisicoes,
  sprintf("%02dh00", 0:23),
  \(requisicao, hora){

    tryCatch({

      ecmwfr::wf_request(
        request  = requisicao,
        transfer = TRUE,
        path = dir_tmp)

      unzip(zipfile = file.path(dir_tmp,
                                paste0("era5land_vento_",
                                       hora,
                                       ".zip")),
            exdir = file.path(dir_tmp,
                              paste0("era5land_vento_",
                                     hora)),
            overwrite = TRUE)

      terra::rast(file.path(file.path(dir_tmp,
                                      paste0("era5land_vento_",
                                             hora)),
                            "data_0.nc"))

      file.remove(file.path(dir_tmp,
                            paste0("era5land_vento_",
                                   hora, ".zip")))

    },
    error = \(e){

      NULL

    })

  },
  .progress = TRUE) |>
  setNames(paste0("03-08-2026 ",
                  sprintf("%02d:00", 0:23)))
