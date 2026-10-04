export default function Button({className='button',type='button',variant,loading=false,fullWidth=false,children,disabled,...props}){
  const visualClass=variant?`me-button me-button--${variant}${fullWidth?' me-button--full':''} ${className==='button'?'':className}`.trim():className;
  return <button className={visualClass} type={type} disabled={disabled||loading} aria-busy={loading||undefined} {...props}>
    {loading&&variant&&<span className="me-button__spinner" aria-hidden="true"/>}
    {children}
  </button>;
}