import {BarChart3,Boxes,Instagram,LayoutDashboard,MessageSquare,Package,ShoppingBag,Star,Tags,Users} from 'lucide-react';

export const storeNavigation=[
  {label:'Collections',to:'/collections'},
  {label:'Accessories',to:'/accessories'},
  {label:'New arrivals',to:'/shop?sort=newest'},
  {label:'Shop',to:'/shop'},
  {label:'Our Story',to:'/about'},
];

export const customerNavigation=[
  {label:'My account',to:'/account'},
  {label:'Order history',to:'/orders'},
  {label:'Saved pieces',to:'/wishlist'},
  {label:'Shopping bag',to:'/cart'},
];

export const exploreNavigation=[
  {label:'The collection',to:'/shop'},
  {label:'Collections',to:'/collections'},
  {label:'Accessories',to:'/accessories'},
  {label:'Our perspective',to:'/about'},
  {label:'Contact support',to:'/contact-support'},
];

export const adminNavigation=[
  {label:'Overview',to:'/admin',Icon:LayoutDashboard,end:true},
  {label:'All Products',to:'/admin/products',Icon:Package},
  {label:'Collections',to:'/admin/collections',Icon:Tags},
  {label:'Accessories',to:'/admin/accessories',Icon:ShoppingBag},
  {label:'Instagram Reels',to:'/admin/instagram-reels',Icon:Instagram},
  {label:'Inventory',to:'/admin/inventory',Icon:Boxes},
  {label:'Orders',to:'/admin/orders',Icon:ShoppingBag},
  {label:'Customers',to:'/admin/customers',Icon:Users},
  {label:'Analytics',to:'/admin/analytics',Icon:BarChart3},
  {label:'Reviews',to:'/admin/reviews',Icon:Star},
  {label:'Support Inbox',to:'/admin/support',Icon:MessageSquare},
];