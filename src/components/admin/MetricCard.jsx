import {ArrowDownRight,ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';

export default function MetricCard({label,value,detail,Icon,href,trend}){
  const content=<><div className="admin-metric-card__top"><span>{label}</span>{Icon&&<Icon size={17}/>}</div><strong>{value}</strong><div className="admin-metric-card__bottom">{trend&&<span className={`admin-metric-card__trend ${trend.direction==='down'?'is-down':'is-up'}`}>{trend.direction==='down'?<ArrowDownRight size={14}/>:<ArrowUpRight size={14}/>} {trend.label}</span>}<span>{detail}</span></div></>;
  return href?<Link className="admin-metric-card" to={href}>{content}</Link>:<article className="admin-metric-card">{content}</article>;
}