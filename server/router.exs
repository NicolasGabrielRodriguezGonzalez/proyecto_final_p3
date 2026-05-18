# =============================================================
#  Módulo: Azar.Server.Router
#  Responsabilidad: Punto central de entrada del sistema.
#  - Recibe TODAS las solicitudes de admin y jugadores
#  - Las redirige al SorteoServer o módulo correspondiente
#  - Registra cada solicitud en el Logger
#  - Registrado globalmente para ser accesible desde otros nodos
# =============================================================

defmodule Azar.Server.Router do
  use GenServer

  @name :azar_router

  # ------------------------------------------------------------
  # API PÚBLICA — llamada desde admin.exs y player.exs
  # Esta función es la única que los clientes necesitan conocer
  # ------------------------------------------------------------

  def start do
    case GenServer.start_link(__MODULE__, [], name: {:global, @name}) do
      {:ok, pid} ->
        Azar.Server.Logger.info("Router iniciado y registrado globalmente (pid: #{inspect(pid)})")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Azar.Server.Logger.info("Router ya estaba activo (pid: #{inspect(pid)})")
        {:ok, pid}

      error ->
        Azar.Server.Logger.error("No se pudo iniciar el Router: #{inspect(error)}")
        error
    end
  end

  @doc """
  Función principal que usan los clientes remotos.
  Ejemplo desde admin:
    Azar.Server.Router.llamar({:crear_sorteo, datos})
  Ejemplo desde player:
    Azar.Server.Router.llamar({:comprar, "sorteo_001", "123456", "0001", 2})
  """
  def llamar(solicitud) do
    GenServer.call({:global, @name}, solicitud, 10_000)
  end

  # ------------------------------------------------------------
  # CALLBACKS GENSERVER
  # ------------------------------------------------------------

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  # ============================================================
  # SOLICITUDES DE SORTEOS (Admin)
  # ============================================================

  # Listar todos los sorteos
  @impl true
  def handle_call(:listar_sorteos, _from, state) do
    resultado = cargar_todos_los_sorteos()
    Azar.Server.Logger.log("listar_sorteos", :ok)
    {:reply, {:ok, resultado}, state}
  end

  # Crear un nuevo sorteo
  @impl true
  def handle_call({:crear_sorteo, datos}, _from, state) do
    sorteo_id = "sorteo_#{:os.system_time(:millisecond)}"
    path = "data/sorteos/#{sorteo_id}.json"

    nuevo_sorteo = %{
      id:             sorteo_id,
      nombre:         datos.nombre,
      fecha:          datos.fecha,
      valor_billete:  datos.valor_billete,
      num_fracciones: datos.num_fracciones,
      billetes:       generar_billetes(datos.cantidad_billetes, datos.num_fracciones),
      premios:        [],
      compras:        [],
      ganadores:      nil,
      realizado:      false
    }

    Azar.Shared.JsonStore.write(path, nuevo_sorteo)
    Azar.Server.SorteoSupervisor.iniciar_sorteo(sorteo_id)
    Azar.Server.Logger.log("crear_sorteo:#{datos.nombre}", :ok)
    {:reply, {:ok, sorteo_id}, state}
  end

  # Eliminar un sorteo
  @impl true
  def handle_call({:eliminar_sorteo, sorteo_id}, _from, state) do
    case Azar.Server.SorteoServer.get_info(sorteo_id) do
      {:ok, sorteo} ->
        premios = sorteo.premios || []

        if length(premios) > 0 do
          Azar.Server.Logger.log("eliminar_sorteo:#{sorteo_id}", {:error, "tiene premios"})
          {:reply, {:error, "No se puede eliminar: el sorteo tiene premios asociados"}, state}
        else
          Azar.Server.SorteoSupervisor.detener_sorteo(sorteo_id)
          File.rm("data/sorteos/#{sorteo_id}.json")
          Azar.Server.Logger.log("eliminar_sorteo:#{sorteo_id}", :ok)
          {:reply, {:ok, "Sorteo eliminado"}, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  # Consultar info de un sorteo
  @impl true
  def handle_call({:get_sorteo, sorteo_id}, _from, state) do
    resultado = Azar.Server.SorteoServer.get_info(sorteo_id)
    Azar.Server.Logger.log("get_sorteo:#{sorteo_id}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Consultar clientes de un sorteo
  @impl true
  def handle_call({:get_clientes_sorteo, sorteo_id}, _from, state) do
    resultado = Azar.Server.SorteoServer.get_clientes(sorteo_id)
    Azar.Server.Logger.log("get_clientes:#{sorteo_id}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Consultar ingresos de un sorteo
  @impl true
  def handle_call({:get_ingresos, sorteo_id}, _from, state) do
    resultado = Azar.Server.SorteoServer.get_ingresos(sorteo_id)
    Azar.Server.Logger.log("get_ingresos:#{sorteo_id}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # ============================================================
  # SOLICITUDES DE PREMIOS (Admin)
  # ============================================================

  # Agregar premio a un sorteo
  @impl true
  def handle_call({:agregar_premio, sorteo_id, premio}, _from, state) do
    resultado = Azar.Server.SorteoServer.agregar_premio(sorteo_id, premio)
    Azar.Server.Logger.log("agregar_premio:#{sorteo_id}:#{premio.nombre}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Eliminar premio de un sorteo
  @impl true
  def handle_call({:eliminar_premio, sorteo_id, nombre_premio}, _from, state) do
    resultado = Azar.Server.SorteoServer.eliminar_premio(sorteo_id, nombre_premio)
    Azar.Server.Logger.log("eliminar_premio:#{sorteo_id}:#{nombre_premio}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Listar premios de todos los sorteos
  @impl true
  def handle_call(:listar_premios, _from, state) do
    sorteos = cargar_todos_los_sorteos()
    premios = Enum.flat_map(sorteos, fn s ->
      Enum.map(s.premios || [], fn p -> Map.put(p, :sorteo, s.nombre) end)
    end)
    Azar.Server.Logger.log("listar_premios", :ok)
    {:reply, {:ok, premios}, state}
  end

  # Ejecutar sorteos pendientes hasta fecha dada
  @impl true
  def handle_call({:actualizar_fecha, fecha_limite}, _from, state) do
    sorteos = cargar_todos_los_sorteos()

    ejecutados = sorteos
      |> Enum.filter(fn s ->
        not s.realizado and s.fecha <= fecha_limite
      end)
      |> Enum.map(fn s ->
        resultado = Azar.Server.SorteoServer.realizar(s.id)
        Azar.Server.Logger.log("realizar_sorteo:#{s.id}", elem(resultado, 0))
        {s.id, resultado}
      end)

    {:reply, {:ok, ejecutados}, state}
  end

  # ============================================================
  # SOLICITUDES DE CLIENTES (Player)
  # ============================================================

  # Registrar nuevo cliente
  @impl true
  def handle_call({:registrar_cliente, datos}, _from, state) do
    path = "data/clientes.json"
    clientes = Azar.Shared.JsonStore.read_list(path)

    ya_existe = Enum.any?(clientes, &("#{&1.documento}" == "#{datos.documento}"))

    if ya_existe do
      Azar.Server.Logger.log("registrar_cliente:#{datos.documento}", {:error, "ya existe"})
      {:reply, {:error, "Ya existe un cliente con ese documento"}, state}
    else
      nuevo = %{
        documento:      datos.documento,
        nombre:         datos.nombre,
        contrasena:     datos.contrasena,
        tarjeta:        datos.tarjeta,
        compras:        [],
        notificaciones: []
      }
      Azar.Shared.JsonStore.append(path, nuevo)
      Azar.Server.Logger.log("registrar_cliente:#{datos.documento}", :ok)
      {:reply, {:ok, "Cliente registrado exitosamente"}, state}
    end
  end

  # Login de cliente
  @impl true
  def handle_call({:login, documento, contrasena}, _from, state) do
    clientes = Azar.Shared.JsonStore.read_list("data/clientes.json")

    cliente = Enum.find(clientes, fn c ->
      "#{c.documento}" == "#{documento}" and c.contrasena == contrasena
    end)

    if cliente do
      Azar.Server.Logger.log("login:#{documento}", :ok)
      {:reply, {:ok, cliente}, state}
    else
      Azar.Server.Logger.log("login:#{documento}", {:error, "credenciales invalidas"})
      {:reply, {:error, "Documento o contraseña incorrectos"}, state}
    end
  end

  # Listar sorteos disponibles (no realizados)
  @impl true
  def handle_call(:sorteos_disponibles, _from, state) do
    disponibles = cargar_todos_los_sorteos()
      |> Enum.filter(&(not &1.realizado))
      |> Enum.sort_by(&(&1.fecha))
    Azar.Server.Logger.log("sorteos_disponibles", :ok)
    {:reply, {:ok, disponibles}, state}
  end

  # Comprar billete o fracción
  @impl true
  def handle_call({:comprar, sorteo_id, cliente_doc, numero, fraccion}, _from, state) do
    resultado = Azar.Server.SorteoServer.comprar(sorteo_id, cliente_doc, numero, fraccion)
    Azar.Server.Logger.log("comprar:#{sorteo_id}:#{cliente_doc}:#{numero}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Devolver billete o fracción
  @impl true
  def handle_call({:devolver, sorteo_id, cliente_doc, numero, fraccion}, _from, state) do
    resultado = Azar.Server.SorteoServer.devolver(sorteo_id, cliente_doc, numero, fraccion)
    Azar.Server.Logger.log("devolver:#{sorteo_id}:#{cliente_doc}:#{numero}", elem(resultado, 0))
    {:reply, resultado, state}
  end

  # Consultar notificaciones de un cliente
  @impl true
  def handle_call({:get_notificaciones, cliente_doc}, _from, state) do
    clientes = Azar.Shared.JsonStore.read_list("data/clientes.json")
    cliente  = Enum.find(clientes, &("#{&1.documento}" == "#{cliente_doc}"))
    notifs   = if cliente, do: Map.get(cliente, :notificaciones, []), else: []
    Azar.Server.Logger.log("get_notificaciones:#{cliente_doc}", :ok)
    {:reply, {:ok, notifs}, state}
  end

  # ============================================================
  # SOLICITUD NO RECONOCIDA
  # ============================================================

  @impl true
  def handle_call(solicitud, _from, state) do
    Azar.Server.Logger.log("solicitud_desconocida:#{inspect(solicitud)}", {:error, "no manejada"})
    {:reply, {:error, "Solicitud no reconocida"}, state}
  end

  # ------------------------------------------------------------
  # FUNCIONES PRIVADAS
  # ------------------------------------------------------------

  defp cargar_todos_los_sorteos do
    Azar.Server.SorteoSupervisor.sorteos_activos()
    |> Enum.map(fn sorteo_id ->
      case Azar.Server.SorteoServer.get_info(sorteo_id) do
        {:ok, data} -> data
        _           -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&(&1.fecha))
  end

  defp generar_billetes(cantidad, num_fracciones) do
    fracciones = Enum.to_list(1..num_fracciones)
    Enum.map(1..cantidad, fn n ->
      %{
        numero:                  String.pad_leading("#{n}", 4, "0"),
        fracciones_disponibles:  fracciones
      }
    end)
  end

end
