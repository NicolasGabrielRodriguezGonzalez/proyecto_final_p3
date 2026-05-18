# =============================================================
#  Módulo: Azar.Admin.SorteosMenu
#  Responsabilidad: Gestión completa de sorteos
# =============================================================

defmodule Azar.Admin.SorteosMenu do

  def start do
    loop()
  end

  defp loop do
    IO.puts("")
    IO.puts("-------- GESTION DE SORTEOS --------")
    IO.puts("1. Crear sorteo")
    IO.puts("2. Listar sorteos")
    IO.puts("3. Eliminar sorteo")
    IO.puts("4. Consultar clientes de un sorteo")
    IO.puts("5. Consultar ingresos por sorteo")
    IO.puts("6. Consultar premios entregados")
    IO.puts("7. Balance general de sorteos")
    IO.puts("0. Volver")
    IO.puts("------------------------------------")

    case IO.gets("Seleccione una opcion: ") |> String.trim() do
      "1" -> crear_sorteo();              loop()
      "2" -> listar_sorteos();            loop()
      "3" -> eliminar_sorteo();           loop()
      "4" -> consultar_clientes();        loop()
      "5" -> consultar_ingresos();        loop()
      "6" -> consultar_premios_entregados(); loop()
      "7" -> consultar_balance();         loop()
      "0" -> :ok
      _   -> IO.puts("Opcion invalida."); loop()
    end
  end

  # ============================================================
  # 1. CREAR SORTEO
  # ============================================================

  defp crear_sorteo do
    IO.puts("")
    IO.puts("=== CREAR SORTEO ===")

    nombre    = IO.gets("Nombre del sorteo       : ") |> String.trim()
    fecha     = IO.gets("Fecha (YYYY-MM-DD)       : ") |> String.trim()
    valor_str = IO.gets("Valor billete completo   : ") |> String.trim()
    frac_str  = IO.gets("Cantidad de fracciones   : ") |> String.trim()
    cant_str  = IO.gets("Cantidad de billetes     : ") |> String.trim()

    # Validar que los números sean válidos
    with {valor, _} <- Integer.parse(valor_str),
         {fracs, _} <- Integer.parse(frac_str),
         {cant,  _} <- Integer.parse(cant_str) do

      datos = %{
        nombre:           nombre,
        fecha:            fecha,
        valor_billete:    valor,
        num_fracciones:   fracs,
        cantidad_billetes: cant
      }

      case Azar.Shared.ClienteRouter.llamar({:crear_sorteo, datos}) do
        {:ok, sorteo_id} ->
          IO.puts("")
          IO.puts("[OK] Sorteo creado exitosamente.")
          IO.puts("     ID asignado: " <> sorteo_id)

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
      end

    else
      _ ->
        IO.puts("[ERROR] Los valores de valor, fracciones y cantidad deben ser numeros enteros.")
    end
  end

  # ============================================================
  # 2. LISTAR SORTEOS
  # ============================================================

  defp listar_sorteos do
    IO.puts("")
    IO.puts("=== LISTADO DE SORTEOS (ordenados por fecha) ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, []} ->
        IO.puts("No hay sorteos registrados.")

      {:ok, sorteos} ->
        Enum.each(sorteos, fn s ->
          IO.puts("")
          IO.puts("----------------------------------------")
          IO.puts("  Nombre  : " <> s.nombre)
          IO.puts("  ID      : " <> s.id)
          IO.puts("  Fecha   : " <> s.fecha)
          IO.puts("  Billete : $" <> to_string(s.valor_billete) <>
                  " | Fracciones: " <> to_string(s.num_fracciones))
          IO.puts("  Billetes: " <> to_string(length(s.billetes)))
          IO.puts("  Estado  : " <> if(s.realizado, do: "REALIZADO", else: "PENDIENTE"))

          # Mostrar premios si existen
          premios = s.premios || []
          if length(premios) > 0 do
            IO.puts("  Premios :")
            Enum.each(premios, fn p ->
              IO.puts("    - " <> p.nombre <> ": $" <> to_string(p.valor))
            end)
          else
            IO.puts("  Premios : Sin premios asignados")
          end

          # Si ya se realizó, mostrar ganadores
          if s.realizado and s.ganadores != nil do
            IO.puts("  Ganadores:")
            Enum.each(s.ganadores, fn g ->
              IO.puts("    - " <> g.premio <> " -> Numero: " <> g.numero <>
                      " | $" <> to_string(g.valor))
            end)
          end
        end)
        IO.puts("----------------------------------------")
        IO.puts("Total: " <> to_string(length(sorteos)) <> " sorteo(s)")

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 3. ELIMINAR SORTEO
  # ============================================================

  defp eliminar_sorteo do
    IO.puts("")
    IO.puts("=== ELIMINAR SORTEO ===")

    listar_ids()

    sorteo_id = IO.gets("ID del sorteo a eliminar : ") |> String.trim()

    if sorteo_id == "" do
      IO.puts("Operacion cancelada.")
    else
      confirmacion = IO.gets("Confirmar eliminacion de '" <> sorteo_id <> "' (s/n): ")
        |> String.trim()
        |> String.downcase()

      if confirmacion == "s" do
        case Azar.Shared.ClienteRouter.llamar({:eliminar_sorteo, sorteo_id}) do
          {:ok, msg} ->
            IO.puts("[OK] " <> msg)

          {:error, msg} ->
            IO.puts("[ERROR] " <> msg)
        end
      else
        IO.puts("Eliminacion cancelada.")
      end
    end
  end

  # ============================================================
  # 4. CONSULTAR CLIENTES DE UN SORTEO
  # ============================================================

  defp consultar_clientes do
    IO.puts("")
    IO.puts("=== CLIENTES POR SORTEO ===")

    listar_ids()

    sorteo_id = IO.gets("ID del sorteo: ") |> String.trim()

    case Azar.Shared.ClienteRouter.llamar({:get_clientes_sorteo, sorteo_id}) do
      {:ok, %{completos: completos, fracciones: fracciones}} ->
        IO.puts("")
        IO.puts("-- COMPRADORES DE BILLETE COMPLETO (" <>
                to_string(length(completos)) <> ") --")

        if length(completos) == 0 do
          IO.puts("  (ninguno)")
        else
          Enum.each(completos, fn c ->
            IO.puts("  " <> c.cliente_nombre <>
                    " | Billete: " <> c.numero_billete <>
                    " | $" <> to_string(c.valor))
          end)
        end

        IO.puts("")
        IO.puts("-- COMPRADORES POR FRACCION (" <>
                to_string(length(fracciones)) <> ") --")

        if length(fracciones) == 0 do
          IO.puts("  (ninguno)")
        else
          Enum.each(fracciones, fn c ->
            IO.puts("  " <> c.cliente_nombre <>
                    " | Billete: " <> c.numero_billete <>
                    " Fraccion " <> to_string(c.fraccion) <>
                    " | $" <> to_string(c.valor))
          end)
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 5. CONSULTAR INGRESOS POR SORTEO
  # ============================================================

  defp consultar_ingresos do
    IO.puts("")
    IO.puts("=== INGRESOS POR SORTEO ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, []} ->
        IO.puts("No hay sorteos registrados.")

      {:ok, sorteos} ->
        IO.puts("")
        Enum.each(sorteos, fn s ->
          case Azar.Shared.ClienteRouter.llamar({:get_ingresos, s.id}) do
            {:ok, total} ->
              estado = if s.realizado, do: "[REALIZADO]", else: "[PENDIENTE]"
              IO.puts("  " <> estado <> " " <> s.nombre <>
                      " (" <> s.fecha <> ")" <>
                      " -> $" <> to_string(total))
            _ -> :ok
          end
        end)

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 6. CONSULTAR PREMIOS ENTREGADOS EN SORTEOS PASADOS
  # ============================================================

  defp consultar_premios_entregados do
    IO.puts("")
    IO.puts("=== PREMIOS ENTREGADOS EN SORTEOS PASADOS ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        realizados = Enum.filter(sorteos, & &1.realizado)

        if length(realizados) == 0 do
          IO.puts("No hay sorteos realizados aun.")
        else
          Enum.each(realizados, fn s ->
            IO.puts("")
            IO.puts("=== " <> s.nombre <> " (" <> s.fecha <> ") ===")

            # Calcular ingresos
            {:ok, ingresos} = Azar.Shared.ClienteRouter.llamar({:get_ingresos, s.id})

            # Calcular total de premios entregados
            ganadores = s.ganadores || []
            total_premios = Enum.reduce(ganadores, 0, fn g, acc ->
              acc + g.valor
            end)

            ganancia = ingresos - total_premios

            # Mostrar ganadores con nombre del cliente
            IO.puts("  Premios entregados:")
            Enum.each(ganadores, fn g ->
              # Buscar quien compró ese número
              compras = s.compras || []
              compradores = Enum.filter(compras, fn c ->
                c.numero_billete == g.numero
              end)

              nombres = Enum.map(compradores, & &1.cliente_nombre) |> Enum.join(", ")
              ganador_str = if nombres == "", do: "Sin ganador (no vendido)", else: nombres

              IO.puts("    - " <> g.premio <>
                      " | Numero: " <> g.numero <>
                      " | $" <> to_string(g.valor) <>
                      " | Ganador: " <> ganador_str)
            end)

            IO.puts("")
            IO.puts("  Dinero recolectado : $" <> to_string(ingresos))
            IO.puts("  Total en premios   : $" <> to_string(total_premios))

            if ganancia >= 0 do
              IO.puts("  Ganancia           : $" <> to_string(ganancia))
            else
              IO.puts("  Perdida            : $" <> to_string(abs(ganancia)))
            end
          end)
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 7. BALANCE GENERAL DE TODOS LOS SORTEOS
  # ============================================================

  defp consultar_balance do
    IO.puts("")
    IO.puts("=== BALANCE GENERAL DE SORTEOS ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, []} ->
        IO.puts("No hay sorteos registrados.")

      {:ok, sorteos} ->
        realizados = Enum.filter(sorteos, & &1.realizado)

        if length(realizados) == 0 do
          IO.puts("No hay sorteos realizados aun.")
        else
          IO.puts("")
          IO.puts(String.pad_trailing("SORTEO", 30) <>
                  String.pad_leading("INGRESOS", 12) <>
                  String.pad_leading("PREMIOS", 12) <>
                  String.pad_leading("BALANCE", 12))
          IO.puts(String.duplicate("-", 66))

          total_acumulado = Enum.reduce(realizados, 0, fn s, acc_total ->
            {:ok, ingresos} = Azar.Shared.ClienteRouter.llamar({:get_ingresos, s.id})

            ganadores = s.ganadores || []
            total_premios = Enum.reduce(ganadores, 0, fn g, acc -> acc + g.valor end)
            balance = ingresos - total_premios

            balance_str = if balance >= 0 do
              "+$" <> to_string(balance)
            else
              "-$" <> to_string(abs(balance))
            end

            IO.puts(String.pad_trailing(s.nombre, 30) <>
                    String.pad_leading("$" <> to_string(ingresos), 12) <>
                    String.pad_leading("$" <> to_string(total_premios), 12) <>
                    String.pad_leading(balance_str, 12))

            acc_total + balance
          end)

          IO.puts(String.duplicate("-", 66))

          if total_acumulado >= 0 do
            IO.puts("TOTAL ACUMULADO: GANANCIA de $" <> to_string(total_acumulado))
          else
            IO.puts("TOTAL ACUMULADO: PERDIDA de $" <> to_string(abs(total_acumulado)))
          end
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # HELPERS PRIVADOS
  # ============================================================

  # Muestra lista de IDs disponibles para seleccionar
  defp listar_ids do
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} when length(sorteos) > 0 ->
        IO.puts("Sorteos disponibles:")
        Enum.each(sorteos, fn s ->
          estado = if s.realizado, do: "[REALIZADO]", else: "[PENDIENTE]"
          IO.puts("  " <> s.id <> " -> " <> s.nombre <> " " <> estado)
        end)
        IO.puts("")
      _ -> :ok
    end
  end

end
