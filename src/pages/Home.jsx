import {useProducts} from '../hooks/useProducts';
import LuxuryHero from '../components/LuxuryHero';
import BrandStatement from '../components/BrandStatement';
import CollectionShowcase from '../components/CollectionShowcase';
import NewArrivals from '../components/NewArrivals';
import CategoryCarousel from '../components/CategoryCarousel';
import StorySection from '../components/StorySection';
import LuxuryNewsletter from '../components/LuxuryNewsletter';

export default function Home(){
	const q=useProducts();

	return <>
		<LuxuryHero/>
		<CollectionShowcase products={q.data||[]} loading={q.loading&&!q.data} error={q.error} retry={q.refresh}/>
		<NewArrivals products={q.data||[]} loading={q.loading&&!q.data} error={q.error} retry={q.refresh}/>
		<BrandStatement/>
		<CategoryCarousel products={q.data||[]}/>
		<StorySection products={q.data||[]}/>
		<LuxuryNewsletter/>
	</>;
}
