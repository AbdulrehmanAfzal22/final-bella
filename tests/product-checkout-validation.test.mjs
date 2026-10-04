import test from 'node:test';
import assert from 'node:assert/strict';
import {validateProductForSave} from '../src/lib/productValidation.js';
import {shippingFromSavedAddress} from '../src/lib/shippingAddress.js';

const complete={categoryId:'category-id',description:'Soft cotton overshirt',status:'published',images:[{path:'cover.webp'}],files:[],variants:[{color:'Ink',size:'M'}]};

test('product save requires a category even for drafts',()=>{
  assert.throws(()=>validateProductForSave({...complete,categoryId:'',status:'draft'}),/Choose a category/);
  assert.doesNotThrow(()=>validateProductForSave({...complete,status:'draft',images:[],description:''}));
});

test('publishing requires description, image, and a complete variant',()=>{
  assert.doesNotThrow(()=>validateProductForSave(complete));
  assert.throws(()=>validateProductForSave({...complete,description:'   '}),/description/);
  assert.throws(()=>validateProductForSave({...complete,images:[]}),/image/);
  assert.throws(()=>validateProductForSave({...complete,variants:[]}),/variant/);
  assert.throws(()=>validateProductForSave({...complete,variants:[{color:'',size:''}]}),/complete colour and size/);
});

test('a queued upload satisfies publish image requirement',()=>{
  assert.doesNotThrow(()=>validateProductForSave({...complete,images:[],files:[{name:'cover.png'}]}));
});

test('saved address fields map to checkout fields and optional values default empty',()=>{
  assert.deepEqual(shippingFromSavedAddress({full_name:'Ada',line1:'1 Rue',city:'Paris',postal_code:'75001',country:'France',phone:'+331'}),{
    full_name:'Ada',line1:'1 Rue',city:'Paris',postal_code:'75001',country:'France',phone:'+331',
  });
  assert.deepEqual(shippingFromSavedAddress(null),{full_name:'',line1:'',city:'',postal_code:'',country:'',phone:''});
});