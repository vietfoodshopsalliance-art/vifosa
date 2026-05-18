// web/components/tracking/TrackingTimeline.tsx
'use client';

const STATUS_LABELS: Record<string, string> = {
  pending: 'Chờ xác nhận',
  confirmed: 'Quán đã xác nhận',
  preparing: 'Đang chuẩn bị',
  ready: 'Sẵn sàng giao',
  delivering: 'Đang giao hàng',
  delivered: 'Đã giao',
  completed: 'Hoàn thành',
  cancelled: 'Đã huỷ',
  refunded: 'Đã hoàn tiền',
};

const STATUS_ORDER = [
  'pending', 'confirmed', 'preparing', 'ready', 'delivering', 'delivered', 'completed',
];

interface HistoryEntry {
  status: string;
  at: string;
  note?: string;
}

interface Props {
  status: string;
  history: HistoryEntry[];
}

export default function TrackingTimeline({ status, history }: Props) {
  const isCancelled = status === 'cancelled' || status === 'refunded';

  return (
    <div className="bg-white rounded-2xl shadow p-6">
      <h2 className="font-semibold text-gray-800 mb-4">Trạng thái đơn hàng</h2>
      <ol className="relative border-l border-gray-200 space-y-4 pl-4">
        {history.map((entry, i) => (
          <li key={i} className="ml-2">
            <span className={`absolute -left-1.5 w-3 h-3 rounded-full border-2 ${
              i === history.length - 1
                ? isCancelled ? 'border-red-500 bg-red-500' : 'border-orange-500 bg-orange-500'
                : 'border-gray-300 bg-white'
            }`} />
            <p className={`text-sm font-medium ${i === history.length - 1 ? 'text-orange-600' : 'text-gray-600'}`}>
              {STATUS_LABELS[entry.status] ?? entry.status}
            </p>
            <p className="text-xs text-gray-400">
              {new Date(entry.at).toLocaleString('vi-VN')}
            </p>
            {entry.note && <p className="text-xs text-gray-500 mt-0.5">{entry.note}</p>}
          </li>
        ))}
      </ol>
    </div>
  );
}