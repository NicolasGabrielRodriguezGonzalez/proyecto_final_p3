# =============================================================
#  Módulo: Azar.Server.SorteoSupervisor
#  Responsabilidad: Iniciar y supervisar todos los GenServers de sorteo
#  - Al arrancar, levanta un GenServer por cada JSON en data/sorteos/
#  - Permite agregar nuevos sorteos en caliente (sin reiniciar)
#  - Permite consultar qué sorteos están activos
#  - Si un GenServer cae, puede reiniciarlo
# =============================================================

defmodule Azar.Server.SorteoSupervisor do
  use GenServer

  @data_dir "data/sorteos"
  @name     :azar_sorteo_supervisor

  # ------------------------------------------------------------
  # API PÚBLICA
  # ------------------------------------------------------------

  def start do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @doc "Inicia un GenServer para un nuevo sorteo recién creado"
  def iniciar_sorteo(sorteo_id) do
    GenServer.call(@name, {:iniciar_sorteo, sorteo_id})
  end

  @doc "Retorna la lista de IDs de sorteos activos en memoria"
  def sorteos_activos do
    GenServer.call(@name, :sorteos_activos)
  end

  @doc "Detiene el GenServer de un sorteo (al eliminarlo)"
  def detener_sorteo(sorteo_id) do
    GenServer.call(@name, {:detener_sorteo, sorteo_id})
  end

  # ------------------------------------------------------------
  # CALLBACKS GENSERVER
  # ------------------------------------------------------------

  @impl true
  def init(_) do
    Azar.Server.Logger.separador()
    Azar.Server.Logger.info("SorteoSupervisor arrancando...")

    # Levantar un GenServer por cada JSON existente
    activos = @data_dir
      |> Azar.Shared.JsonStore.list_files()
      |> Enum.reduce([], fn path, acc ->
        sorteo_id = Path.basename(path, ".json")

        case Azar.Server.SorteoServer.start_link(sorteo_id) do
          {:ok, pid} ->
            Azar.Server.Logger.info("  ✓ Sorteo cargado: #{sorteo_id} (pid: #{inspect(pid)})")
            [{sorteo_id, pid} | acc]

          {:error, {:already_started, pid}} ->
            Azar.Server.Logger.info("  ~ Sorteo ya activo: #{sorteo_id}")
            [{sorteo_id, pid} | acc]

          {:error, reason} ->
            Azar.Server.Logger.error("  ✗ Error cargando #{sorteo_id}: #{inspect(reason)}")
            acc
        end
      end)

    total = length(activos)
    Azar.Server.Logger.info("SorteoSupervisor listo. #{total} sorteo(s) activo(s).")
    Azar.Server.Logger.separador()

    # El estado es un mapa %{"sorteo_id" => pid}
    estado = Enum.into(activos, %{})
    {:ok, estado}
  end

  # --- Iniciar un nuevo sorteo en caliente ---
  @impl true
  def handle_call({:iniciar_sorteo, sorteo_id}, _from, estado) do
    case Azar.Server.SorteoServer.start_link(sorteo_id) do
      {:ok, pid} ->
        Azar.Server.Logger.info("Nuevo sorteo iniciado: #{sorteo_id}")
        nuevo_estado = Map.put(estado, sorteo_id, pid)
        {:reply, {:ok, pid}, nuevo_estado}

      {:error, {:already_started, pid}} ->
        {:reply, {:ok, pid}, estado}

      {:error, reason} ->
        Azar.Server.Logger.error("No se pudo iniciar sorteo #{sorteo_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, estado}
    end
  end

  # --- Consultar sorteos activos ---
  @impl true
  def handle_call(:sorteos_activos, _from, estado) do
    ids = Map.keys(estado)
    {:reply, ids, estado}
  end

  # --- Detener un sorteo ---
  @impl true
  def handle_call({:detener_sorteo, sorteo_id}, _from, estado) do
    case Map.get(estado, sorteo_id) do
      nil ->
        {:reply, {:error, "Sorteo no encontrado en memoria"}, estado}

      pid ->
        Process.exit(pid, :normal)
        nuevo_estado = Map.delete(estado, sorteo_id)
        Azar.Server.Logger.info("Sorteo detenido: #{sorteo_id}")
        {:reply, :ok, nuevo_estado}
    end
  end

end
