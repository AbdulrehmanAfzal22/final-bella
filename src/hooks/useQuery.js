import {useCallback,useEffect,useRef,useState} from 'react';
export function useQuery(load,deps=[]){
 const [data,setData]=useState(null),[error,setError]=useState(null),[loading,setLoading]=useState(true),version=useRef(0);
 const refresh=useCallback(async()=>{const v=++version.current;setLoading(true);setError(null);try{const value=await load();if(v===version.current)setData(value);}catch(e){if(v===version.current)setError(e);}finally{if(v===version.current)setLoading(false);}},deps);
 useEffect(()=>{refresh();const focus=()=>refresh();window.addEventListener('focus',focus);return()=>{version.current++;window.removeEventListener('focus',focus);};},[refresh]);
 return {data,error,loading,refresh,setData};
}
