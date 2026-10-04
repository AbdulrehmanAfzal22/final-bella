import {useId} from 'react';

export default function Input({label,error,hint,id,className='',...props}){
  const generatedId=useId();
  const inputId=id||generatedId;
  const hintId=hint?`${inputId}-hint`:undefined;
  const errorId=error?`${inputId}-error`:undefined;
  return <div className="me-field-group">
    {label&&<label className="me-field-label" htmlFor={inputId}>{label}</label>}
    <input id={inputId} className={`me-field ${className}`.trim()} aria-invalid={error?true:undefined} aria-describedby={[hintId,errorId].filter(Boolean).join(' ')||undefined} {...props}/>
    {hint&&<p className="me-field-hint" id={hintId}>{hint}</p>}
    {error&&<p className="me-field-error" id={errorId}>{error}</p>}
  </div>;
}