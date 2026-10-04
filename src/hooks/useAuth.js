import {useSession} from '../context/SessionContext';

export function useAuth(){
  return useSession();
}