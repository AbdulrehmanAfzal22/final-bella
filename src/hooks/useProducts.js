import {getProducts} from '../services/catalog';
import {useQuery} from './useQuery';

export function useProducts({admin=false,isAccessory=null}={}){
  return useQuery(()=>getProducts(admin,null,isAccessory),[admin,isAccessory]);
}