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
      target = paste0("era5land_vento_", dia, ".nc")
      )

    },
  .progress = TRUE) |>
  setNames(paste0(stringr::str_pad(1:31, width = 2, pad = "0"),
                  "-07-2026"))

requisicoes

## Criar diretório ----

dir.create("./dados_clim", showWarnings = FALSE)

## Baixar rasters ----

raster_vento <- purrr::map2(
  requisicoes,
  stringr::str_pad(1:31, width = 2, pad = "0"),
  \(requisicao, dia){

    tryCatch({

      ecmwfr::wf_request(
        request  = requisicao,
        transfer = TRUE,
        path = paste0("./dados_clim/")
        )

      unzip(zipfile = paste0("dados_clim/era5land_vento_",
                             dia,
                             ".zip"),
            exdir = paste0("dados_clim/era5land_vento_",
                           dia),
            overwrite = TRUE)

      file.remove(paste0("dados_clim/era5land_vento_",
                          dia,
                          ".zip"))

      terra::rast(paste0("dados_clim/era5land_vento_",
                         dia,
                         "/data_0.nc"))

      },
      error = \(e){

        NULL

      })

    },
  .progress = TRUE) |>
  setNames(paste0(stringr::str_pad(1:31, width = 2, pad = "0"),
                  "-07-2026"))

## Recortar paraa área do Brasil ----

raster_vento_trat <- purrr::map(
  raster_vento,
  \(raster){

    raster |>
      terra::mask(br) |>
      terra::crop(br)

    },
  .progress = TRUE)

raster_vento_trat

## Calcular velocidade e direção ----

raster_vento_trat_vel <- purrr::map(
  raster_vento_trat,
  \(raster){

    velocidade <- sqrt(raster$u10^2 + raster$v10^2)

    direcao <- (270 - atan2(raster$v10, raster$u10) * 180/pi) %% 360

    raster <- c(velocidade, direcao)

    names(raster) <- c("Velocidade (m/s)",
                       "Direção (°)")

    raster

    },
  .progress = TRUE)

## Visualizar ----

purrr::imap(
  raster_vento_trat_vel,
  \(raster, data){

    ggplot() +
      tidyterra::geom_spatraster(data = raster) +
      facet_wrap(~lyr) +
      scale_fill_viridis_c() +
      labs(title = data)

    },
  .progress = TRUE)
