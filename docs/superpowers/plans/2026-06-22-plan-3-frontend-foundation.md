# Frontend Foundation — Plan 3

> **Para agentes:** usar superpowers:executing-plans o superpowers:subagent-driven-development.

**Goal:** Scaffoldear el proyecto React + Vite, conectarlo al backend con axios + JWT, implementar login funcional y el layout principal con sidebar. Al final del plan el desarrollador puede abrir `http://localhost:5173`, iniciar sesión y ver el dashboard.

**Architecture:** SPA React 18 + Vite 5, JavaScript (sin TypeScript). Zustand para estado global de auth. TanStack Query para datos del servidor. React Router v6 para navegación con rutas protegidas. Tailwind CSS para estilos.

**Tech Stack:** React 18, Vite 5, Tailwind CSS 3, Zustand 4, TanStack Query 5, React Router DOM 6, Axios, vite-plugin-pwa

## Global Constraints

- Carpeta raíz del frontend: `RESTAURANTE/frontend/` (hermana de `backend/`)
- API base URL: `http://localhost:3001/api/v1` (configurable via `VITE_API_URL`)
- Auth: JWT access token (header `Authorization: Bearer <token>`) + refresh token
- Respuesta exitosa de API: `{ ok: true, datos: ... }`
- Respuesta de error de API: `{ ok: false, mensaje: "..." }`
- Login endpoint: `POST /api/v1/auth/login` body: `{ email, contrasena }`
- Refresh endpoint: `POST /api/v1/auth/refresh` body: `{ refreshToken }`
- Login response datos: `{ token, refreshToken, usuario: { id, nombre, email, rol: { nombre, permisos: [{ modulo, accion }] } } }`
- Permisos formato: `modulo.accion` (ej: `ventas.ver`, `caja.abrir`)
- Token y refreshToken se persisten en localStorage via Zustand persist
- Idioma de la UI: español
- Color primario: azul (`blue-600` Tailwind)
- JavaScript solamente — sin TypeScript
- Sin librerías de componentes externas (solo Tailwind)

---

### Task 1: Scaffold Vite + React + Tailwind + dependencias

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/vite.config.js`
- Create: `frontend/index.html`
- Create: `frontend/tailwind.config.js`
- Create: `frontend/postcss.config.js`
- Create: `frontend/.env`
- Create: `frontend/src/main.jsx`
- Create: `frontend/src/App.jsx`
- Create: `frontend/src/index.css`

**Interfaces:**
- Produces: proyecto corriendo en `http://localhost:5173` con Tailwind activo

- [ ] **Step 1: Crear la carpeta frontend e instalar dependencias**

Desde `RESTAURANTE/` (raíz del workspace):

```bash
mkdir frontend
cd frontend
npm create vite@latest . -- --template react
```

Cuando pregunte si sobreescribir, responder `y`. Luego instalar todo:

```bash
npm install
npm install axios @tanstack/react-query zustand react-router-dom
npm install -D tailwindcss postcss autoprefixer vite-plugin-pwa
npx tailwindcss init -p
```

- [ ] **Step 2: Configurar Tailwind**

Reemplazar `frontend/tailwind.config.js`:

```js
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
};
```

- [ ] **Step 3: Agregar directivas Tailwind al CSS global**

Reemplazar `frontend/src/index.css` con:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

- [ ] **Step 4: Configurar Vite con PWA**

Reemplazar `frontend/vite.config.js`:

```js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'Sistema Restaurante',
        short_name: 'Restaurante',
        theme_color: '#1d4ed8',
        icons: [{ src: '/favicon.ico', sizes: '64x64', type: 'image/x-icon' }],
      },
    }),
  ],
  server: {
    port: 5173,
  },
});
```

- [ ] **Step 5: Crear archivo .env**

Crear `frontend/.env`:

```
VITE_API_URL=http://localhost:3001/api/v1
```

- [ ] **Step 6: Limpiar App.jsx a un mínimo**

Reemplazar `frontend/src/App.jsx`:

```jsx
export default function App() {
  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <h1 className="text-3xl font-bold text-blue-600">Sistema Restaurante</h1>
    </div>
  );
}
```

Reemplazar `frontend/src/main.jsx`:

```jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

- [ ] **Step 7: Verificar que arranca**

```bash
cd frontend
npm run dev
```

Abrir `http://localhost:5173` — debe verse texto azul "Sistema Restaurante" sobre fondo gris.

- [ ] **Step 8: Commit**

```bash
cd frontend
git add -A
git commit -m "feat: scaffold frontend Vite + React + Tailwind"
```

---

### Task 2: Zustand auth store

**Files:**
- Create: `frontend/src/store/authStore.js`
- Create: `frontend/src/hooks/useAuth.js`
- Create: `frontend/src/hooks/usePermisos.js`

**Interfaces:**
- Produces: `useAuthStore` con `{ token, refreshToken, usuario, setAuth, setToken, logout }`
- Produces: `useAuth()` → `{ usuario, token, estaAutenticado, logout }`
- Produces: `usePermisos()` → `{ tienePermiso(modulo, accion) }`

- [ ] **Step 1: Crear el auth store**

Crear `frontend/src/store/authStore.js`:

```js
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export const useAuthStore = create(
  persist(
    (set) => ({
      token: null,
      refreshToken: null,
      usuario: null,
      setAuth: ({ token, refreshToken, usuario }) =>
        set({ token, refreshToken, usuario }),
      setToken: (token) => set({ token }),
      logout: () => set({ token: null, refreshToken: null, usuario: null }),
    }),
    { name: 'auth' }
  )
);
```

- [ ] **Step 2: Crear useAuth hook**

Crear `frontend/src/hooks/useAuth.js`:

```js
import { useAuthStore } from '../store/authStore';

export function useAuth() {
  const token = useAuthStore((s) => s.token);
  const usuario = useAuthStore((s) => s.usuario);
  const logout = useAuthStore((s) => s.logout);
  return { usuario, token, estaAutenticado: !!token, logout };
}
```

- [ ] **Step 3: Crear usePermisos hook**

Crear `frontend/src/hooks/usePermisos.js`:

```js
import { useAuthStore } from '../store/authStore';

export function usePermisos() {
  const usuario = useAuthStore((s) => s.usuario);
  const permisos = usuario?.rol?.permisos ?? [];

  function tienePermiso(modulo, accion) {
    return permisos.some((p) => p.modulo === modulo && p.accion === accion);
  }

  return { tienePermiso };
}
```

- [ ] **Step 4: Verificar manualmente en el navegador**

En `App.jsx`, agregar temporalmente para verificar:

```jsx
import { useAuthStore } from './store/authStore';

export default function App() {
  const { setAuth, logout, usuario } = useAuthStore();

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">Auth Store Test</h1>
      <p>Usuario: {usuario?.nombre ?? 'no autenticado'}</p>
      <button
        className="bg-blue-600 text-white px-4 py-2 rounded"
        onClick={() => setAuth({ token: 'test', refreshToken: 'rf', usuario: { nombre: 'Admin' } })}
      >
        Simular login
      </button>
      <button
        className="bg-red-500 text-white px-4 py-2 rounded ml-2"
        onClick={logout}
      >
        Logout
      </button>
    </div>
  );
}
```

Abrir `http://localhost:5173`, hacer click en "Simular login" → debe aparecer "Admin". Recargar página → debe mantenerse "Admin" (localStorage persist). Click logout → debe volver a "no autenticado".

- [ ] **Step 5: Revertir App.jsx al mínimo**

```jsx
export default function App() {
  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <h1 className="text-3xl font-bold text-blue-600">Sistema Restaurante</h1>
    </div>
  );
}
```

- [ ] **Step 6: Commit**

```bash
git add src/store/authStore.js src/hooks/useAuth.js src/hooks/usePermisos.js src/App.jsx
git commit -m "feat: zustand auth store + useAuth + usePermisos hooks"
```

---

### Task 3: Axios + cliente API + interceptores JWT

**Files:**
- Create: `frontend/src/api/cliente.js`

**Interfaces:**
- Consumes: `useAuthStore.getState()` para leer/escribir token sin hooks
- Produces: instancia axios `api` con baseURL, request interceptor (Bearer token), response interceptor (refresh automático en 401)

- [ ] **Step 1: Crear el cliente axios**

Crear `frontend/src/api/cliente.js`:

```js
import axios from 'axios';
import { useAuthStore } from '../store/authStore';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://localhost:3001/api/v1',
});

// Adjuntar token a cada request
api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Refresh automático en 401
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config;
    if (error.response?.status === 401 && !config._reintentado) {
      config._reintentado = true;
      try {
        const refreshToken = useAuthStore.getState().refreshToken;
        const { data } = await axios.post(
          `${api.defaults.baseURL}/auth/refresh`,
          { refreshToken }
        );
        useAuthStore.getState().setToken(data.datos.token);
        config.headers.Authorization = `Bearer ${data.datos.token}`;
        return api(config);
      } catch {
        useAuthStore.getState().logout();
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;
```

- [ ] **Step 2: Verificar que el cliente conecta al backend**

Asegurarse de que el backend esté corriendo en puerto 3001. En `App.jsx` agregar temporalmente:

```jsx
import { useEffect } from 'react';
import api from './api/cliente';

export default function App() {
  useEffect(() => {
    api.post('/auth/login', { email: 'admin@restaurante.com', contrasena: 'admin123' })
      .then(({ data }) => console.log('Login OK:', data.datos.usuario.nombre))
      .catch((err) => console.error('Error:', err.response?.data));
  }, []);

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <h1 className="text-3xl font-bold text-blue-600">Verificando conexión...</h1>
    </div>
  );
}
```

Abrir `http://localhost:5173`, abrir la consola del navegador (F12). Debe aparecer `Login OK: Admin` (o el nombre del usuario admin). Si aparece error de CORS, verificar que el backend tiene `CORS_ORIGIN=http://localhost:5173` en su `.env`.

- [ ] **Step 3: Revertir App.jsx**

```jsx
export default function App() {
  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <h1 className="text-3xl font-bold text-blue-600">Sistema Restaurante</h1>
    </div>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add src/api/cliente.js src/App.jsx
git commit -m "feat: axios cliente API con interceptores JWT y refresh automático"
```

---

### Task 4: React Router + rutas protegidas + página Login

**Files:**
- Create: `frontend/src/router/RutaProtegida.jsx`
- Create: `frontend/src/router/index.jsx`
- Create: `frontend/src/pages/auth/LoginPage.jsx`
- Create: `frontend/src/pages/Dashboard.jsx`
- Modify: `frontend/src/App.jsx`

**Interfaces:**
- Consumes: `useAuthStore` (token para guard), `api` (POST /auth/login)
- Produces: `/login` → LoginPage, `/` → Dashboard (solo si autenticado, sino redirect a `/login`)

- [ ] **Step 1: Crear RutaProtegida**

Crear `frontend/src/router/RutaProtegida.jsx`:

```jsx
import { Navigate, Outlet } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

export default function RutaProtegida() {
  const token = useAuthStore((s) => s.token);
  if (!token) return <Navigate to="/login" replace />;
  return <Outlet />;
}
```

- [ ] **Step 2: Crear página Dashboard placeholder**

Crear `frontend/src/pages/Dashboard.jsx`:

```jsx
import { useAuth } from '../hooks/useAuth';

export default function Dashboard() {
  const { usuario } = useAuth();
  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800">
        Bienvenido, {usuario?.nombre}
      </h1>
      <p className="text-gray-500 mt-1">Panel principal del restaurante</p>
    </div>
  );
}
```

- [ ] **Step 3: Crear LoginPage**

Crear `frontend/src/pages/auth/LoginPage.jsx`:

```jsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../../api/cliente';
import { useAuthStore } from '../../store/authStore';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [contrasena, setContrasena] = useState('');
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(false);
  const setAuth = useAuthStore((s) => s.setAuth);
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setCargando(true);
    try {
      const { data } = await api.post('/auth/login', { email, contrasena });
      setAuth(data.datos);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.mensaje ?? 'Error al iniciar sesión');
    } finally {
      setCargando(false);
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center px-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Restaurante</h1>
          <p className="text-gray-500 mt-1">Sistema de Gestión</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Correo electrónico
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              placeholder="admin@restaurante.com"
              className="w-full border border-gray-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Contraseña
            </label>
            <input
              type="password"
              value={contrasena}
              onChange={(e) => setContrasena(e.target.value)}
              required
              placeholder="••••••••"
              className="w-full border border-gray-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg px-3 py-2">
              <p className="text-red-600 text-sm">{error}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={cargando}
            className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded-lg py-2.5 font-medium transition-colors"
          >
            {cargando ? 'Iniciando sesión...' : 'Iniciar Sesión'}
          </button>
        </form>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Crear el router**

Crear `frontend/src/router/index.jsx`:

```jsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import RutaProtegida from './RutaProtegida';
import LoginPage from '../pages/auth/LoginPage';
import Dashboard from '../pages/Dashboard';

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  {
    element: <RutaProtegida />,
    children: [
      { path: '/', element: <Dashboard /> },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]);
```

- [ ] **Step 5: Conectar router y TanStack Query en App.jsx**

Reemplazar `frontend/src/App.jsx`:

```jsx
import { RouterProvider } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { router } from './router/index.jsx';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, staleTime: 30_000 },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 6: Verificar flujo completo de autenticación**

Con el backend corriendo:

1. Abrir `http://localhost:5173` → debe redirigir automáticamente a `/login`
2. Ingresar `admin@restaurante.com` / `admin123` → debe redirigir a `/` y mostrar "Bienvenido, Admin"
3. Recargar la página → debe mantenerse en `/` (token persistido)
4. Abrir DevTools → Application → Local Storage → ver clave `auth` con token
5. Modificar manualmente el token en localStorage → recargar → debe redirigir a `/login`

- [ ] **Step 7: Commit**

```bash
git add src/router/ src/pages/ src/App.jsx
git commit -m "feat: router con rutas protegidas, login page funcional"
```

---

### Task 5: Layout principal (Sidebar + Topbar)

**Files:**
- Create: `frontend/src/components/layout/Layout.jsx`
- Create: `frontend/src/components/layout/Sidebar.jsx`
- Create: `frontend/src/components/layout/Topbar.jsx`
- Modify: `frontend/src/router/index.jsx`

**Interfaces:**
- Consumes: `useAuth()` para nombre de usuario y logout, `usePermisos()` para mostrar/ocultar items del sidebar
- Produces: layout con sidebar izquierdo (ancho fijo 240px, fondo oscuro) + topbar superior + área principal con `<Outlet />`

- [ ] **Step 1: Crear Sidebar**

Crear `frontend/src/components/layout/Sidebar.jsx`:

```jsx
import { NavLink } from 'react-router-dom';
import { usePermisos } from '../../hooks/usePermisos';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', icono: '🏠', siempre: true },
  { to: '/ventas', label: 'Ventas / POS', icono: '🍽️', modulo: 'ventas', accion: 'ver' },
  { to: '/caja', label: 'Caja', icono: '💰', modulo: 'caja', accion: 'ver' },
  { to: '/libro-caja', label: 'Libro Caja', icono: '📒', modulo: 'libro_caja', accion: 'ver' },
  { to: '/productos', label: 'Productos', icono: '🛒', modulo: 'inventario', accion: 'ver' },
  { to: '/inventario', label: 'Inventario', icono: '📦', modulo: 'inventario', accion: 'ajustar' },
  { to: '/compras', label: 'Compras', icono: '🚚', modulo: 'compras', accion: 'ver' },
  { to: '/clientes', label: 'Clientes', icono: '👥', modulo: 'ventas', accion: 'ver' },
  { to: '/reservaciones', label: 'Reservaciones', icono: '📅', modulo: 'ventas', accion: 'ver' },
  { to: '/usuarios', label: 'Usuarios', icono: '👤', modulo: 'usuarios', accion: 'ver' },
  { to: '/roles', label: 'Roles', icono: '🔑', modulo: 'roles', accion: 'ver' },
  { to: '/configuracion', label: 'Configuración', icono: '⚙️', modulo: 'configuracion', accion: 'ver' },
];

export default function Sidebar() {
  const { tienePermiso } = usePermisos();

  const itemsVisibles = NAV_ITEMS.filter(
    (item) => item.siempre || tienePermiso(item.modulo, item.accion)
  );

  return (
    <aside className="w-60 bg-gray-900 text-white flex flex-col shrink-0">
      {/* Logo */}
      <div className="px-6 py-5 border-b border-gray-700">
        <h2 className="text-lg font-bold text-white">Restaurante</h2>
        <p className="text-xs text-gray-400">Sistema de Gestión</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-4 px-3 space-y-0.5">
        {itemsVisibles.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                isActive
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-300 hover:bg-gray-700 hover:text-white'
              }`
            }
          >
            <span className="text-base">{item.icono}</span>
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 2: Crear Topbar**

Crear `frontend/src/components/layout/Topbar.jsx`:

```jsx
import { useAuth } from '../../hooks/useAuth';
import { useNavigate } from 'react-router-dom';
import api from '../../api/cliente';

export default function Topbar() {
  const { usuario, logout } = useAuth();
  const navigate = useNavigate();

  async function handleLogout() {
    try {
      await api.post('/auth/logout');
    } catch {
      // ignorar errores de red al cerrar sesión
    }
    logout();
    navigate('/login');
  }

  return (
    <header className="h-14 bg-white border-b border-gray-200 flex items-center justify-between px-6 shrink-0">
      <div />
      <div className="flex items-center gap-4">
        <div className="text-right">
          <p className="text-sm font-medium text-gray-800">{usuario?.nombre}</p>
          <p className="text-xs text-gray-500">{usuario?.rol?.nombre}</p>
        </div>
        <button
          onClick={handleLogout}
          className="text-sm text-gray-500 hover:text-red-600 transition-colors px-2 py-1 rounded"
        >
          Salir
        </button>
      </div>
    </header>
  );
}
```

- [ ] **Step 3: Crear Layout**

Crear `frontend/src/components/layout/Layout.jsx`:

```jsx
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';

export default function Layout() {
  return (
    <div className="flex h-screen bg-gray-100 overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Integrar Layout en el router**

Modificar `frontend/src/router/index.jsx`:

```jsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import RutaProtegida from './RutaProtegida';
import Layout from '../components/layout/Layout';
import LoginPage from '../pages/auth/LoginPage';
import Dashboard from '../pages/Dashboard';

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  {
    element: <RutaProtegida />,
    children: [
      {
        element: <Layout />,
        children: [
          { path: '/', element: <Dashboard /> },
        ],
      },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]);
```

- [ ] **Step 5: Verificar layout completo**

Con el backend corriendo:

1. Ir a `http://localhost:5173/login` → ingresar credenciales admin
2. Verificar que se ve el sidebar oscuro a la izquierda con todos los items de nav
3. Verificar que el topbar muestra el nombre del usuario y su rol
4. Verificar que el link "Dashboard" está resaltado en azul
5. Hacer click en "Salir" → debe redirigir a `/login` y limpiar el localStorage

- [ ] **Step 6: Commit**

```bash
git add src/components/ src/router/index.jsx
git commit -m "feat: layout principal con sidebar y topbar"
```
