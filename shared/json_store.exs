# =============================================================
#  Módulo: Azar.Shared.JsonStore
#  Responsabilidad: Leer y escribir archivos JSON
#  Usado por: servidor, admin y jugador
# =============================================================

defmodule Azar.Shared.JsonStore do

  # ------------------------------------------------------------
  # LEER
  # ------------------------------------------------------------

  @doc """
  Lee un archivo JSON y lo convierte en mapa/lista Elixir.
  Las claves quedan como átomos (ej: data.nombre, data.fecha).
  Retorna nil si el archivo no existe.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.trim()
        |> Jason.decode!(keys: :atoms)

      {:error, :enoent} ->
        nil

      {:error, reason} ->
        IO.puts("  [JsonStore] Error leyendo #{path}: #{inspect(reason)}")
        nil
    end
  end

  # ------------------------------------------------------------
  # ESCRIBIR
  # ------------------------------------------------------------

  @doc """
  Serializa un mapa/lista Elixir y lo guarda como JSON formateado.
  Crea el directorio si no existe.
  """
  def write(path, data) do
    # Asegurarse de que el directorio existe
    path |> Path.dirname() |> File.mkdir_p!()

    content = Jason.encode!(data, pretty: true)
    File.write!(path, content)
  end

  # ------------------------------------------------------------
  # LISTAR ARCHIVOS
  # ------------------------------------------------------------

  @doc """
  Retorna la lista de rutas completas de todos los .json en un directorio.
  Retorna lista vacía si el directorio no existe.
  """
  def list_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort()
        |> Enum.map(&Path.join(dir, &1))

      {:error, _} ->
        []
    end
  end

  # ------------------------------------------------------------
  # LEER TODOS LOS REGISTROS DE UN DIRECTORIO
  # ------------------------------------------------------------

  @doc """
  Lee todos los JSON de un directorio y los retorna como lista de mapas.
  Útil para cargar todos los sorteos de golpe.
  """
  def read_all(dir) do
    dir
    |> list_files()
    |> Enum.map(&read/1)
    |> Enum.reject(&is_nil/1)
  end

  # ------------------------------------------------------------
  # LEER / ESCRIBIR LISTA (archivo con array JSON)
  # ------------------------------------------------------------

  @doc """
  Lee un archivo JSON que contiene una lista (array).
  Si no existe, retorna lista vacía.
  """
  def read_list(path) do
    case read(path) do
      nil  -> []
      data -> data
    end
  end

  @doc """
  Agrega un elemento a una lista guardada en un archivo JSON.
  Si el archivo no existe, lo crea con una lista de un elemento.
  """
  def append(path, elemento) do
    lista = read_list(path)
    write(path, lista ++ [elemento])
  end

  @doc """
  Actualiza un elemento de una lista JSON buscando por campo clave.
  Ejemplo: update("clientes.json", :documento, "123", nuevo_mapa)
  """
  def update_in_list(path, campo_clave, valor_clave, nuevo_elemento) do
    lista = read_list(path)

    nueva_lista =
      Enum.map(lista, fn item ->
        if Map.get(item, campo_clave) == valor_clave do
          nuevo_elemento
        else
          item
        end
      end)

    write(path, nueva_lista)
  end

  @doc """
  Elimina un elemento de una lista JSON buscando por campo clave.
  """
  def delete_from_list(path, campo_clave, valor_clave) do
    lista = read_list(path)
    nueva_lista = Enum.reject(lista, fn item ->
      Map.get(item, campo_clave) == valor_clave
    end)
    write(path, nueva_lista)
  end

end
