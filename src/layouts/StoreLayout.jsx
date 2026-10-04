import {Outlet,useLocation} from 'react-router-dom';
import {motion,useReducedMotion} from 'framer-motion';
import {getStoreRouteMetadata} from '../config/routeMetadata';
import {usePageMetadata} from '../hooks/usePageMetadata';
import LuxuryHeader from '../components/LuxuryHeader';
import LuxuryFooter from '../components/LuxuryFooter';
import StoreFooter from '../components/StoreFooter';
import FloatingSupportButton from '../components/FloatingSupportButton';
import FairyScrollMagic from '../components/FairyScrollMagic';
import PackagingGlow from '../components/PackagingGlow';
import './StoreLayout.css';
export default function StoreLayout(){
	const location=useLocation();
	const reducedMotion=useReducedMotion();
	const home=location.pathname==='/';
	const metadata=getStoreRouteMetadata(location.pathname,location.search);
	usePageMetadata(metadata);

	return <div className="bella-storefront">
		<PackagingGlow/>
		<a className="skip-link" href="#main">Skip to content</a>
		<div className="announcement">Demo collection · Sample products &amp; prices · Complimentary shipping</div>
		<LuxuryHeader home={home}/>
		<motion.main id="main" tabIndex="-1" initial={{opacity:1}} animate={{opacity:1}} exit={{opacity:0}} transition={{duration:reducedMotion?0:.45,ease:[.22,1,.36,1]}}><Outlet/></motion.main>
		{home?<LuxuryFooter/>:<StoreFooter/>}
		{location.pathname!=='/contact-support'&&<FloatingSupportButton/>}
		<FairyScrollMagic/>
	</div>;
}
