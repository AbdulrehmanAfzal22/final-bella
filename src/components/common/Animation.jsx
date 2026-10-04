const animationClasses={fadeIn:'me-animate--fade-in',fadeUp:'me-animate--fade-up',slideIn:'me-animate--slide-in',imageReveal:'me-image-reveal'};

export default function Animation({type='fadeUp',as:Element='div',className='',children,...props}){
  return <Element className={`${animationClasses[type]||animationClasses.fadeUp} ${className}`.trim()} {...props}>{children}</Element>;
}