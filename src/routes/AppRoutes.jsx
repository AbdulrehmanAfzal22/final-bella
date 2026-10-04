import {Navigate,Route,Routes} from 'react-router-dom';
import PublicRoute from '../components/PublicRoute';
import ProtectedRoute from '../components/ProtectedRoute';
import AdminRoute from '../components/AdminRoute';
import StoreLayout from '../layouts/StoreLayout';
import AdminLayout from '../layouts/AdminLayout';
import {About,Account,Cart,CategoryProducts,Checkout,Collections,Home,OrderConfirmation,Orders,Product,Shop,Wishlist} from '../pages/store';
import {Auth} from '../pages/auth/index.js';
import {Analytics,Customers,Dashboard,Inventory,Orders as AdminOrders,ProductEditor,Products,Reviews} from '../pages/admin';
import InstagramReels from '../admin/InstagramReels';
import AdminCatalogSection from '../pages/admin/AdminCatalogSection';
import ContactSupport from '../pages/ContactSupport';
import SupportManagement from '../pages/admin/SupportManagement';
import NotFound from '../pages/NotFound';

export default function AppRoutes({location}){
  return <Routes location={location}>
    <Route element={<StoreLayout/>}>
      <Route element={<PublicRoute/>}>
        <Route index element={<Home/>}/>
        <Route path="shop" element={<Shop/>}/>
        <Route path="search" element={<Shop/>}/>
        <Route path="about" element={<About/>}/>
        <Route path="contact-support" element={<ContactSupport/>}/>
        <Route path="support" element={<Navigate to="/contact-support" replace/>}/>
        <Route path="collections" element={<Collections/>}/>
        <Route path="accessories" element={<Collections isAccessory/>}/>
        <Route path="collections/:category" element={<CategoryProducts section="collections"/>}/>
        <Route path="accessories/:category" element={<CategoryProducts section="accessories"/>}/>
        <Route path="product/:id" element={<Product/>}/>
        <Route element={<PublicRoute guestOnly/>}>
          <Route path="login" element={<Auth/>}/>
          <Route path="register" element={<Auth/>}/>
        </Route>
        <Route path="reset-password" element={<Auth/>}/>
        <Route path="auth" element={<Auth/>}/>
      </Route>
      <Route element={<ProtectedRoute/>}>
        <Route path="cart" element={<Cart/>}/>
        <Route path="checkout" element={<Checkout/>}/>
        <Route path="order-confirmation/:orderId" element={<OrderConfirmation/>}/>
        <Route path="orders" element={<Orders/>}/>
        <Route path="wishlist" element={<Wishlist/>}/>
        <Route path="account" element={<Account/>}/>
      </Route>
      <Route path="*" element={<NotFound/>}/>
    </Route>
    <Route path="admin" element={<AdminRoute><AdminLayout/></AdminRoute>}>
      <Route index element={<Dashboard/>}/>
      <Route path="products" element={<Products/>}/>
      <Route path="products/create" element={<ProductEditor/>}/>
      <Route path="products/:id/edit" element={<ProductEditor/>}/>
      <Route path="products/new" element={<ProductEditor/>}/>
      <Route path="products/:id" element={<ProductEditor/>}/>
      <Route path="collections" element={<AdminCatalogSection isAccessory={false}/>}/>
      <Route path="accessories" element={<AdminCatalogSection isAccessory/>}/>
      <Route path="instagram-reels" element={<InstagramReels/>}/>
      <Route path="categories" element={<Navigate to="/admin/collections?tab=categories" replace/>}/>
      <Route path="orders" element={<AdminOrders/>}/>
      <Route path="customers" element={<Customers/>}/>
      <Route path="inventory" element={<Inventory/>}/>
      <Route path="analytics" element={<Analytics/>}/>
      <Route path="reviews" element={<Reviews/>}/>
      <Route path="support" element={<SupportManagement/>}/>
      <Route path="*" element={<NotFound/>}/>
    </Route>
  </Routes>;
}