import React from 'react';
import {createRoot} from 'react-dom/client';
import {useEffect,useRef} from 'react';
import {useLocation} from 'react-router-dom';
import {BrowserRouter} from 'react-router-dom';
import {AnimatePresence,LayoutGroup} from 'framer-motion';
import {Toaster} from 'sonner';
import {SessionProvider} from './context/SessionContext';
import CursorProvider from './components/CursorProvider';
import AppRoutes from './routes/AppRoutes';
import './styles/base.css';
import './styles/workflows.css';
import './styles/luxury-home.css';
import './styles/luxury-mobile.css';
import './styles/luxury-footer.css';
import './styles/homepage.css';
import './styles/theme.css';
import './styles/support-requests.css';
import './styles/collection-browsing.css';
import './styles/bella-theme.css';
import './styles/accessories-editorial.css';
import './styles/home-journal-editorial.css';
import './styles/footer-editorial.css';
import './styles/bella-magic.css';
import './styles/bella-packaging.css';

// Preserve old prototype bookmarks while moving to real routes.
if(['#home','#shop','#admin','#account'].includes(location.hash)){history.replaceState(null,'',location.hash==='#home'?'/':location.hash.slice(1));}

function App(){
  return (
    <BrowserRouter>
      <CursorProvider>
        <SessionProvider>
          <RouteTransitions/>
          <Toaster richColors position="bottom-right"/>
        </SessionProvider>
      </CursorProvider>
    </BrowserRouter>
  );
}

function RouteTransitions(){
  const location=useLocation();
  const initialRender=useRef(true);
  useEffect(()=>{
    if(initialRender.current){initialRender.current=false;return undefined;}
    const timer=window.setTimeout(()=>window.scrollTo(0,0),location.pathname.startsWith('/admin')?0:450);
    return()=>window.clearTimeout(timer);
  },[location.pathname]);
  return <LayoutGroup id="maison-elan-routes"><AnimatePresence mode="popLayout" initial={false}><AppRoutes key={location.pathname} location={location}/></AnimatePresence></LayoutGroup>;
}

createRoot(document.getElementById('root')).render(<App/>);
