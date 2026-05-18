# =============================================================
#  Módulo: Azar.Player.ComprasMenu
#  Responsabilidad: Comprar, devolver y consultar historial
# =============================================================

defmodule Azar.Player.ComprasMenu do

  # ============================================================
  # 1. COMPRAR BILLETE O FRACCION
  # ============================================================

  def comprar(cliente) do
    IO.puts("")
    IO.puts("=== COMPRAR BILLETE / FRACCION ===")

    # Mostrar sorteos disponibles
    case Azar.Shared.ClienteRouter.llamar(:sorteos_disponibles) do
      {:ok, []} ->
        IO.puts("No hay sorteos disponibles en este momento.")

      {:ok, sorteos} ->
        IO.puts("Sorteos disponibles:")
        Enum.each(sorteos, fn s ->
          IO.puts("  " <> s.id <> " -> " <> s.nombre <>
                  " | Fecha: " <> s.fecha <>
                  " | Billete: $" <> to_string(s.valor_billete) <>
                  " | Fracciones: " <> to_string(s.num_fracciones))
        end)
        IO.puts("")

        sorteo_id = IO.gets("ID del sorteo        : ") |> String.trim()

        # Buscar el sorteo seleccionado
        sorteo = Enum.find(sorteos, fn s -> s.id == sorteo_id end)

        if sorteo == nil do
          IO.puts("[ERROR] Sorteo no encontrado.")
        else
          IO.puts("")
          IO.puts("Tipo de compra:")
          IO.puts("  1. Billete completo ($" <> to_string(sorteo.valor_billete) <> ")")
          valor_fraccion = div(sorteo.valor_billete, sorteo.num_fracciones)
          IO.puts("  2. Fraccion         ($" <> to_string(valor_fraccion) <> " c/u)")

          tipo = IO.gets("Seleccione (1/2)     : ") |> String.trim()

          case tipo do
            "1" -> comprar_billete_completo(cliente, sorteo)
            "2" -> comprar_fraccion(cliente, sorteo)
            _   -> IO.puts("[ERROR] Opcion invalida.")
          end
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 2. DEVOLVER COMPRA
  # ============================================================

  def devolver(cliente) do
    IO.puts("")
    IO.puts("=== DEVOLVER COMPRA ===")
    IO.puts("Solo se pueden devolver compras de sorteos no realizados.")
    IO.puts("")

    # Obtener compras del cliente desde sus datos
    compras_cliente = obtener_compras_cliente(cliente.documento)

    if length(compras_cliente) == 0 do
      IO.puts("No tiene compras registradas.")
    else
      # Filtrar solo las de sorteos no realizados
      compras_devolvibles = Enum.filter(compras_cliente, fn c ->
        case Azar.Shared.ClienteRouter.llamar({:get_sorteo, c.sorteo_id}) do
          {:ok, sorteo} -> not sorteo.realizado
          _             -> false
        end
      end)

      if length(compras_devolvibles) == 0 do
        IO.puts("No tiene compras devolvibles (todos los sorteos ya fueron realizados).")
      else
        IO.puts("Compras devolvibles:")
        Enum.with_index(compras_devolvibles, 1) |> Enum.each(fn {c, i} ->
          fraccion_str = if c.fraccion == nil do
            "Billete completo"
          else
            "Fraccion " <> to_string(c.fraccion)
          end
          IO.puts("  " <> to_string(i) <> ". Sorteo: " <> c.sorteo_id <>
                  " | Billete: " <> c.numero_billete <>
                  " | " <> fraccion_str <>
                  " | $" <> to_string(c.valor))
        end)

        IO.puts("")
        opcion_str = IO.gets("Numero de compra a devolver (0 para cancelar): ")
          |> String.trim()

        case Integer.parse(opcion_str) do
          {0, _} ->
            IO.puts("Devolucion cancelada.")

          {n, _} when n > 0 and n <= length(compras_devolvibles) ->
            compra = Enum.at(compras_devolvibles, n - 1)

            case Azar.Shared.ClienteRouter.llamar(
              {:devolver, compra.sorteo_id, cliente.documento,
               compra.numero_billete, compra.fraccion}
            ) do
              {:ok, msg} ->
                IO.puts("[OK] " <> msg)
                IO.puts("     Reembolso de $" <> to_string(compra.valor) <>
                        " procesado a su tarjeta.")

              {:error, msg} ->
                IO.puts("[ERROR] " <> msg)
            end

          _ ->
            IO.puts("[ERROR] Opcion invalida.")
        end
      end
    end
  end

  # ============================================================
  # 3. HISTORIAL DE COMPRAS
  # ============================================================

  def historial(cliente) do
    IO.puts("")
    IO.puts("=== HISTORIAL DE COMPRAS ===")

    compras = obtener_compras_cliente(cliente.documento)

    if length(compras) == 0 do
      IO.puts("No tiene compras registradas.")
    else
      IO.puts("")
      IO.puts(String.pad_trailing("SORTEO", 15) <>
              String.pad_trailing("BILLETE", 10) <>
              String.pad_trailing("TIPO", 18) <>
              String.pad_leading("VALOR", 10))
      IO.puts(String.duplicate("-", 55))

      total = Enum.reduce(compras, 0, fn c, acc ->
        fraccion_str = if c.fraccion == nil do
          "Completo"
        else
          "Fraccion " <> to_string(c.fraccion)
        end

        IO.puts(String.pad_trailing(c.sorteo_id, 15) <>
                String.pad_trailing(c.numero_billete, 10) <>
                String.pad_trailing(fraccion_str, 18) <>
                String.pad_leading("$" <> to_string(c.valor), 10))

        acc + c.valor
      end)

      IO.puts(String.duplicate("-", 55))
      IO.puts(String.pad_leading("TOTAL GASTADO: $" <> to_string(total), 55))
    end
  end

  # ============================================================
  # HELPERS PRIVADOS
  # ============================================================

  # Comprar billete completo
  defp comprar_billete_completo(cliente, sorteo) do
    IO.puts("")
    mostrar_billetes_disponibles(sorteo)

    numero = IO.gets("Numero de billete : ") |> String.trim()

    IO.puts("Confirmar compra del billete " <> numero <>
            " por $" <> to_string(sorteo.valor_billete) <> " (s/n): ")
    confirmacion = IO.gets("") |> String.trim() |> String.downcase()

    if confirmacion == "s" do
      case Azar.Shared.ClienteRouter.llamar(
        {:comprar, sorteo.id, cliente.documento, numero, nil}
      ) do
        {:ok, msg} ->
          IO.puts("[OK] " <> msg)
          IO.puts("     $" <> to_string(sorteo.valor_billete) <>
                  " cargados a su tarjeta terminada en " <>
                  ultimos_digitos(cliente.tarjeta))
          # Guardar compra en datos locales del cliente
          registrar_compra_local(cliente.documento, sorteo.id, numero, nil,
                                  sorteo.valor_billete)

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
      end
    else
      IO.puts("Compra cancelada.")
    end
  end

  # Comprar fraccion
  defp comprar_fraccion(cliente, sorteo) do
    IO.puts("")
    mostrar_billetes_disponibles(sorteo)

    numero   = IO.gets("Numero de billete : ") |> String.trim()
    fraccion = IO.gets("Numero de fraccion: ") |> String.trim()

    valor_fraccion = div(sorteo.valor_billete, sorteo.num_fracciones)

    IO.puts("Confirmar compra de la fraccion " <> fraccion <>
            " del billete " <> numero <>
            " por $" <> to_string(valor_fraccion) <> " (s/n): ")
    confirmacion = IO.gets("") |> String.trim() |> String.downcase()

    if confirmacion == "s" do
      case Azar.Shared.ClienteRouter.llamar(
        {:comprar, sorteo.id, cliente.documento, numero, fraccion}
      ) do
        {:ok, msg} ->
          IO.puts("[OK] " <> msg)
          IO.puts("     $" <> to_string(valor_fraccion) <>
                  " cargados a su tarjeta terminada en " <>
                  ultimos_digitos(cliente.tarjeta))
          registrar_compra_local(cliente.documento, sorteo.id, numero,
                                  String.to_integer(fraccion), valor_fraccion)

        {:error, msg} ->
          IO.puts("[ERROR] " <> msg)
      end
    else
      IO.puts("Compra cancelada.")
    end
  end

  # Mostrar billetes con fracciones disponibles
  defp mostrar_billetes_disponibles(sorteo) do
    case Azar.Shared.ClienteRouter.llamar({:get_sorteo, sorteo.id}) do
      {:ok, s} ->
        disponibles = Enum.filter(s.billetes, fn b ->
          length(b.fracciones_disponibles) > 0
        end)

        if length(disponibles) == 0 do
          IO.puts("No hay billetes disponibles.")
        else
          IO.puts("Billetes disponibles:")
          Enum.each(disponibles, fn b ->
            fracs = Enum.join(b.fracciones_disponibles, ", ")
            IO.puts("  Billete " <> b.numero <>
                    " | Fracciones libres: [" <> fracs <> "]")
          end)
          IO.puts("")
        end
      _ -> :ok
    end
  end

  # Obtener compras del cliente desde los sorteos
  defp obtener_compras_cliente(cliente_doc) do
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        Enum.flat_map(sorteos, fn s ->
          compras = s.compras || []
          compras
          |> Enum.filter(fn c -> "#{c.cliente_doc}" == "#{cliente_doc}" end)
          |> Enum.map(fn c -> Map.put(c, :sorteo_id, s.id) end)
        end)
      _ -> []
    end
  end

  # Guardar compra en el JSON del cliente
  defp registrar_compra_local(cliente_doc, sorteo_id, numero, fraccion, valor) do
    path     = "data/clientes.json"
    clientes = Azar.Shared.JsonStore.read_list(path)

    nuevos = Enum.map(clientes, fn c ->
      if "#{c.documento}" == "#{cliente_doc}" do
        compra = %{
          sorteo_id:      sorteo_id,
          numero_billete: numero,
          fraccion:       fraccion,
          valor:          valor
        }
        compras_actuales = Map.get(c, :compras, [])
        %{c | compras: compras_actuales ++ [compra]}
      else
        c
      end
    end)

    Azar.Shared.JsonStore.write(path, nuevos)
  end

  # Mostrar solo los últimos 4 dígitos de la tarjeta
  defp ultimos_digitos(tarjeta) do
    tarjeta
    |> String.replace(" ", "")
    |> String.slice(-4, 4)
  end

end
