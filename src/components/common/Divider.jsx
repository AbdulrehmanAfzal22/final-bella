export default function Divider({short=false,className='',...props}){
  return <hr className={`me-divider ${short?'me-divider--short':''} ${className}`.trim()} {...props}/>;
}