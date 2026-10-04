import {createContext,useContext,useEffect,useState,useCallback} from 'react';
import {supabase,unwrap} from '../lib/supabase';
import {ensureCustomerProfile} from '../services/supportService';
const Context=createContext(null);
export function SessionProvider({children}){
 const [user,setUser]=useState(null),[admin,setAdmin]=useState(false),[loading,setLoading]=useState(true),[error,setError]=useState('');
 const refresh=useCallback(async()=>{
  try{setError('');const {data,error}=await supabase.auth.getUser();
   if(error && error.name!=='AuthSessionMissingError') throw error;
   setUser(data.user);
   if(data.user){await ensureCustomerProfile();setAdmin(!!unwrap(await supabase.rpc('is_admin')));}
   else setAdmin(false);
  }catch(e){setError(e.message);setAdmin(false);}finally{setLoading(false);}
 },[]);
 useEffect(()=>{refresh();const {data:{subscription}}=supabase.auth.onAuthStateChange(()=>{setTimeout(refresh,0)});return()=>subscription.unsubscribe();},[refresh]);
 return <Context.Provider value={{user,admin,loading,error,refresh}}>{children}</Context.Provider>;
}
export const useSession=()=>useContext(Context);
