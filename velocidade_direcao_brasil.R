# PAcotes ----

library(geobr)

library(tidyverse)

library(sf)

library(ecmwfr)

library(terra)

library(tidyterra)

library(patchwork)

library(ggview)

library(magick)

# Shapefile de REcife ----

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

    velocidade <- ggplot() +
      tidyterra::geom_spatraster(data = raster[["Velocidade (m/s)"]]) +
      facet_wrap(~lyr) +
      scale_fill_viridis_c(na.value = "transparent")

    direcao <- ggplot() +
      tidyterra::geom_spatraster(data = raster[["Direção (°)"]]) +
      facet_wrap(~lyr) +
      scale_fill_viridis_c(na.value = "transparent")

    (velocidade + direcao) +
      labs(title = data) +
      ggview::canvas(height = 10, width = 14)

    },
  .progress = TRUE)

## Calcular a direão das setas ----

df_dir <- purrr::imap_dfr(
  raster_vento_trat_vel,
  \(raster, data){

    raster |>
      aggregate(fact = 20, fun = "mean") |>
      as.data.frame(xy = TRUE) |>
      dplyr::mutate(angle_rad = (90 - (`Direção (°)` + 180)) * pi / 180,
                    lyr = data)

    },
  .progress = TRUE)

df_dir

## Criar mapas ----

mapas <- purrr::imap(
  raster_vento_trat_vel,
  \(raster, data){

    ggplot() +
      tidyterra::geom_spatraster(data = raster[["Velocidade (m/s)"]]) +
      scale_fill_viridis_c(na.value = "transparent",
                           guide = guide_colourbar(
                             title = "Velocidade do vento (m/s)",
                             title.position = "top",
                             title.hjust = 0.5,
                             barwidth = 30,
                             barheight = 2.5,
                             frame.colour = "black",
                             ticks.colour = "black"
                           )) +
      geom_sf(data = br, color = "black", fill = "transparent",
              linewidth = 1) +
      geom_spoke(data = df_dir |>
                   dplyr::filter(lyr == data),
                 aes(x = x, y = y,
                     angle = angle_rad,
                     radius = 3),
                 arrow = arrow(length = unit(0.1, "cm")),
                 color = "orange") +
      labs(title = paste0("Velocidade e direção do vento do Brasil para a data de ",
                          data)) +
      theme_bw() +
      theme(axis.text = element_text(size = 20, color = "black"),
            legend.text = element_text(size = 20, color = "black"),
            legend.title = element_text(size = 20, color = "black"),
            legend.position = "bottom",
            strip.text = element_text(size = 30, color = "black"),
            strip.background = element_rect(color = "black",
                                            linewidth = 1),
            panel.border = element_rect(color = "black", linewidth = 1),
            plot.title = element_text(size = 30, color = "black", hjust = 0.5)) +
      ggview::canvas(height = 10, width = 14)

    },
    .progress = TRUE)

mapas

## Gif animado ----

### Criar gif ----

imagens <- purrr::map(
  mapas,
  purrr::in_parallel(

    \(p){

      img <- magick::image_graph(height = 10 * 150,
                                 width = 16 * 150,
                                 res = 150)

      grid::grid.newpage()

      grid::grid.draw(ggplot2::ggplotGrob(p))

      dev.off()

      img

    }

  ),
  .progress = TRUE) |>
  magick::image_join()

imagens

## Criar o gif ----

gif_vento <- imagens |> magick::image_animate(fps = 1)

gif_vento

## Exportar gif ----

gif_vento |>
  magick::image_scale("1280x1066!") |>
  magick::image_write("./velocidade_direcao_vento.gif")
