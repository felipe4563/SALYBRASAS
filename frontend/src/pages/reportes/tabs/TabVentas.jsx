import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Download, ShoppingCart, TrendingUp, DollarSign, BarChart2 } from 'lucide-react';
import { getReporteVentas } from '../../../api/reportes';
import { useAuth } from '../../../hooks/useAuth';
import { exportarPDF } from '../utils/exportarPDF';
import { FiltroFechas, StatCard, BadgeTipo, Skeleton, bs, fecha, fechaHora, hoy, inicioMes } from '../shared';

export default function TabVentas({ empresa }) {
  const { usuario } = useAuth();
  const [desde, setDesde] = useState(inicioMes());
  const [hasta, setHasta] = useState(hoy());
  const [filtroCajero, setFiltroCajero] = useState('todos');
  const [params, setParams] = useState({ desde: inicioMes(), hasta: hoy() });

  const { data = [], isLoading } = useQuery({
    queryKey: ['reporte-ventas', params],
    queryFn: () => getReporteVentas(params),
  });

  const cajeros = useMemo(() => {
    const unicos = new Map();
    data.forEach(v => {
      if (v.usuario?.id) unicos.set(v.usuario.id, v.usuario.nombre);
    });
    return Array.from(unicos.entries()).map(([id, nombre]) => ({ id, nombre }));
  }, [data]);

  const filtrado = useMemo(() =>
    filtroCajero === 'todos' ? data : data.filter(v => String(v.usuario?.id) === filtroCajero),
    [data, filtroCajero]
  );

  const stats = useMemo(() => {
    const total    = filtrado.reduce((s, v) => s + parseFloat(v.total || 0), 0);
    const efectivo = filtrado.filter(v => v.metodo_pago === 'efectivo').reduce((s, v) => s + parseFloat(v.total || 0), 0);
    const qr       = filtrado.filter(v => v.metodo_pago !== 'efectivo').reduce((s, v) => s + parseFloat(v.total || 0), 0);
    return { count: filtrado.length, total, efectivo, qr };
  }, [filtrado]);

  const cajeroLabel = filtroCajero === 'todos'
    ? 'Todos los cajeros'
    : cajeros.find(c => String(c.id) === filtroCajero)?.nombre || 'Cajero';

  const exportar = () => exportarPDF({
    titulo:        'Reporte de Ventas',
    subtitulo:     `${fecha(params.desde)} — ${fecha(params.hasta)} · ${cajeroLabel}`,
    empresa,
    generadoPor:   usuario?.nombre,
    columnas:      ['Fecha', 'Mesa', 'Cliente', 'Cajero', 'Método de pago', 'Total'],
    filas:         filtrado.map(v => [
      fechaHora(v.creado_en),
      v.mesa?.nombre || '-',
      v.nombre_cliente || v.cliente?.nombre || 'Público General',
      v.usuario?.nombre || '-',
      v.metodo_pago || '-',
      bs(v.total),
    ]),
    totales: [
      { label: 'N° Ventas',          valor: stats.count },
      { label: 'Total Ingresos',     valor: bs(stats.total) },
      { label: 'Efectivo',           valor: bs(stats.efectivo) },
      { label: 'QR / Transferencia', valor: bs(stats.qr) },
    ],
    nombreArchivo: `reporte-ventas-${params.desde}-${params.hasta}${filtroCajero !== 'todos' ? `-${cajeroLabel}` : ''}.pdf`,
  });

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-wrap items-end gap-3">
          <FiltroFechas desde={desde} hasta={hasta} setDesde={setDesde} setHasta={setHasta}
            onBuscar={() => setParams({ desde, hasta })} cargando={isLoading} />
          <div className="flex flex-col gap-1">
            <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Cajero</label>
            <select value={filtroCajero} onChange={e => setFiltroCajero(e.target.value)}
              className="px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-violet-500">
              <option value="todos">Todos</option>
              {cajeros.map(c => (
                <option key={c.id} value={String(c.id)}>{c.nombre}</option>
              ))}
            </select>
          </div>
        </div>
        <button onClick={exportar} disabled={!filtrado.length}
          className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-medium transition-colors disabled:opacity-40">
          <Download className="w-4 h-4" /> Exportar PDF
        </button>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="N° Ventas"          valor={stats.count}        color="violet"  Icono={ShoppingCart} idx={0} />
        <StatCard label="Total Ingresos"     valor={bs(stats.total)}    color="emerald" Icono={TrendingUp}   idx={1} />
        <StatCard label="Efectivo"           valor={bs(stats.efectivo)} color="blue"    Icono={DollarSign}   idx={2} />
        <StatCard label="QR / Transferencia" valor={bs(stats.qr)}       color="amber"   Icono={BarChart2}    idx={3} />
      </div>

      {isLoading ? <Skeleton /> : (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 dark:border-gray-700/50">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-800/60 border-b border-gray-200 dark:border-gray-700/50">
                {['Fecha', 'Mesa', 'Cliente', 'Cajero', 'Método', 'Total'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/40">
              {filtrado.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-10 text-gray-400 dark:text-gray-500">Sin resultados para el período</td></tr>
              ) : filtrado.map((v, i) => (
                <tr key={v.id}
                  className="bg-white dark:bg-gray-900 hover:bg-violet-50/40 dark:hover:bg-violet-900/10 transition-colors animate-[rpFadeUp_0.3s_ease_forwards] opacity-0"
                  style={{ animationDelay: `${i * 20}ms` }}>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300 whitespace-nowrap">{fechaHora(v.creado_en)}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{v.mesa?.nombre || '-'}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{v.nombre_cliente || v.cliente?.nombre || 'Público General'}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{v.usuario?.nombre || '-'}</td>
                  <td className="px-4 py-3"><BadgeTipo tipo={v.metodo_pago || 'efectivo'} /></td>
                  <td className="px-4 py-3 font-semibold text-emerald-600 dark:text-emerald-400">{bs(v.total)}</td>
                </tr>
              ))}
            </tbody>
            {filtrado.length > 0 && (
              <tfoot>
                <tr className="bg-gray-50 dark:bg-gray-800/60 border-t-2 border-violet-200 dark:border-violet-700/40">
                  <td colSpan={5} className="px-4 py-3 text-right font-semibold text-gray-700 dark:text-gray-300 text-sm">TOTAL</td>
                  <td className="px-4 py-3 font-bold text-emerald-600 dark:text-emerald-400">{bs(stats.total)}</td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      )}
    </div>
  );
}
