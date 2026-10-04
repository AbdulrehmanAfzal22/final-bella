export default function SectionTitle({id,eyebrow,title,description,action,as:Heading='h2',className=''}){
  return <header className={`me-section-title ${className}`.trim()}>
    <div className="me-section-title__copy">
      {eyebrow&&<p className="me-section-title__eyebrow">{eyebrow}</p>}
      <Heading id={id} className="me-section-title__heading">{title}</Heading>
      {description&&<p className="me-section-title__description">{description}</p>}
    </div>
    {action&&<div className="me-section-title__action">{action}</div>}
  </header>;
}