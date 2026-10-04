import {forwardRef} from 'react';

const IconButton=forwardRef(function IconButton({icon,label,className='',type='button',...props},ref){
  return <button ref={ref} type={type} className={`me-icon-button ${className}`.trim()} aria-label={label} title={props.title||label} {...props}>{icon}</button>;
});

export default IconButton;