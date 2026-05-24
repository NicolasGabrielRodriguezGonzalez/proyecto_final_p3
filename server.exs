# =============================================================
#  AZAR S.A. - Servidor Central
#  Ejecutar: elixir --name server@192.168.1.59 --cookie azar server.exs
# =============================================================

Mix.install([{:jason, "~> 1.4"}])

Code.require_file("shared/json_store.exs",       __DIR__)
Code.require_file("server/logger.exs",            __DIR__)
Code.require_file("server/sorteo_server.exs",     __DIR__)
Code.require_file("server/sorteo_supervisor.exs", __DIR__)
Code.require_file("server/router.exs",            __DIR__)

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

# Monitorear conexiones y desconexiones de nodos
# :net_kernel.monitor_nodes/1 avisa cuando un nodo se conecta o desconecta
:net_kernel.monitor_nodes(true)

# Proceso que escucha eventos de conexion/desconexion
spawn(fn ->
  loop_monitor = fn loop ->
    receive do
      {:nodeup, nodo_remoto} ->
        nodo_str  = to_string(nodo_remoto)
        tipo      = cond do
          String.starts_with?(nodo_str, "admin")  -> "ADMINISTRADOR"
          String.starts_with?(nodo_str, "player") -> "JUGADOR"
          true                                     -> "NODO"
        end
        ip = nodo_str |> String.split("@") |> Enum.at(1)
        IO.puts("")
        IO.puts("╔══════════════════════════════════════════════╗")
        IO.puts("║  [+] " <> tipo <> " CONECTADO")
        IO.puts("║      Nodo : " <> nodo_str)
        IO.puts("║      IP   : " <> ip)
        IO.puts("╚══════════════════════════════════════════════╝")
        Azar.Server.Logger.log("conexion:" <> nodo_str, :ok)
        loop.(loop)

      {:nodedown, nodo_remoto} ->
        nodo_str  = to_string(nodo_remoto)
        tipo      = cond do
          String.starts_with?(nodo_str, "admin")  -> "ADMINISTRADOR"
          String.starts_with?(nodo_str, "player") -> "JUGADOR"
          true                                     -> "NODO"
        end
        ip = nodo_str |> String.split("@") |> Enum.at(1)
        IO.puts("")
        IO.puts("╔══════════════════════════════════════════════╗")
        IO.puts("║  [-] " <> tipo <> " DESCONECTADO")
        IO.puts("║      Nodo : " <> nodo_str)
        IO.puts("║      IP   : " <> ip)
        IO.puts("╚══════════════════════════════════════════════╝")
        Azar.Server.Logger.log("desconexion:" <> nodo_str, :ok)
        loop.(loop)
    end
  end
  loop_monitor.(loop_monitor)
end)

IO.puts(" Esperando conexiones de admin y player...")
IO.puts("")

Process.sleep(:infinity)
