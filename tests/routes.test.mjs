import test from 'node:test';
import assert from 'node:assert/strict';
import {getStoreRouteMetadata} from '../src/config/routeMetadata.js';

test('public product and category routes have indexable metadata',()=>{
  assert.equal(getStoreRouteMetadata('/collections/coats').noindex,false);
  assert.equal(getStoreRouteMetadata('/contact-support').title,'Contact Support');
  assert.equal(getStoreRouteMetadata('/contact-support').noindex,false);
  assert.equal(getStoreRouteMetadata('/accessories').title,'Accessories');
  assert.equal(getStoreRouteMetadata('/accessories/scarves').noindex,false);
  assert.equal(getStoreRouteMetadata('/product/coat-01').title,'Product');
  assert.equal(getStoreRouteMetadata('/product/coat-01').noindex,false);
});

test('private customer routes and unknown paths are not indexed',()=>{
  for(const path of ['/account','/orders','/wishlist','/cart','/checkout','/support','/missing']){
    assert.equal(getStoreRouteMetadata(path).noindex,true,path);
  }
});

test('canonical and legacy auth URLs resolve the intended page metadata',()=>{
  assert.equal(getStoreRouteMetadata('/register').title,'Create an account');
  assert.equal(getStoreRouteMetadata('/reset-password').title,'Choose a new password');
  assert.equal(getStoreRouteMetadata('/reset-password','?mode=forgot').title,'Reset your password');
  assert.equal(getStoreRouteMetadata('/auth','?mode=signup').title,'Create an account');
  assert.equal(getStoreRouteMetadata('/auth','?mode=forgot').noindex,true);
});