export default function Loader({label='Loading…',variant='legacy',className=''}){
  if(variant==='premium')return <div className={`me-loader ${className}`.trim()} role="status"><span className="me-loader__line" aria-hidden="true"/><span>{label}</span></div>;
  return <div className={`state ${className}`.trim()} role="status"><span className="loading-line"/>{label}</div>;
}