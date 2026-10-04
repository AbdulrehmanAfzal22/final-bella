import {X} from 'lucide-react';
import Modal from '../common/Modal';
import {FilterControls} from './FilterSidebar';

export default function MobileFilterDrawer({open,onClose,categories,colors,sizes,params,change,onClear,count}){
  return <Modal open={open} onClose={onClose} className="shop-filter-drawer" labelledBy="shop-filter-title">
    <div className="shop-filter-drawer__inner">
      <header className="shop-filter-drawer__heading"><div><p className="shop-eyebrow">The collection</p><h2 id="shop-filter-title">Filter & refine</h2></div><button type="button" onClick={onClose} aria-label="Close filters"><X size={20}/></button></header>
      <div className="shop-filter-drawer__body"><FilterControls categories={categories} colors={colors} sizes={sizes} params={params} change={change}/></div>
      <footer className="shop-filter-drawer__footer"><button type="button" className="shop-filter-drawer__clear" onClick={onClear}>Clear all</button><button type="button" className="shop-filter-drawer__apply" onClick={onClose}>View {count} {count===1?'piece':'pieces'}</button></footer>
    </div>
  </Modal>;
}