import { useEffect, useState } from 'react';
import { Save } from 'lucide-react';
import { toast } from 'sonner';

export default function QuantityEditor({ value, min = 0, max = 1000000, label, onSave, disabled = false }) {
  const [draft, setDraft] = useState(String(value));
  const [busy, setBusy] = useState(false);
  useEffect(() => setDraft(String(value)), [value]);
  async function submit(event) {
    event.preventDefault();
    const number = Number(draft);
    if (!draft || !Number.isInteger(number) || number < min || number > max) return;
    setBusy(true);
    try { await onSave(number); toast.success('Quantity saved.'); }
    catch (error) { toast.error(error.message); }
    finally { setBusy(false); }
  }
  return <form className="quantity-editor" onSubmit={submit}>
    <input type="number" aria-label={label} min={min} max={max} step="1" required value={draft}
      disabled={disabled || busy} onChange={event => setDraft(event.target.value)} />
    <button className="icon-button" type="submit" title="Save quantity" aria-label={'Save '+label}
      disabled={disabled || busy || draft === String(value)}><Save size={18} /></button>
  </form>;
}
