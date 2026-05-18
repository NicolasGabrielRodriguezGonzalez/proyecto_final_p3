# AZAR S.A. - Sistema Distribuido de Sorteos
### Programación III - Elixir

---

## Estructura del proyecto

```
azar_system/
├── server.exs                  ← Punto de entrada: Servidor Central
├── admin.exs                   ← Punto de entrada: Administrador
├── player.exs                  ← Punto de entrada: Jugador
│
├── server/
│   ├── router.exs              ← Recibe y redirige todas las solicitudes
│   ├── logger.exs              ← Bitácora (pantalla + archivo)
│   ├── sorteo_supervisor.exs   ← Inicia un GenServer por cada sorteo
│   └── sorteo_server.exs       ← GenServer individual por sorteo
│
├── admin/
│   ├── cli.exs                 ← Menú principal administrador
│   ├── sorteos_menu.exs        ← Gestión de sorteos
│   └── premios_menu.exs        ← Gestión de premios
│
├── player/
│   ├── cli.exs                 ← Menú principal jugador
│   ├── auth.exs                ← Registro y login
│   ├── compras_menu.exs        ← Comprar / devolver billetes
│   └── notificaciones.exs      ← Recibir mensajes del servidor
│
├── shared/
│   └── json_store.exs          ← Utilidad para leer/escribir JSON
│
├── data/
│   ├── sorteos/
│   │   ├── sorteo_001.json     ← Datos de prueba
│   │   └── sorteo_002.json
│   └── clientes.json
│
└── log/
    └── bitacora.txt
```

---

## Cómo ejecutar

Requiere Elixir instalado. Abrir **3 terminales** en la carpeta `azar_system/`:

```bash
# Terminal 1 - Servidor (iniciar primero)
elixir --name server@localhost --cookie azar server.exs

# Terminal 2 - Administrador
elixir --name admin@localhost --cookie azar admin.exs

# Terminal 3 - Jugador
elixir --name player@localhost --cookie azar player.exs
```

---

## Tecnologías usadas

- **Elixir / OTP**: GenServer, Supervisor, Node
- **:global**: Registro global de procesos entre nodos
- **Jason**: Parsing de JSON
- **Distributed Erlang**: Comunicación entre las 3 apps
