# =============================================================
#  Módulo: Azar.Admin.CLI
#  Responsabilidad: Menú principal del administrador
# =============================================================

defmodule Azar.Admin.CLI do

  def start do
    bienvenida()
    loop()
  end

  # ============================================================
  # MENÚ PRINCIPAL
  # ============================================================

  defp loop do
    IO.puts("")
    IO.puts("========== MENU ADMINISTRADOR ==========")
    IO.puts("1. Gestion de Sorteos")
    IO.puts("2. Gestion de Premios")
    IO.puts("3. Actualizar fecha del sistema")
    IO.puts("0. Salir")
    IO.puts("=========================================")

    case IO.gets("Seleccione una opcion: ") |> String.trim() do
      "1" -> Azar.Admin.SorteosMenu.start(); loop()
      "2" -> Azar.Admin.PremiosMenu.start(); loop()
      "3" -> actualizar_fecha();             loop()
      "0" -> despedida()
      _   -> IO.puts("Opcion invalida."); loop()
    end
  end

  # ============================================================
  # 3. ACTUALIZAR FECHA DEL SISTEMA
  # ============================================================

  defp actualizar_fecha do
    IO.puts("")
    IO.puts("=== ACTUALIZAR FECHA DEL SISTEMA ===")
    IO.puts("Ejecuta todos los sorteos pendientes hasta la fecha indicada.")
    IO.puts("Asigna numeros ganadores aleatorios y notifica a los jugadores.")
    IO.puts("")

    # Mostrar sorteos pendientes primero
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        pendientes = Enum.filter(sorteos, fn s -> not s.realizado end)

        if length(pendientes) == 0 do
          IO.puts("No hay sorteos pendientes por realizar.")
        else
          IO.puts("Sorteos pendientes:")
          Enum.each(pendientes, fn s ->
            IO.puts("  - " <> s.nombre <> " | Fecha: " <> s.fecha)
          end)
          IO.puts("")

          fecha = IO.gets("Ingrese la fecha limite (YYYY-MM-DD): ") |> String.trim()

          if fecha == "" do
            IO.puts("Operacion cancelada.")
          else
            # Verificar formato de fecha básico
            if not fecha_valida?(fecha) do
              IO.puts("[ERROR] Formato de fecha invalido. Use YYYY-MM-DD")
            else
              IO.puts("")
              IO.puts("Procesando sorteos hasta el " <> fecha <> "...")
              IO.puts("")

              case Azar.Shared.ClienteRouter.llamar({:actualizar_fecha, fecha}) do
                {:ok, []} ->
                  IO.puts("[INFO] No habia sorteos pendientes hasta esa fecha.")

                {:ok, ejecutados} ->
                  IO.puts("Sorteos ejecutados: " <> to_string(length(ejecutados)))
                  IO.puts("")

                  Enum.each(ejecutados, fn {sorteo_id, resultado} ->
                    case resultado do
                      {:ok, ganadores} ->
                        IO.puts("[OK] Sorteo ejecutado: " <> sorteo_id)
                        IO.puts("     Ganadores:")
                        Enum.each(ganadores, fn g ->
                          IO.puts("       - " <> g.premio <>
                                  " -> Numero: " <> g.numero <>
                                  " | $" <> to_string(g.valor))
                        end)
                        IO.puts("     Notificaciones enviadas a los jugadores.")

                      {:error, msg} ->
                        IO.puts("[ERROR] Sorteo " <> sorteo_id <> ": " <> msg)
                    end
                    IO.puts("")
                  end)

                {:error, msg} ->
                  IO.puts("[ERROR] " <> msg)
              end
            end
          end
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # HELPERS PRIVADOS
  # ============================================================

  defp bienvenida do
    IO.puts("")
    IO.puts("========================================")
    IO.puts("   Bienvenido al Panel Administrador")
    IO.puts("   AZAR S.A. - Sistema de Sorteos")
    IO.puts("========================================")

    # Mostrar resumen rápido del estado del sistema
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        pendientes = Enum.count(sorteos, fn s -> not s.realizado end)
        realizados = Enum.count(sorteos, fn s -> s.realizado end)
        IO.puts("   Sorteos pendientes : " <> to_string(pendientes))
        IO.puts("   Sorteos realizados : " <> to_string(realizados))
      _ -> :ok
    end

    IO.puts("========================================")
  end

  defp despedida do
    IO.puts("")
    IO.puts("Cerrando sesion de administrador...")
    IO.puts("Hasta luego.")
  end

  defp fecha_valida?(fecha) do
    case String.split(fecha, "-") do
      [anio, mes, dia] ->
        String.length(anio) == 4 and
        String.length(mes)  == 2 and
        String.length(dia)  == 2 and
        match?({_, ""}, Integer.parse(anio)) and
        match?({_, ""}, Integer.parse(mes))  and
        match?({_, ""}, Integer.parse(dia))
      _ -> false
    end
  end

end
