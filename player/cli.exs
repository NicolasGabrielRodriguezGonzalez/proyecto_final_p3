# =============================================================
#  Módulo: Azar.Player.CLI
#  Responsabilidad: Menú principal del jugador
# =============================================================

defmodule Azar.Player.CLI do

  def start do
    loop_login()
  end

  # ============================================================
  # MENÚ DE LOGIN / REGISTRO
  # ============================================================

  defp loop_login do
    IO.puts("")
    IO.puts("========== PORTAL JUGADOR ==========")
    IO.puts("1. Registrarse")
    IO.puts("2. Iniciar sesion")
    IO.puts("0. Salir")
    IO.puts("=====================================")

    case IO.gets("Seleccione una opcion: ") |> String.trim() do
      "1" ->
        case Azar.Player.Auth.registrar() do
          {:ok, _} -> loop_login()
          _        -> loop_login()
        end

      "2" ->
        case Azar.Player.Auth.login() do
          {:ok, cliente} -> menu_principal(cliente)
          {:error, _}    -> loop_login()
        end

      "0" ->
        IO.puts("Hasta luego.")

      _ ->
        IO.puts("Opcion invalida.")
        loop_login()
    end
  end

  # ============================================================
  # MENÚ PRINCIPAL (usuario autenticado)
  # ============================================================

  defp menu_principal(cliente) do
    IO.puts("")
    IO.puts("Sesion activa: " <> cliente.nombre <>
            " | Doc: " <> to_string(cliente.documento))
    loop_menu(cliente)
  end

  defp loop_menu(cliente) do
    IO.puts("")
    IO.puts("-------- MENU PRINCIPAL --------")
    IO.puts("1. Consultar sorteos disponibles")
    IO.puts("2. Consultar numeros disponibles")
    IO.puts("3. Comprar billete / fraccion")
    IO.puts("4. Devolver compra")
    IO.puts("5. Historial de compras")
    IO.puts("6. Premios obtenidos")
    IO.puts("7. Balance personal")
    IO.puts("8. Ver notificaciones")
    IO.puts("0. Cerrar sesion")
    IO.puts("--------------------------------")

    case IO.gets("Seleccione una opcion: ") |> String.trim() do
      "1" -> consultar_sorteos();                          loop_menu(cliente)
      "2" -> consultar_numeros();                          loop_menu(cliente)
      "3" -> Azar.Player.ComprasMenu.comprar(cliente);     loop_menu(cliente)
      "4" -> Azar.Player.ComprasMenu.devolver(cliente);    loop_menu(cliente)
      "5" -> Azar.Player.ComprasMenu.historial(cliente);   loop_menu(cliente)
      "6" -> premios_obtenidos(cliente);                   loop_menu(cliente)
      "7" -> balance_personal(cliente);                    loop_menu(cliente)
      "8" -> Azar.Player.Notificaciones.ver(cliente);      loop_menu(cliente)
      "0" -> cerrar_sesion()
      _   -> IO.puts("Opcion invalida.");                  loop_menu(cliente)
    end
  end

  # ============================================================
  # 1. CONSULTAR SORTEOS DISPONIBLES
  # ============================================================

  defp consultar_sorteos do
    IO.puts("")
    IO.puts("=== SORTEOS DISPONIBLES ===")

    case Azar.Shared.ClienteRouter.llamar(:sorteos_disponibles) do
      {:ok, []} ->
        IO.puts("No hay sorteos disponibles en este momento.")

      {:ok, sorteos} ->
        IO.puts("Hay " <> to_string(length(sorteos)) <> " sorteo(s) disponible(s):")
        IO.puts("")

        Enum.each(sorteos, fn s ->
          # Contar billetes y fracciones disponibles
          total_fracs_disp = Enum.reduce(s.billetes, 0, fn b, acc ->
            acc + length(b.fracciones_disponibles)
          end)
          billetes_completos = Enum.count(s.billetes, fn b ->
            length(b.fracciones_disponibles) == s.num_fracciones
          end)

          IO.puts("  ID      : " <> s.id)
          IO.puts("  Nombre  : " <> s.nombre)
          IO.puts("  Fecha   : " <> s.fecha)
          IO.puts("  Billete : $" <> to_string(s.valor_billete) <>
                  " | Fraccion: $" <> to_string(div(s.valor_billete, s.num_fracciones)))
          IO.puts("  Billetes completos disponibles : " <> to_string(billetes_completos))
          IO.puts("  Fracciones disponibles         : " <> to_string(total_fracs_disp))

          premios = s.premios || []
          if length(premios) > 0 do
            IO.puts("  Premios :")
            Enum.each(premios, fn p ->
              IO.puts("    - " <> p.nombre <> ": $" <> to_string(p.valor))
            end)
          end
          IO.puts("")
        end)

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 2. CONSULTAR NUMEROS DISPONIBLES
  # ============================================================

  defp consultar_numeros do
    IO.puts("")
    IO.puts("=== NUMEROS DISPONIBLES ===")

    case Azar.Shared.ClienteRouter.llamar(:sorteos_disponibles) do
      {:ok, []} ->
        IO.puts("No hay sorteos disponibles.")

      {:ok, sorteos} ->
        Enum.each(sorteos, fn s ->
          IO.puts("")
          IO.puts("Sorteo: " <> s.nombre <> " (" <> s.id <> ")")
          IO.puts(String.duplicate("-", 45))

          disponibles = Enum.filter(s.billetes, fn b ->
            length(b.fracciones_disponibles) > 0
          end)

          if length(disponibles) == 0 do
            IO.puts("  No hay numeros disponibles.")
          else
            # Separar: billetes completos vs parciales
            completos  = Enum.filter(disponibles, fn b ->
              length(b.fracciones_disponibles) == s.num_fracciones
            end)
            parciales  = Enum.filter(disponibles, fn b ->
              length(b.fracciones_disponibles) < s.num_fracciones and
              length(b.fracciones_disponibles) > 0
            end)

            if length(completos) > 0 do
              nums = Enum.map(completos, & &1.numero) |> Enum.join(", ")
              IO.puts("  Billetes completos : " <> nums)
            end

            if length(parciales) > 0 do
              IO.puts("  Billetes parciales (fracciones libres):")
              Enum.each(parciales, fn b ->
                fracs = Enum.join(b.fracciones_disponibles, ", ")
                IO.puts("    Billete " <> b.numero <> " -> fracciones: [" <> fracs <> "]")
              end)
            end
          end
        end)

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 6. PREMIOS OBTENIDOS
  # ============================================================

  defp premios_obtenidos(cliente) do
    IO.puts("")
    IO.puts("=== PREMIOS OBTENIDOS ===")

    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        # Buscar sorteos realizados donde el cliente tenga un número ganador
        premios_ganados = Enum.flat_map(sorteos, fn s ->
          if s.realizado and s.ganadores != nil do
            ganadores = s.ganadores || []
            compras   = s.compras   || []

            # Ver si el cliente tiene alguna compra con número ganador
            Enum.flat_map(ganadores, fn g ->
              compra_ganadora = Enum.find(compras, fn c ->
                "#{c.cliente_doc}" == "#{cliente.documento}" and
                c.numero_billete == g.numero
              end)

              if compra_ganadora != nil do
                valor_ganado = if compra_ganadora.fraccion == nil do
                  g.valor
                else
                  div(g.valor, s.num_fracciones)
                end

                [%{
                  sorteo:  s.nombre,
                  fecha:   s.fecha,
                  premio:  g.premio,
                  numero:  g.numero,
                  fraccion: compra_ganadora.fraccion,
                  valor:   valor_ganado
                }]
              else
                []
              end
            end)
          else
            []
          end
        end)

        if length(premios_ganados) == 0 do
          IO.puts("No ha ganado ningun premio todavia.")
        else
          IO.puts("Ha ganado " <> to_string(length(premios_ganados)) <> " premio(s)!")
          IO.puts("")

          Enum.each(premios_ganados, fn p ->
            tipo = if p.fraccion == nil do
              "Billete completo"
            else
              "Fraccion " <> to_string(p.fraccion)
            end
            IO.puts("  Sorteo  : " <> p.sorteo <> " (" <> p.fecha <> ")")
            IO.puts("  Premio  : " <> p.premio)
            IO.puts("  Numero  : " <> p.numero <> " | " <> tipo)
            IO.puts("  Valor   : $" <> to_string(p.valor))
            IO.puts("")
          end)
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # 7. BALANCE PERSONAL
  # ============================================================

  defp balance_personal(cliente) do
    IO.puts("")
    IO.puts("=== BALANCE PERSONAL ===")

    # Calcular total gastado
    case Azar.Shared.ClienteRouter.llamar(:listar_sorteos) do
      {:ok, sorteos} ->
        total_gastado = Enum.reduce(sorteos, 0, fn s, acc ->
          compras = s.compras || []
          mis_compras = Enum.filter(compras, fn c ->
            "#{c.cliente_doc}" == "#{cliente.documento}"
          end)
          acc + Enum.reduce(mis_compras, 0, fn c, a -> a + c.valor end)
        end)

        # Calcular total ganado
        total_ganado = Enum.reduce(sorteos, 0, fn s, acc ->
          if s.realizado and s.ganadores != nil do
            ganadores = s.ganadores || []
            compras   = s.compras   || []

            ganado = Enum.reduce(ganadores, 0, fn g, a ->
              compra = Enum.find(compras, fn c ->
                "#{c.cliente_doc}" == "#{cliente.documento}" and
                c.numero_billete == g.numero
              end)
              if compra != nil do
                if compra.fraccion == nil do
                  a + g.valor
                else
                  a + div(g.valor, s.num_fracciones)
                end
              else
                a
              end
            end)

            acc + ganado
          else
            acc
          end
        end)

        balance = total_ganado - total_gastado

        IO.puts("")
        IO.puts("  Total gastado en sorteos : $" <> to_string(total_gastado))
        IO.puts("  Total ganado en premios  : $" <> to_string(total_ganado))
        IO.puts(String.duplicate("-", 40))

        if balance >= 0 do
          IO.puts("  GANANCIA NETA            : $" <> to_string(balance))
        else
          IO.puts("  PERDIDA NETA             : $" <> to_string(abs(balance)))
        end

      {:error, msg} ->
        IO.puts("[ERROR] " <> msg)
    end
  end

  # ============================================================
  # HELPERS PRIVADOS
  # ============================================================

  defp cerrar_sesion do
    IO.puts("")
    IO.puts("Sesion cerrada. Hasta luego!")
    loop_login()
  end

end
