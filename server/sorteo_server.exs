# =============================================================
#  Módulo: Azar.Server.SorteoServer
#  Responsabilidad: GenServer individual por cada sorteo.
#  - Carga su estado desde JSON al iniciar
#  - Maneja compras, devoluciones y ejecución del sorteo
#  - Persiste cualquier cambio de vuelta al JSON
#  - Notifica a jugadores cuando el sorteo se realiza
# =============================================================

defmodule Azar.Server.SorteoServer do
  use GenServer

  # ------------------------------------------------------------
  # API PÚBLICA — llamada desde el Router
  # ------------------------------------------------------------

  def start_link(sorteo_id) do
    GenServer.start_link(__MODULE__, sorteo_id, name: via(sorteo_id))
  end

  @doc "Retorna toda la información del sorteo"
  def get_info(sorteo_id) do
    GenServer.call(via(sorteo_id), :get_info)
  end

  @doc "Agrega un premio al sorteo"
  def agregar_premio(sorteo_id, premio) do
    GenServer.call(via(sorteo_id), {:agregar_premio, premio})
  end

  @doc "Elimina un premio del sorteo (solo si no hay compras)"
  def eliminar_premio(sorteo_id, nombre_premio) do
    GenServer.call(via(sorteo_id), {:eliminar_premio, nombre_premio})
  end

  @doc "Compra un billete completo o fracción para un cliente"
  def comprar(sorteo_id, cliente_doc, numero_billete, fraccion \\ nil) do
    GenServer.call(via(sorteo_id), {:comprar, cliente_doc, numero_billete, fraccion})
  end

  @doc "Devuelve un billete completo o fracción (solo si el sorteo no se ha realizado)"
  def devolver(sorteo_id, cliente_doc, numero_billete, fraccion \\ nil) do
    GenServer.call(via(sorteo_id), {:devolver, cliente_doc, numero_billete, fraccion})
  end

  @doc "Ejecuta el sorteo: asigna ganadores aleatorios y notifica jugadores"
  def realizar(sorteo_id) do
    GenServer.call(via(sorteo_id), :realizar)
  end

  @doc "Retorna las compras de un sorteo agrupadas por cliente"
  def get_clientes(sorteo_id) do
    GenServer.call(via(sorteo_id), :get_clientes)
  end

  @doc "Retorna los ingresos totales del sorteo"
  def get_ingresos(sorteo_id) do
    GenServer.call(via(sorteo_id), :get_ingresos)
  end

  # ------------------------------------------------------------
  # CALLBACKS GENSERVER
  # ------------------------------------------------------------

  @impl true
  def init(sorteo_id) do
    path = "data/sorteos/#{sorteo_id}.json"

    case Azar.Shared.JsonStore.read(path) do
      nil ->
        {:stop, "No se encontró el archivo #{path}"}

      data ->
        Azar.Server.Logger.info("SorteoServer iniciado: #{data.nombre} (#{sorteo_id})")
        {:ok, %{id: sorteo_id, path: path, data: data}}
    end
  end

  # --- Consultar info completa ---
  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, {:ok, state.data}, state}
  end

  # --- Agregar premio ---
  @impl true
  def handle_call({:agregar_premio, premio}, _from, state) do
    premios_actuales = state.data.premios || []
    nueva_data = %{state.data | premios: premios_actuales ++ [premio]}
    nuevo_state = persistir(state, nueva_data)
    {:reply, {:ok, "Premio '#{premio.nombre}' agregado"}, nuevo_state}
  end

  # --- Eliminar premio ---
  @impl true
  def handle_call({:eliminar_premio, nombre_premio}, _from, state) do
    compras = state.data.compras || []

    if length(compras) > 0 do
      {:reply, {:error, "No se puede eliminar: el sorteo ya tiene clientes"}, state}
    else
      nuevos_premios = Enum.reject(state.data.premios, &(&1.nombre == nombre_premio))
      nueva_data = %{state.data | premios: nuevos_premios}
      nuevo_state = persistir(state, nueva_data)
      {:reply, {:ok, "Premio eliminado"}, nuevo_state}
    end
  end

  # --- Comprar billete o fracción ---
  @impl true
  def handle_call({:comprar, cliente_doc, numero_billete, fraccion}, _from, state) do
    cond do
      state.data.realizado ->
        {:reply, {:error, "El sorteo ya fue realizado"}, state}

      fraccion == nil ->
        comprar_billete_completo(state, cliente_doc, numero_billete)

      true ->
        comprar_fraccion(state, cliente_doc, numero_billete, fraccion)
    end
  end

  # --- Devolver billete o fracción ---
  @impl true
  def handle_call({:devolver, cliente_doc, numero_billete, fraccion}, _from, state) do
    if state.data.realizado do
      {:reply, {:error, "No se puede devolver: el sorteo ya fue realizado"}, state}
    else
      devolver_compra(state, cliente_doc, numero_billete, fraccion)
    end
  end

  # --- Realizar el sorteo ---
  @impl true
  def handle_call(:realizar, _from, state) do
    if state.data.realizado do
      {:reply, {:error, "El sorteo ya fue realizado anteriormente"}, state}
    else
      ejecutar_sorteo(state)
    end
  end

  # --- Consultar clientes ---
  @impl true
  def handle_call(:get_clientes, _from, state) do
    compras = state.data.compras || []

    # Separar compradores de billete completo vs fracción
    completos  = Enum.filter(compras, &(&1.fraccion == nil))
    fracciones = Enum.filter(compras, &(&1.fraccion != nil))

    resultado = %{
      completos:  completos  |> Enum.sort_by(&(&1.cliente_nombre)),
      fracciones: fracciones |> Enum.sort_by(&(&1.cliente_nombre))
    }

    {:reply, {:ok, resultado}, state}
  end

  # --- Consultar ingresos ---
  @impl true
  def handle_call(:get_ingresos, _from, state) do
    compras = state.data.compras || []
    valor_fraccion = state.data.valor_billete / state.data.num_fracciones

    total = Enum.reduce(compras, 0, fn compra, acc ->
      if compra.fraccion == nil do
        acc + state.data.valor_billete
      else
        acc + valor_fraccion
      end
    end)

    {:reply, {:ok, total}, state}
  end

  # ------------------------------------------------------------
  # FUNCIONES PRIVADAS — lógica interna
  # ------------------------------------------------------------

  # Comprar billete completo
  defp comprar_billete_completo(state, cliente_doc, numero_billete) do
    billete = encontrar_billete(state.data.billetes, numero_billete)

    cond do
      billete == nil ->
        {{:reply, {:error, "Número de billete no existe"}, state}}

      billete.fracciones_disponibles != Enum.to_list(1..state.data.num_fracciones) ->
        {:reply, {:error, "El billete ya tiene fracciones vendidas"}, state}

      true ->
        # Marcar todas las fracciones como vendidas
        nuevos_billetes = actualizar_billete(state.data.billetes, numero_billete, [])

        nueva_compra = %{
          cliente_doc:    cliente_doc,
          cliente_nombre: obtener_nombre_cliente(cliente_doc),
          numero_billete: numero_billete,
          fraccion:       nil,
          valor:          state.data.valor_billete
        }

        compras_actuales = state.data.compras || []
        nueva_data = %{state.data |
          billetes: nuevos_billetes,
          compras:  compras_actuales ++ [nueva_compra]
        }

        nuevo_state = persistir(state, nueva_data)
        {:reply, {:ok, "Billete #{numero_billete} comprado exitosamente"}, nuevo_state}
    end
  end

  # Comprar fracción
  defp comprar_fraccion(state, cliente_doc, numero_billete, fraccion) do
    billete = encontrar_billete(state.data.billetes, numero_billete)
    fraccion_int = String.to_integer("#{fraccion}")

    cond do
      billete == nil ->
        {:reply, {:error, "Número de billete no existe"}, state}

      fraccion_int not in billete.fracciones_disponibles ->
        {:reply, {:error, "Fracción #{fraccion} no disponible"}, state}

      true ->
        nuevas_fracciones = List.delete(billete.fracciones_disponibles, fraccion_int)
        nuevos_billetes = actualizar_billete(state.data.billetes, numero_billete, nuevas_fracciones)

        valor_fraccion = state.data.valor_billete / state.data.num_fracciones

        nueva_compra = %{
          cliente_doc:    cliente_doc,
          cliente_nombre: obtener_nombre_cliente(cliente_doc),
          numero_billete: numero_billete,
          fraccion:       fraccion_int,
          valor:          valor_fraccion
        }

        compras_actuales = state.data.compras || []
        nueva_data = %{state.data |
          billetes: nuevos_billetes,
          compras:  compras_actuales ++ [nueva_compra]
        }

        nuevo_state = persistir(state, nueva_data)
        {:reply, {:ok, "Fracción #{fraccion} del billete #{numero_billete} comprada"}, nuevo_state}
    end
  end

  # Devolver compra
  defp devolver_compra(state, cliente_doc, numero_billete, fraccion) do
    compras = state.data.compras || []
    fraccion_int = if fraccion, do: String.to_integer("#{fraccion}"), else: nil

    compra = Enum.find(compras, fn c ->
      c.cliente_doc == cliente_doc and
      c.numero_billete == numero_billete and
      c.fraccion == fraccion_int
    end)

    if compra == nil do
      {:reply, {:error, "No se encontró la compra para devolver"}, state}
    else
      # Eliminar la compra
      nuevas_compras = List.delete(compras, compra)

      # Restaurar disponibilidad del billete
      billete = encontrar_billete(state.data.billetes, numero_billete)
      fracciones_restauradas =
        if fraccion_int == nil do
          Enum.to_list(1..state.data.num_fracciones)
        else
          Enum.sort([fraccion_int | billete.fracciones_disponibles])
        end

      nuevos_billetes = actualizar_billete(state.data.billetes, numero_billete, fracciones_restauradas)

      nueva_data = %{state.data | compras: nuevas_compras, billetes: nuevos_billetes}
      nuevo_state = persistir(state, nueva_data)

      {:reply, {:ok, "Devolución realizada correctamente"}, nuevo_state}
    end
  end

  # Ejecutar el sorteo y notificar ganadores
  defp ejecutar_sorteo(state) do
    billetes_vendidos = state.data.billetes
      |> Enum.filter(fn b ->
        b.fracciones_disponibles != Enum.to_list(1..state.data.num_fracciones)
      end)

    if length(billetes_vendidos) == 0 do
      {:reply, {:error, "No hay billetes vendidos para realizar el sorteo"}, state}
    else
      total_billetes = length(state.data.billetes)
      premios = state.data.premios || []

      # Asignar un número ganador aleatorio por cada premio
      ganadores = Enum.map(premios, fn premio ->
        idx = :rand.uniform(total_billetes) - 1
        numero_ganador = Enum.at(state.data.billetes, idx).numero
        %{premio: premio.nombre, valor: premio.valor, numero: numero_ganador}
      end)

      nueva_data = %{state.data | realizado: true, ganadores: ganadores}
      nuevo_state = persistir(state, nueva_data)

      # Notificar a los jugadores ganadores
      notificar_ganadores(state.data.compras || [], ganadores, state.data.nombre)

      {:reply, {:ok, ganadores}, nuevo_state}
    end
  end

  # Notificar a jugadores cuyo número ganó
  defp notificar_ganadores(compras, ganadores, nombre_sorteo) do
    Enum.each(ganadores, fn ganador ->
      # Buscar compradores del número ganador
      compradores = Enum.filter(compras, &(&1.numero_billete == ganador.numero))

      Enum.each(compradores, fn compra ->
        mensaje = "Ganaste en " <> nombre_sorteo <> "! " <>
                  "Premio: " <> ganador.premio <> " - " <>
                  "Numero: " <> ganador.numero <> " - " <>
                  "Valor: $" <> to_string(ganador.valor)

        # Enviar notificacion al nodo jugador
        Enum.each(Node.list(), fn nodo ->
          if String.starts_with?("#{nodo}", "player") do
            Node.spawn(nodo, Azar.Player.Notificaciones, :recibir, [compra.cliente_doc, mensaje])
          end
        end)

        # Guardar notificacion en el JSON del cliente
        guardar_notificacion_cliente(compra.cliente_doc, mensaje)
      end)
    end)
  end

  # Guardar notificación en el archivo de clientes
  defp guardar_notificacion_cliente(cliente_doc, mensaje) do
    path = "data/clientes.json"
    clientes = Azar.Shared.JsonStore.read_list(path)

    nuevos_clientes = Enum.map(clientes, fn c ->
      if "#{c.documento}" == "#{cliente_doc}" do
        notifs = Map.get(c, :notificaciones, [])
        %{c | notificaciones: notifs ++ [mensaje]}
      else
        c
      end
    end)

    Azar.Shared.JsonStore.write(path, nuevos_clientes)
  end

  # Encontrar un billete por número
  defp encontrar_billete(billetes, numero) do
    Enum.find(billetes, &("#{&1.numero}" == "#{numero}"))
  end

  # Actualizar fracciones disponibles de un billete
  defp actualizar_billete(billetes, numero, nuevas_fracciones) do
    Enum.map(billetes, fn b ->
      if "#{b.numero}" == "#{numero}" do
        %{b | fracciones_disponibles: nuevas_fracciones}
      else
        b
      end
    end)
  end

  # Obtener nombre del cliente desde el JSON
  defp obtener_nombre_cliente(cliente_doc) do
    clientes = Azar.Shared.JsonStore.read_list("data/clientes.json")
    cliente = Enum.find(clientes, &("#{&1.documento}" == "#{cliente_doc}"))
    if cliente, do: cliente.nombre, else: "#{cliente_doc}"
  end

  # Persistir estado en memoria y en JSON
  defp persistir(state, nueva_data) do
    Azar.Shared.JsonStore.write(state.path, nueva_data)
    %{state | data: nueva_data}
  end

  # Registro global del proceso por sorteo_id
  defp via(sorteo_id) do
    {:via, :global, {__MODULE__, sorteo_id}}
  end

end
