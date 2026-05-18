# =============================================================
#  Módulo: Azar.Admin.PremiosMenu
#  Responsabilidad: Gestión de premios (crear, listar, eliminar)
# =============================================================

defmodule Azar.Admin.PremiosMenu do

  def start do
    loop()
  end

  defp loop do
    IO.puts("")
    IO.puts("-------- GESTION DE PREMIOS --------")
    IO.puts("1. Crear premio para un sorteo")
    IO.puts("2. Listar premios")
    IO.puts("3. Eliminar premio")
    IO.puts("0. Volver")
    IO.puts("------------------------------------")

    case IO.gets("Seleccione una opcion: ") |> String.trim() do
      "1" -> crear_premio();   loop()
      "2" -> listar_premios(); loop()
      "3" -> eliminar_premio(); loop()
      "0" -> :ok
      _   -> IO.puts("Opcion invalida."); loop()
    end
  end

  # ============================================================
  # 1. CREAR PREMIO
  # ============================================================

  defp crear_premio do
    IO.puts("")
    IO.puts("=== CREAR PREMIO ===")

    # Mostrar sorteos disponibles para elegir
    listar_sorteos_pendientes()

    sorteo_id = IO.gets("ID del sorteo          : ") |> String.trim()

    if sorteo_id == "" do
      IO.puts("Operacion cancelada.")
    else
      # Verificar que el sorteo existe y no ha sido realizado
      case Azar.Shared.ClienteRouter.llamar({:get_sorteo, sorteo_id}) do
        {:ok, sorteo} ->
          if sorteo.realizado do
            IO.puts("[ERROR] No se pueden agregar premios a un sorteo ya realizado.")
          else
            nombre_premio = IO.gets("Nombre del premio      : ") |> String.trim()
            valor_str     = IO.gets("Valor del premio ($)   : ") |> String.trim()

            case Integer.parse(valor_str) do
              {valor, _} ->
                premio = %{nombre: nombre_premio, valor: valor}

                case Azar.Shared.ClienteRouter.llamar({:agregar_premio, sorteo_id, premio}) do
                  {:ok, msg} ->
                    IO.puts("")
                    IO.puts("[OK] " <> msg)
                    IO.puts("     Sorteo  : " <> sorteo.nombre)
                    IO.puts("     Premio  : " <> nombre_premio)
                    IO.puts("     Valor   : $" <> to_string(valor))
                    IO.puts("     Por frac: $" <> to_string(div(valor, sorteo.num_fracciones)) <>
                            " (cada fraccion)")

                  {:error, msg} ->
                    IO.puts("[ERROR] " <> msg)
                end

              :error ->
                IO.puts("[ERROR] El valor debe ser un numero entero.")
            end
          end

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
      end
    end
  end

  # ============================================================
  # 2. LISTAR PREMIOS
  # ============================================================

  defp listar_premios do
    IO.puts("")
    IO.puts("=== LISTADO DE PREMIOS (agrupados por sorteo) ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, []} ->
        IO.puts("No hay sorteos registrados.")

      {:ok, sorteos} ->
        # Ordenar por fecha
        sorteos_ordenados = Enum.sort_by(sorteos, & &1.fecha)

        hay_premios = Enum.any?(sorteos_ordenados, fn s ->
          length(s.premios || []) > 0
        end)

        if not hay_premios do
          IO.puts("No hay premios registrados en ningun sorteo.")
        else
          Enum.each(sorteos_ordenados, fn s ->
            premios = s.premios || []
            if length(premios) > 0 do
              IO.puts("")
              estado = if s.realizado, do: "[REALIZADO]", else: "[PENDIENTE]"
              IO.puts("Sorteo: " <> s.nombre <> " - " <> s.fecha <> " " <> estado)
              IO.puts(String.duplicate("-", 50))

              Enum.each(premios, fn p ->
                valor_fraccion = div(p.valor, s.num_fracciones)
                IO.puts("  Premio  : " <> p.nombre)
                IO.puts("  Valor   : $" <> to_string(p.valor))
                IO.puts("  x frac  : $" <> to_string(valor_fraccion) <>
                        " (de " <> to_string(s.num_fracciones) <> " fracciones)")

                # Si el sorteo ya se realizó, mostrar si este premio fue entregado
                if s.realizado and s.ganadores != nil do
                  ganador = Enum.find(s.ganadores, fn g -> g.premio == p.nombre end)
                  if ganador do
                    IO.puts("  Ganador : Numero " <> ganador.numero)
                  end
                end

                IO.puts("")
              end)
            end
          end)
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 3. ELIMINAR PREMIO
  # ============================================================

  defp eliminar_premio do
    IO.puts("")
    IO.puts("=== ELIMINAR PREMIO ===")
    IO.puts("NOTA: Solo se puede eliminar si el sorteo no tiene clientes.")
    IO.puts("")

    # Mostrar sorteos con sus premios
    listar_sorteos_con_premios()

    sorteo_id = IO.gets("ID del sorteo  : ") |> String.trim()

    if sorteo_id == "" do
      IO.puts("Operacion cancelada.")
    else
      case Azar.Shared.ClienteRouter.llamar({:get_sorteo, sorteo_id}) do
        {:ok, sorteo} ->
          premios = sorteo.premios || []

          if length(premios) == 0 do
            IO.puts("[INFO] Este sorteo no tiene premios.")
          else
            # Mostrar premios del sorteo seleccionado
            IO.puts("")
            IO.puts("Premios del sorteo '" <> sorteo.nombre <> "':")
            Enum.with_index(premios, 1) |> Enum.each(fn {p, i} ->
              IO.puts("  " <> to_string(i) <> ". " <> p.nombre <>
                      " - $" <> to_string(p.valor))
            end)

            nombre_premio = IO.gets("Nombre del premio a eliminar: ") |> String.trim()

            existe = Enum.any?(premios, fn p -> p.nombre == nombre_premio end)

            if not existe do
              IO.puts("[ERROR] No se encontro el premio '" <> nombre_premio <> "'.")
            else
              confirmacion = IO.gets("Confirmar eliminacion (s/n): ")
                |> String.trim()
                |> String.downcase()

              if confirmacion == "s" do
                case Azar.Shared.ClienteRouter.llamar({:eliminar_premio, sorteo_id, nombre_premio}) do
                  {:ok, msg}    -> IO.puts("[OK] " <> msg)
                  {:error, msg} -> IO.puts("[ERROR] " <> msg)
                end
              else
                IO.puts("Eliminacion cancelada.")
              end
            end
          end

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
      end
    end
  end

  # ============================================================
  # HELPERS PRIVADOS
  # ============================================================

  # Lista solo sorteos pendientes (no realizados) para crear premios
  defp listar_sorteos_pendientes do
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        pendientes = Enum.filter(sorteos, fn s -> not s.realizado end)
        if length(pendientes) > 0 do
          IO.puts("Sorteos disponibles:")
          Enum.each(pendientes, fn s ->
            IO.puts("  " <> s.id <> " -> " <> s.nombre <> " (" <> s.fecha <> ")")
          end)
          IO.puts("")
        else
          IO.puts("No hay sorteos pendientes.")
        end
      _ -> :ok
    end
  end

  # Lista sorteos que tienen al menos un premio
  defp listar_sorteos_con_premios do
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        con_premios = Enum.filter(sorteos, fn s ->
          length(s.premios || []) > 0 and not s.realizado
        end)
        if length(con_premios) > 0 do
          IO.puts("Sorteos con premios (no realizados):")
          Enum.each(con_premios, fn s ->
            total_premios = length(s.premios)
            IO.puts("  " <> s.id <> " -> " <> s.nombre <>
                    " (" <> to_string(total_premios) <> " premio(s))")
          end)
          IO.puts("")
        else
          IO.puts("No hay sorteos pendientes con premios.")
        end
      _ -> :ok
    end
  end

end
