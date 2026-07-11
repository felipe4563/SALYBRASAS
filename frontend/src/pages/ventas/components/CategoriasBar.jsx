import { useEffect, useRef, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export default function CategoriasBar({ categorias, categoriaActiva, onSeleccionar }) {
  const scrollRef = useRef(null);
  const [puedeIzq, setPuedeIzq] = useState(false);
  const [puedeDer, setPuedeDer] = useState(false);

  function actualizarScroll() {
    const el = scrollRef.current;
    if (!el) return;
    setPuedeIzq(el.scrollLeft > 4);
    setPuedeDer(el.scrollLeft + el.clientWidth < el.scrollWidth - 4);
  }

  useEffect(() => {
    actualizarScroll();
    window.addEventListener('resize', actualizarScroll);
    return () => window.removeEventListener('resize', actualizarScroll);
  }, [categorias]);

  function desplazar(direccion) {
    scrollRef.current?.scrollBy({ left: direccion * 180, behavior: 'smooth' });
  }

  const items = [{ id: null, nombre: 'Todos' }, ...categorias];

  return (
    <div className="relative shrink-0">
      {puedeIzq && (
        <div className="pointer-events-none absolute left-0 top-0 bottom-0 w-10 z-10 bg-gradient-to-r from-gray-100 dark:from-gray-950 to-transparent" />
      )}
      {puedeIzq && (
        <button
          type="button"
          onClick={() => desplazar(-1)}
          aria-label="Desplazar categorías a la izquierda"
          className="hidden sm:flex absolute left-0 top-1/2 -translate-y-1/2 z-20 w-7 h-7 items-center justify-center rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-sm text-gray-500 hover:text-gray-800 dark:hover:text-gray-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
      )}

      <div
        ref={scrollRef}
        onScroll={actualizarScroll}
        className="flex gap-2 overflow-x-auto scroll-smooth snap-x snap-proximity scrollbar-hide py-0.5"
      >
        {items.map((cat) => {
          const activa = categoriaActiva === cat.id;
          return (
            <button
              key={cat.id ?? 'todos'}
              type="button"
              onClick={() => onSeleccionar(cat.id)}
              className={`shrink-0 snap-start px-4 py-2 rounded-full text-sm font-semibold transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-950 ${
                activa
                  ? 'bg-blue-600 text-white shadow-sm shadow-blue-600/30'
                  : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-blue-300 dark:hover:border-blue-600 hover:text-gray-900 dark:hover:text-gray-200'
              }`}
            >
              {cat.nombre}
            </button>
          );
        })}
      </div>

      {puedeDer && (
        <div className="pointer-events-none absolute right-0 top-0 bottom-0 w-10 z-10 bg-gradient-to-l from-gray-100 dark:from-gray-950 to-transparent" />
      )}
      {puedeDer && (
        <button
          type="button"
          onClick={() => desplazar(1)}
          aria-label="Desplazar categorías a la derecha"
          className="hidden sm:flex absolute right-0 top-1/2 -translate-y-1/2 z-20 w-7 h-7 items-center justify-center rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-sm text-gray-500 hover:text-gray-800 dark:hover:text-gray-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
        >
          <ChevronRight className="w-4 h-4" />
        </button>
      )}
    </div>
  );
}
