// A short-lived decorative effect. Frames run only while a fairy or sparkle is alive.
export function startFairyMagic(canvas, surface=window){
  const context=canvas.getContext('2d');
  if(!context)return ()=>{};
  let width=0,height=0,frame=0,lastY=surface.scrollY,lastFlight=-Infinity,lastBloom=-Infinity,travel=0,side=0,flightCount=0;
  let fairy=null,butterfly=null,particles=[];
  const compact=surface.matchMedia('(max-width: 700px)').matches;
  const reduced=surface.matchMedia('(prefers-reduced-motion: reduce)');
  const particleLimit=compact?30:54;
  const clock=()=>surface.performance.now();
  const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

  function resize(){
    width=surface.innerWidth;height=surface.innerHeight;
    const ratio=Math.min(surface.devicePixelRatio||1,2);
    canvas.width=Math.round(width*ratio);canvas.height=Math.round(height*ratio);
    context.setTransform(ratio,0,0,ratio,0,0);
  }

  function star(x,y,size,alpha,color){
    context.save();context.translate(x,y);context.globalAlpha=alpha;
    context.fillStyle=color;context.shadowColor=color;context.shadowBlur=size*3;
    context.beginPath();context.moveTo(0,-size);context.quadraticCurveTo(size*.2,-size*.2,size,0);
    context.quadraticCurveTo(size*.2,size*.2,0,size);context.quadraticCurveTo(-size*.2,size*.2,-size,0);
    context.quadraticCurveTo(-size*.2,-size*.2,0,-size);context.fill();context.restore();
  }

  function dust(x,y,now,kind='star'){
    particles.push({x:x+(Math.random()-.5)*30,y:y+(Math.random()-.5)*24,
      vx:(Math.random()-.5)*28,vy:kind==='petal'?-18:kind==='heart'?-22:9+Math.random()*17,born:now,kind,
      life:kind==='petal'?900+Math.random()*650:600+Math.random()*650,size:kind==='petal'?4+Math.random()*3:kind==='heart'?3+Math.random()*2:1.3+Math.random()*2.2,
      color:kind==='petal'?'#e9a1b8':Math.random()>.5?'#e4b66f':'#d985ad',phase:Math.random()*Math.PI*2});
    if(particles.length>particleLimit)particles.shift();
  }

  function heart(x,y,size,alpha,color){
    context.save();context.translate(x,y);context.globalAlpha=alpha;context.fillStyle=color;
    context.beginPath();context.moveTo(0,size*.75);
    context.bezierCurveTo(-size*2,-size*.4,-size,-size*1.5,0,-size*.45);
    context.bezierCurveTo(size,-size*1.5,size*2,-size*.4,0,size*.75);
    context.fill();context.restore();
  }

  function petal(x,y,size,alpha,color,phase){
    context.save();context.translate(x,y);context.rotate(phase);context.globalAlpha=alpha;
    const wash=context.createLinearGradient(-size,-size,size,size);
    wash.addColorStop(0,'#fff1ef');wash.addColorStop(.6,color);wash.addColorStop(1,'#efb5c8');
    context.fillStyle=wash;context.beginPath();context.moveTo(-size,0);
    context.bezierCurveTo(-size,-size*1.2,size*.7,-size*.8,size,0);
    context.bezierCurveTo(size*.7,size*.8,-size,size*.6,-size,0);
    context.fill();context.restore();
  }

  function drawButterfly(x,y,progress,now,direction){
    const opacity=Math.min(progress*6,(1-progress)*5,.8);
    context.save();context.translate(x,y);context.rotate(direction*.3);
    context.globalAlpha=opacity;
    context.scale(.55+Math.abs(Math.sin(now/85))*.45,1);
    const wing=context.createRadialGradient(0,0,1,0,0,18);
    wing.addColorStop(0,'#fff7e5');wing.addColorStop(.5,'#e9b3ce');wing.addColorStop(1,'#bd769a66');
    context.fillStyle=wing;context.strokeStyle='#d7a66a';context.lineWidth=.65;
    for(const sign of [-1,1]){
      context.beginPath();context.ellipse(sign*9,-6,10,15,sign*.5,0,Math.PI*2);context.fill();context.stroke();
      context.beginPath();context.ellipse(sign*7,9,7,9,-sign*.4,0,Math.PI*2);context.fill();
    }
    context.strokeStyle='#a66c86';context.lineWidth=1.4;
    context.beginPath();context.moveTo(0,-10);context.lineTo(0,13);context.stroke();context.restore();
  }

  function drawFairy(x,y,progress,now,direction){
    const opacity=Math.min(progress*8,(1-progress)*6,1);
    context.save();context.translate(x,y);context.scale(direction*(compact ? 1.1 : 1.45),compact ? 1.1 : 1.45);
    context.rotate(-.2+Math.sin(now/180)*.08);context.globalAlpha=opacity;
    const wing=context.createRadialGradient(-5,-3,1,-10,-7,18);
    wing.addColorStop(0,'#fff9ee');wing.addColorStop(.55,'#eec7dcbb');wing.addColorStop(1,'#dfa3c600');
    context.fillStyle=wing;context.shadowColor='#d985ad';context.shadowBlur=9;
    const flutter=.7+Math.sin(now/42)*.25;
    context.save();context.scale(flutter,1);
    context.beginPath();context.ellipse(-10,-8,8,14,-.65,0,Math.PI*2);context.fill();
    context.beginPath();context.ellipse(-10,5,7,10,.7,0,Math.PI*2);context.fill();context.restore();
    context.shadowBlur=0;
    context.strokeStyle='#e0b78f88';context.lineWidth=.5;
    context.beginPath();context.moveTo(-2,-3);context.quadraticCurveTo(-10,-14,-13,-18);context.stroke();
    const dress=context.createLinearGradient(0,-4,0,12);
    dress.addColorStop(0,'#f3bdd6');dress.addColorStop(1,'#a9507d');context.fillStyle=dress;
    context.beginPath();context.moveTo(0,-4);context.quadraticCurveTo(4,2,7,10);
    context.quadraticCurveTo(0,8,-6,11);context.quadraticCurveTo(-2,0,0,-4);context.fill();
    context.fillStyle='#efd1ad';context.beginPath();context.arc(1,-9,3.4,0,Math.PI*2);context.fill();
    context.fillStyle='#a8754c';context.beginPath();context.arc(-1,-11,2.6,0,Math.PI*2);context.fill();
    context.beginPath();context.arc(-3,-14,2,0,Math.PI*2);context.fill();
    star(0,-15,1.8,opacity,'#e7bd77');
    context.strokeStyle='#d4a781';context.lineWidth=1.3;context.lineCap='round';
    context.beginPath();context.moveTo(1,0);context.lineTo(10,-3);context.moveTo(0,9);context.lineTo(-3,15);context.stroke();
    star(13,-5,3,opacity,'#e4b66f');context.restore();
  }

  function render(now){
    frame=0;context.clearRect(0,0,width,height);
    if(reduced.matches||surface.document.hidden){fairy=null;butterfly=null;particles=[];return;}
    if(fairy){
      const progress=clamp((now-fairy.born)/fairy.life,0,1);
      const ease=1-Math.pow(1-progress,2);
      const x=fairy.x+(fairy.endX-fairy.x)*ease;
      const y=fairy.y-fairy.rise*ease-Math.sin(progress*Math.PI)*42;
      drawFairy(x,y,progress,now,fairy.direction);
      if(now-fairy.lastDust>55){dust(x-7*fairy.direction,y+5,now,Math.random()>.85?'heart':'star');fairy.lastDust=now;}
      if(progress===1)fairy=null;
    }
    if(butterfly){
      const progress=clamp((now-butterfly.born)/butterfly.life,0,1);
      drawButterfly(butterfly.x+butterfly.direction*120*progress,
        butterfly.y-100*progress+Math.sin(progress*Math.PI*3)*16,progress,now,butterfly.direction);
      if(progress===1)butterfly=null;
    }
    particles=particles.filter(particle=>now-particle.born<particle.life);
    for(const particle of particles){
      const age=(now-particle.born)/1000,progress=(now-particle.born)/particle.life;
      const twinkle=.65+.35*Math.sin(now/90+particle.phase);
      const draw=particle.kind==='petal'?petal:particle.kind==='heart'?heart:star;
      draw(particle.x+particle.vx*age+(particle.kind==='petal'?Math.sin(age*3+particle.phase)*12:0),particle.y+particle.vy*age,particle.size,
        Math.sin(progress*Math.PI)*twinkle*.8,particle.color,particle.phase+age*1.2);
    }
    if(fairy||butterfly||particles.length)frame=surface.requestAnimationFrame(render);
  }

  function scroll(){
    const y=surface.scrollY;travel+=Math.abs(y-lastY);lastY=y;
    if(reduced.matches||surface.document.hidden)return;
    const now=clock();
    if(travel<70||now-lastFlight<(compact?2100:1800))return;
    travel=0;lastFlight=now;side=1-side;
    const x=side?width-35:35,direction=side?-1:1;
    fairy={x,y:height*(.55+Math.random()*.22),endX:clamp(x+direction*(compact?100:180),28,width-28),
      rise:90+Math.random()*65,direction,born:now,lastDust:now,life:2200};
    flightCount++;
    if(flightCount%2===0)butterfly={x:x+direction*28,y:fairy.y+65,direction,born:now+100,life:2000};
    for(let i=0;i<8;i++)dust(x,fairy.y,now-80+i*12,i%4===0?'petal':i%3===0?'heart':'star');
    if(!frame)frame=surface.requestAnimationFrame(render);
  }

  // Delegation is limited to presentation targets; forms and checkout controls are excluded.
  function bloom(event){
    if(reduced.matches||surface.document.hidden)return;
    if(event.type==='pointerover'&&event.pointerType==='touch')return;
    const target=event.target?.closest?.('.luxury-product-card__visual,.product-photo,.new-arrivals__image-link,.collection-puzzle__card,.accessories-masonry__card,.home-hero .luxury-outline-button');
    if(!target||target.contains(event.relatedTarget))return;
    const now=clock();if(now-lastBloom<500)return;
    lastBloom=now;
    const rect=target.getBoundingClientRect();
    const x=clamp(event.clientX??rect.left+rect.width/2,12,width-12);
    const y=clamp(event.clientY??rect.top+rect.height/2,12,height-12);
    for(let i=0;i<(compact?7:11);i++)dust(x+(Math.random()-.5)*46,y,now,i%5===0?'petal':i%4===0?'heart':'star');
    if(!frame)frame=surface.requestAnimationFrame(render);
  }

  function clear(){
    if(frame)surface.cancelAnimationFrame(frame);
    frame=0;fairy=null;butterfly=null;particles=[];travel=0;lastY=surface.scrollY;
    context.clearRect(0,0,width,height);
  }
  resize();surface.addEventListener('resize',resize);surface.addEventListener('scroll',scroll,{passive:true});
  surface.document.addEventListener('visibilitychange',clear);
  surface.document.addEventListener('pointerover',bloom,{passive:true});surface.document.addEventListener('pointerdown',bloom,{passive:true});reduced.addEventListener?.('change',clear);
  return ()=>{clear();surface.removeEventListener('resize',resize);surface.removeEventListener('scroll',scroll);
    surface.document.removeEventListener('visibilitychange',clear);
    surface.document.removeEventListener('pointerover',bloom);surface.document.removeEventListener('pointerdown',bloom);reduced.removeEventListener?.('change',clear);};
}
