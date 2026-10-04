import test from 'node:test';
import assert from 'node:assert/strict';
import {startFairyMagic} from '../src/lib/fairyMagic.js';

function fixture(){
  const events=()=>({handlers:new Map(),addEventListener(name,fn){this.handlers.set(name,fn);},removeEventListener(name){this.handlers.delete(name);},emit(name,event){this.handlers.get(name)?.(event);}});
  const document={...events(),hidden:false},reduced={...events(),matches:false};
  let now=0,id=0,clears=0;
  const frames=new Map();
  const context=new Proxy({clearRect(){clears++;},createRadialGradient(){return {addColorStop(){}};},createLinearGradient(){return {addColorStop(){}};}},{get:(target,key)=>target[key]||(()=>{})});
  const canvas={getContext:()=>context};
  const surface={...events(),document,innerWidth:1200,innerHeight:800,devicePixelRatio:3,scrollY:0,
    performance:{now:()=>now},matchMedia:query=>query.includes('reduced-motion')?reduced:{matches:false},
    requestAnimationFrame(fn){frames.set(++id,fn);return id;},cancelAnimationFrame(id){frames.delete(id);}};
  const scroll=y=>{surface.scrollY=y;surface.emit('scroll');};
  function tick(time){now=time;const current=[...frames.values()];frames.clear();current.forEach(fn=>fn(time));}
  return {surface,canvas,frames,reduced,document,scroll,tick,clears:()=>clears};
}

test('Fairy effect sleeps when idle and stops after the flight and dust fade',()=>{
  const f=fixture(),stop=startFairyMagic(f.canvas,f.surface);
  assert.equal(f.canvas.width,2400,'Pixel ratio is capped for rendering cost');
  assert.equal(f.frames.size,0,'Idle page has no animation loop');
  f.scroll(20);assert.equal(f.frames.size,0);
  f.scroll(100);assert.equal(f.frames.size,1);
  for(let time=0;time<=4000;time+=100)f.tick(time);
  assert.equal(f.frames.size,0,'The loop ends without further scrolling');
  stop();assert.equal(f.surface.handlers.size,0);assert.equal(f.document.handlers.size,0);assert.equal(f.reduced.handlers.size,0);
});

test('Reduced motion, hidden tabs and cleanup cancel decorative animation',()=>{
  const f=fixture(),stop=startFairyMagic(f.canvas,f.surface);
  f.reduced.matches=true;f.scroll(150);assert.equal(f.frames.size,0);
  f.reduced.matches=false;f.scroll(300);assert.equal(f.frames.size,1);
  f.document.hidden=true;f.document.emit('visibilitychange');assert.equal(f.frames.size,0);
  f.document.hidden=false;f.tick(2000);f.scroll(500);assert.equal(f.frames.size,1);
  stop();assert.equal(f.frames.size,0);assert.ok(f.clears()>0);
});

test('Product hover blooms are short lived and never intercept pointer events',()=>{
  const f=fixture(),stop=startFairyMagic(f.canvas,f.surface);
  const card={contains:()=>false,getBoundingClientRect:()=>({left:200,top:300,width:200,height:240})};
  const event={type:'pointerover',pointerType:'mouse',clientX:230,clientY:320,target:{closest:()=>card},relatedTarget:null};
  f.document.emit('pointerover',event);
  assert.equal(f.frames.size,1,'Hover wakes the sleeping renderer');
  for(let i=0;i<100;i++)f.document.emit('pointerover',event);
  assert.equal(f.frames.size,1,'Rapid pointer activity does not multiply animation loops');
  for(let time=0;time<=1800;time+=100)f.tick(time);
  assert.equal(f.frames.size,0,'Hover bloom fades without leaving a running loop');
  stop();assert.equal(f.document.handlers.size,0);
});

test('Forms, touch hover and motion preferences do not trigger sparkle blooms',()=>{
  const f=fixture(),stop=startFairyMagic(f.canvas,f.surface);
  const card={contains:()=>false,getBoundingClientRect:()=>({left:100,top:100,width:100,height:100})};
  const event={type:'pointerover',pointerType:'touch',target:{closest:()=>card}};
  f.document.emit('pointerover',event);assert.equal(f.frames.size,0);
  f.document.emit('pointerdown',{...event,type:'pointerdown',target:{closest:()=>null}});assert.equal(f.frames.size,0);
  f.reduced.matches=true;
  f.document.emit('pointerdown',{...event,type:'pointerdown'});assert.equal(f.frames.size,0);
  f.reduced.matches=false;f.document.hidden=true;
  f.document.emit('pointerdown',{...event,type:'pointerdown'});assert.equal(f.frames.size,0);
  f.document.hidden=false;
  f.document.emit('pointerdown',{...event,type:'pointerdown'});assert.equal(f.frames.size,1,'A deliberate product tap can show a bloom');
  stop();assert.equal(f.frames.size,0);
});
