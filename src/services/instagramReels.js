import {supabase} from '../lib/supabase';

async function invoke(action,body={}){
  const {data,error}=await supabase.functions.invoke('instagram-feed',{body:{action,...body}});
  if(error){
    const context=error.context;
    let detail=error.message||'Instagram feed request failed.';
    if(context&&typeof context.clone==='function'){
      const payload=await context.clone().json().catch(()=>null);
      if(payload?.code==='INSTAGRAM_NOT_CONFIGURED'&&(action==='feed'||action==='more'))return {success:true,connected:false,reels:[],next_offset:null};
      if(payload?.message)detail=`${context.status||''} ${payload.code||''}: ${payload.message}`.trim();
      else if(payload?.error)detail=`${context.status||''}: ${payload.error}`.trim();
    }
    if(detail.includes('Failed to send a request')){
      try{
        const probe=await fetch(`${supabase.supabaseUrl}/functions/v1/instagram-feed`);
        if(probe.status===404){
          const payload=await probe.json().catch(()=>null);
          if(payload?.code==='NOT_FOUND')detail='HTTP 404 NOT_FOUND: Requested function was not found. Deploy the instagram-feed Supabase Edge Function.';
        }
      }catch{}
    }
    throw new Error(detail,{cause:error});
  }
  if(data?.error)throw new Error(data.error);
  return data;
}

function normalizeFeedItem(item,username){
  return {
    id:item.id||item.media_id,
    media_id:item.id||item.media_id,
    media_url:item.mediaUrl||item.media_url,
    media_type:item.mediaType||item.media_type||'IMAGE',
    instagram_url:item.permalink||item.instagram_url,
    permalink:item.permalink||item.instagram_url,
    username:item.username||username,
    profile_image:item.profileImage||item.profile_image,
    thumbnail_url:item.thumbnailUrl||item.thumbnail_url||item.mediaUrl||item.media_url,
    category:item.category,
    caption:item.caption||'',
    published_at:item.timestamp||item.published_at,
    view_count:item.viewCount??item.view_count,
    like_count:item.likeCount??item.like_count,
    comment_count:item.commentCount??item.comment_count,
    product_id:item.productId||item.product_id,
    shop_url:item.shopUrl||item.shop_url,
  };
}

function feedItems(result){
  const sources=[result.media,result.items,result.posts,result.reels].filter(Array.isArray);
  const seen=new Set();
  return sources.flat().filter(item=>{
    if(!item?.id&&!item?.media_id)return false;
    const id=item.id||item.media_id;
    if(seen.has(id))return false;
    seen.add(id);
    return true;
  }).map(item=>normalizeFeedItem(item,result.username));
}

function requireSuccessfulFeed(result){
  if(result?.success===true||result?.ok===true)return;
  const error=new Error(result?.message||result?.error||'Instagram feed request failed.');
  error.code=result?.code||'INSTAGRAM_API_ERROR';
  throw error;
}

export async function getInstagramFeed(){
  const result=await invoke('feed');
  requireSuccessfulFeed(result);
  return {...result,connected:result.connected!==false,reels:feedItems(result),nextOffset:result.nextOffset??result.next_offset??null};
}

export async function getMoreInstagramReels(offset){
  const result=await invoke('more',{offset});
  requireSuccessfulFeed(result);
  return {reels:feedItems(result),nextOffset:result.nextOffset??result.next_offset??null};
}

export async function getInstagramFeedStatus(){
  return invoke('status');
}

export async function saveInstagramFeedSettings(settings){
  return invoke('save-settings',settings);
}

export async function startInstagramConnection(redirectOrigin){
  return invoke('connect',{redirect_origin:redirectOrigin});
}

export async function refreshInstagramFeed(){
  return invoke('refresh');
}

export async function saveInstagramReelLink(id,values){
  return invoke('save-reel-link',{id,...values});
}

export async function disconnectInstagram(){
  return invoke('disconnect');
}

export async function getAdminInstagramReels(){
  const {data,error}=await supabase.from('instagram_reels').select('id,media_id,media_url,instagram_url,username,profile_image,thumbnail_url,caption,media_type,published_at,view_count,like_count,comment_count,is_active,display_order').not('media_id','is',null).order('published_at',{ascending:false}).limit(50);
  if(error)throw error;
  return data||[];
}
