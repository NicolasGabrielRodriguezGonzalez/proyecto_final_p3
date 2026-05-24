# =============================================================
#  AZAR S.A. - Servidor Central
#  Ejecutar: elixir --name server@IP_SERVIDOR --cookie azar server.exs
# =============================================================

Mix.install([{:jason, "~> 1.4"}])

Code.require_file("shared/json_store.exs",       __DIR__)
Code.require_file("server/logger.exs",            __DIR__)
Code.require_file("server/sorteo_server.exs",     __DIR__)
Code.require_file("server/sorteo_supervisor.exs", __DIR__)
Code.require_file("server/router.exs",            __DIR__)

# =====================================================
# CAMBIA ESTAS IPs POR LAS REALES DE TU RED
ip_admin  = "192.168.1.57"   # IP del PC que corre admin
ip_player = "192.168.1.57"   # IP del PC que corre player
#                               (si admin y player estan en el
#                                mismo PC, usan la misma IP)
# =====================================================

IO.puts("")
IO.puts("╔══════════════════════════════════════════════╗")
IO.puts("║          AZAR S.A. - Sistema de Sorteos      ║")
IO.puts("║              SERVIDOR CENTRAL                ║")
IO.puts("╚══════════════════════════════════════════════╝")
IO.puts("")
IO.puts(" Iniciando componentes...")
IO.puts("")

case Azar.Server.SorteoSupervisor.start() do
  {:ok, _pid} ->
    IO.puts(" [OK] SorteoSupervisor activo")
  error ->
    IO.puts(" [ERROR] No se pudo iniciar SorteoSupervisor: " <> inspect(error))
    System.halt(1)
end

case Azar.Server.Router.start() do
  {:ok, _pid} ->
    IO.puts(" [OK] Router activo y registrado globalmente")
  error ->
    IO.puts(" [ERROR] No se pudo iniciar Router: " <> inspect(error))
    System.halt(1)
end

sorteos_activos = Azar.Server.SorteoSupervisor.sorteos_activos()
nodo = Node.self() |> to_string()

IO.puts("")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("  Nodo    : " <> nodo)
IO.puts("  Sorteos : " <> to_string(length(sorteos_activos)) <>
        " cargado(s) -> " <> Enum.join(sorteos_activos, ", "))
IO.puts("  Bitacora: log/bitacora.txt")
IO.puts("  Estado  : Esperando conexiones...")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("")

Azar.Server.Logger.info("Servidor iniciado. Nodo: " <> nodo)

# Conectar a admin y player despues de 3 segundos
# para que los 3 nodos se vean entre si
spawn(fn ->
  :timer.sleep(3000)
  admin_node  = String.to_atom("admin@"  <> ip_admin)
  player_node = String.to_atom("player@" <> ip_player)

  case Node.connect(admin_node) do
    true  -> IO.puts(" [OK] Admin conectado:  " <> to_string(admin_node))
    false -> IO.puts(" [INFO] Admin aun no disponible: " <> to_string(admin_node))
  end

  case Node.connect(player_node) do
    true  -> IO.puts(" [OK] Player conectado: " <> to_string(player_node))
    false -> IO.puts(" [INFO] Player aun no disponible: " <> to_string(player_node))
  end
end)

IO.puts(" Esperando conexiones...")
IO.puts("")

Process.sleep(:infinity)
