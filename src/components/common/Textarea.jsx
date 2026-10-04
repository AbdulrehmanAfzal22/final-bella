import {useId} from 'react';

export default function Textarea({label,error,hint,id,className='',...props}){
  const generatedId=useId();
  const textareaId=id||generatedId;
  const hintId=hint?`${textareaId}-hint`:undefined;
  const errorId=error?`${textareaId}-error`:undefined;
  return <div className="me-field-group">
    {label&&<label className="me-field-label" htmlFor={textareaId}>{label}</label>}
    <textarea id={textareaId} className={`me-field me-textarea ${className}`.trim()} aria-invalid={error?true:undefined} aria-describedby={[hintId,errorId].filter(Boolean).join(' ')||undefined} {...props}/>
    {hint&&<p className="me-field-hint" id={hintId}>{hint}</p>}
    {error&&<p className="me-field-error" id={errorId}>{error}</p>}
  </div>;
}