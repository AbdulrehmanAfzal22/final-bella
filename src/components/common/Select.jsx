import {useId} from 'react';

export default function Select({label,error,hint,id,className='',children,...props}){
  const generatedId=useId();
  const selectId=id||generatedId;
  const hintId=hint?`${selectId}-hint`:undefined;
  const errorId=error?`${selectId}-error`:undefined;
  return <div className="me-field-group">
    {label&&<label className="me-field-label" htmlFor={selectId}>{label}</label>}
    <select id={selectId} className={`me-field ${className}`.trim()} aria-invalid={error?true:undefined} aria-describedby={[hintId,errorId].filter(Boolean).join(' ')||undefined} {...props}>{children}</select>
    {hint&&<p className="me-field-hint" id={hintId}>{hint}</p>}
    {error&&<p className="me-field-error" id={errorId}>{error}</p>}
  </div>;
}