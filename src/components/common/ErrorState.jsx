import Button from './Button';

export default function ErrorState({error,retry}){
  return <div className="state error" role="alert"><h2>Something needs attention</h2><p>{error?.message||error}</p>{retry&&<Button type="button" onClick={retry}>Try again</Button>}</div>;
}