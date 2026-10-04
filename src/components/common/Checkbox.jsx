import {useId} from 'react';

export default function Checkbox({label,error,hint,id,className='',...props}){
  const generatedId=useId();
  const inputId=id||generatedId;
  const hintId=hint?`${inputId}-hint`:undefined;
  const errorId=error?`${inputId}-error`:undefined;
  return <div className="me-field-group">
    <label className="me-checkbox-label" htmlFor={inputId}><input id={inputId} type="checkbox" className={`me-checkbox ${className}`.trim()} aria-invalid={error?true:undefined} aria-describedby={[hintId,errorId].filter(Boolean).join(' ')||undefined} {...props}/><span>{label}</span></label>
    {hint&&<p className="me-field-hint" id={hintId}>{hint}</p>}
    {error&&<p className="me-field-error" id={errorId}>{error}</p>}
  </div>;
}