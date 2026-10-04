import test from 'node:test';
import assert from 'node:assert/strict';
import {findCategoryByRoute,isAccessoryCategory,categoriesForSection} from '../src/lib/categoryMatching.js';

const categories=[
  {id:'category-01',name:'Embroidered',slug:'embroidered'},
  {id:'category-02',name:'Ready to Wear',slug:'ready-to-wear'},
];

test('collection route matching accepts category ID, slug, or name',()=>{
  assert.equal(findCategoryByRoute(categories,'category-01'),categories[0]);
  assert.equal(findCategoryByRoute(categories,'ready-to-wear'),categories[1]);
  assert.equal(findCategoryByRoute(categories,'Ready to Wear'),categories[1]);
});

test('collection route matching ignores case and normalizes category names',()=>{
  assert.equal(findCategoryByRoute(categories,'EMBROIDERED'),categories[0]);
  assert.equal(findCategoryByRoute(categories,'ready---to wear'),categories[1]);
  assert.equal(findCategoryByRoute(categories,'unlisted'),null);
});

test('accessory category classification uses only the persisted boolean',()=>{
  assert.equal(isAccessoryCategory({name:'Jewellery',slug:'jewellery'}),false);
  assert.equal(isAccessoryCategory({name:'Footwear',slug:'accessories'}),false);
  assert.equal(isAccessoryCategory({name:'Collection',slug:'collection',is_accessory:true}),true);
  assert.equal(isAccessoryCategory({name:'Jewellery',is_accessory:false}),false);
});

test('section category filtering isolates group and hides inactive categories by default',()=>{
  const sectionCategories=[
    {id:'collection',is_accessory:false,is_active:true},
    {id:'inactive',is_accessory:false,is_active:false},
    {id:'accessory',is_accessory:true,is_active:true},
  ];
  assert.deepEqual(categoriesForSection(sectionCategories,false).map(category=>category.id),['collection']);
  assert.deepEqual(categoriesForSection(sectionCategories,true).map(category=>category.id),['accessory']);
  assert.deepEqual(categoriesForSection(sectionCategories,false,{activeOnly:false}).map(category=>category.id),['collection','inactive']);
});