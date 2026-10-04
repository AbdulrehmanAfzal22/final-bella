import {useEffect} from 'react';

const defaultDescription='Your everyday beauty edit, with room for individuality. Discover Bella by RT.';

export function usePageMetadata({title,description=defaultDescription,noindex=false,image,type='website'}={}){
  useEffect(()=>{
    const fullTitle=title?`${title} | Bella by RT`:'Bella by RT — Your everyday beauty edit';
    document.title=fullTitle;
    const canonicalUrl=`${window.location.origin}${window.location.pathname}`;
    setMeta('name','description',description);
    setMeta('name','robots',noindex?'noindex,nofollow':null);
    setMeta('property','og:title',fullTitle);
    setMeta('property','og:description',description);
    setMeta('property','og:type',type);
    setMeta('property','og:image',image||null);
    let canonical=document.querySelector('link[rel="canonical"]');
    if(!canonical){canonical=document.createElement('link');canonical.rel='canonical';document.head.append(canonical);}
    canonical.href=canonicalUrl;
  },[title,description,noindex,image,type]);
}

function setMeta(attribute,key,content){
  let element=document.head.querySelector(`meta[${attribute}="${key}"]`);
  if(!content){element?.remove();return;}
  if(!element){element=document.createElement('meta');element.setAttribute(attribute,key);document.head.append(element);}
  element.content=content;
}