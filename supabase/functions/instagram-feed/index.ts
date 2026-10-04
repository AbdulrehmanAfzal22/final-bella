import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'GET, POST, OPTIONS',
};
const graphBase='https://graph.instagram.com/v25.0';
const cacheMs=60*60*1000;
const pageSize=12;
type SupabaseClient=ReturnType<typeof createClient>;
type InstagramConnection={instagram_user_id:string;username:string;access_token:string;token_expires_at:string|null;profile_image_url:string|null};

function response(body:unknown,status=200){
  return new Response(JSON.stringify(body),{status,headers:{...corsHeaders,'Content-Type':'application/json'}});
}

function serviceClient():SupabaseClient{
  return createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
}

async function requireAdmin(request:Request){
  const authorization=request.headers.get('Authorization');
  if(!authorization)return null;
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
  const {data:{user}}=await client.auth.getUser();
  if(!user)return null;
  const {data:isAdmin,error}=await client.rpc('is_admin');
  return error||!isAdmin?null:user;
}

async function getSettings(client:SupabaseClient){
  const {data,error}=await client.from('instagram_feed_settings').select('*').eq('id',true).single();
  if(error)throw error;
  return data;
}

async function getConnection(client:SupabaseClient):Promise<InstagramConnection|null>{
  const {data,error}=await client.from('instagram_private_connection').select('*').eq('id',true).maybeSingle();
  if(error)throw error;
  return data;
}

async function getSecretConnection():Promise<InstagramConnection|null>{
  const accessToken=Deno.env.get('INSTAGRAM_ACCESS_TOKEN')?.trim();
  if(!accessToken)return null;
  const profileUrl=new URL(`${graphBase}/me`);
  profileUrl.searchParams.set('fields','user_id,username,profile_picture_url');
  profileUrl.searchParams.set('access_token',accessToken);
  const result=await fetch(profileUrl);
  const data=await result.json();
  if(!result.ok||data.error)throw new Error('Instagram profile lookup failed. Verify the INSTAGRAM_ACCESS_TOKEN secret and permissions.');
  const profile=data.data?.[0]||data;
  const userId=profile.user_id||profile.id;
  if(!userId)throw new Error('Instagram profile lookup did not return an account ID.');
  return {instagram_user_id:String(userId),username:profile.username||'bellabyrt',access_token:accessToken,token_expires_at:null,profile_image_url:profile.profile_picture_url||null};
}

async function refreshAccessToken(client:SupabaseClient,connection:InstagramConnection):Promise<InstagramConnection>{
  const url=new URL(`${graphBase}/refresh_access_token`);
  url.searchParams.set('grant_type','ig_refresh_token');
  url.searchParams.set('access_token',connection.access_token);
  const result=await fetch(url);
  const data=await result.json();
  if(!result.ok||data.error)throw new Error(data.error?.message||'Instagram token refresh failed. Reconnect the account.');
  const tokenExpiresAt=new Date(Date.now()+(data.expires_in||5184000)*1000).toISOString();
  const {error}=await client.from('instagram_private_connection').update({access_token:data.access_token,token_expires_at:tokenExpiresAt}).eq('id',true);
  if(error)throw error;
  return {...connection,access_token:data.access_token,token_expires_at:tokenExpiresAt};
}

async function currentToken(client:SupabaseClient):Promise<InstagramConnection|null>{
  const secretConnection=await getSecretConnection();
  if(secretConnection)return secretConnection;
  let connection=await getConnection(client);
  if(!connection)return null;
  if(connection.token_expires_at&&new Date(connection.token_expires_at).getTime()<Date.now()+7*24*60*60*1000){
    connection=await refreshAccessToken(client,connection);
  }
  return connection;
}

async function syncReels(client:SupabaseClient,connection:InstagramConnection){
  const settings=await getSettings(client);
  const fields='id,caption,media_type,media_product_type,media_url,permalink,thumbnail_url,timestamp,username,like_count,comments_count,children{media_type,media_url,thumbnail_url}';
  let url:URL|null=new URL(`${graphBase}/${connection.instagram_user_id}/media`);
  url.searchParams.set('fields',fields);
  url.searchParams.set('limit','50');
  url.searchParams.set('access_token',connection.access_token);
  const posts:any[]=[];
  while(url&&posts.length<settings.reels_to_display){
    const result=await fetch(url);
    const data=await result.json();
    if(!result.ok||data.error)throw new Error(data.error?.message||'Instagram feed request failed.');
    for(const item of data.data||[]){
      const firstChild=item.children?.data?.[0];
      const thumbnailUrl=item.thumbnail_url||item.media_url||firstChild?.thumbnail_url||firstChild?.media_url;
      const isReelVideo=item.media_type==='VIDEO'&&(item.media_product_type==='REELS'||item.permalink?.includes('/reel/'));
      if(!(isReelVideo||item.media_type==='IMAGE'||item.media_type==='CAROUSEL_ALBUM')||!item.permalink||!thumbnailUrl)continue;
      posts.push({...item,media_url:item.media_url||firstChild?.media_url||null,thumbnail_url:thumbnailUrl});
      if(posts.length>=settings.reels_to_display)break;
    }
    url=data.paging?.next?new URL(data.paging.next):null;
  }
  const viewsById=new Map<string,number>();
  const videos=posts.filter(item=>item.media_type==='VIDEO').slice(0,12);
  for(let index=0;index<videos.length;index+=4){
    const batch=videos.slice(index,index+4);
    const results=await Promise.all(batch.map(async item=>{
      try{
        const insightsUrl=new URL(`${graphBase}/${item.id}/insights`);
        insightsUrl.searchParams.set('metric','views');
        insightsUrl.searchParams.set('access_token',connection.access_token);
        const result=await fetch(insightsUrl);
        const data=await result.json();
        const value=data.data?.find((metric:any)=>metric.name==='views')?.values?.[0]?.value;
        return value!==null&&value!==undefined&&Number.isFinite(Number(value))?[item.id,Number(value)] as const:null;
      }catch{return null;}
    }));
    results.forEach(result=>{if(result)viewsById.set(result[0],result[1]);});
  }
  const mediaIds=posts.map(item=>item.id);
  let existingRows:any[]=[];
  if(mediaIds.length){
    const {data,error}=await client.from('instagram_reels').select('media_id,category,shop_url,product_id').in('media_id',mediaIds);
    if(error)throw error;
    existingRows=data||[];
  }
  const existingById=new Map<string,any>((existingRows||[]).map(row=>[row.media_id,row]));
  const rows=posts.map((item,index)=>{
    const existing=existingById.get(item.id);
    return ({
    media_id:item.id,
    media_url:item.media_url||null,
    instagram_url:item.permalink,
    username:item.username||connection.username||settings.username,
    profile_image:connection.profile_image_url||null,
    thumbnail_url:item.thumbnail_url||null,
    category:existing?.category||'',
    caption:item.caption||'',
    media_type:item.media_type,
    published_at:item.timestamp||null,
    view_count:viewsById.get(item.id)??null,
    like_count:item.like_count!==null&&item.like_count!==undefined&&Number.isFinite(Number(item.like_count))?Number(item.like_count):null,
    comment_count:item.comments_count!==null&&item.comments_count!==undefined&&Number.isFinite(Number(item.comments_count))?Number(item.comments_count):null,
    shop_url:existing?.shop_url||null,
    product_id:existing?.product_id||null,
    is_active:true,
    display_order:index,
  });
  });
  if(rows.length){
    const {error}=await client.from('instagram_reels').upsert(rows,{onConflict:'media_id'});
    if(error)throw error;
    const ids=rows.map(row=>row.media_id);
    const {error:archiveError}=await client.from('instagram_reels').update({is_active:false}).not('media_id','is',null).not('media_id','in',`(${ids.join(',')})`);
    if(archiveError)throw archiveError;
  }else{
    const {error}=await client.from('instagram_reels').update({is_active:false}).not('media_id','is',null);
    if(error)throw error;
  }
  const now=new Date().toISOString();
  await client.from('instagram_feed_settings').update({last_synced_at:now}).eq('id',true);
  await client.from('instagram_private_connection').update({last_synced_at:now}).eq('id',true);
  return posts.length;
}

async function ensureFreshFeed(client:SupabaseClient){
  const settings=await getSettings(client);
  if(!settings.is_enabled)return {settings,reels:[],connected:false,configured:false};
  const connection=await currentToken(client);
  if(!connection)return {settings,reels:[],connected:false,configured:false};
  const cachedAt=settings.last_synced_at?new Date(settings.last_synced_at).getTime():0;
  if(Date.now()-cachedAt>cacheMs)await syncReels(client,connection);
  const {data,error}=await client.from('instagram_reels').select('id,media_id,media_url,instagram_url,username,profile_image,thumbnail_url,category,caption,media_type,published_at,view_count,like_count,comment_count,product_id,shop_url,display_order').not('media_id','is',null).eq('is_active',true).order('published_at',{ascending:false}).limit(settings.reels_to_display);
  if(error)throw error;
  const allReels=data||[];
  return {settings,reels:allReels.slice(0,pageSize),nextOffset:allReels.length>pageSize?pageSize:null,connected:true,configured:true};
}

function publicItem(item){
  return {id:item.media_id,media_type:item.media_type||'VIDEO',media_url:item.media_url,thumbnail_url:item.thumbnail_url,permalink:item.instagram_url,caption:item.caption||'',timestamp:item.published_at,username:item.username||'bellabyrt',profile_image:item.profile_image,category:item.category,view_count:item.view_count,like_count:item.like_count,comment_count:item.comment_count,product_id:item.product_id,shop_url:item.shop_url};
}

async function handleCallback(request:Request,client:SupabaseClient){
  const url=new URL(request.url);
  const code=url.searchParams.get('code');
  const state=url.searchParams.get('state');
  const error=url.searchParams.get('error_description')||url.searchParams.get('error');
  if(error||!code||!state)return response({error:error||'Instagram authorization did not complete.'},400);
  const {data:oauth,error:stateError}=await client.from('instagram_oauth_states').select('*').eq('state',state).gt('expires_at',new Date().toISOString()).maybeSingle();
  if(stateError||!oauth)return response({error:'Instagram connection request expired. Start again from admin.'},400);
  const callbackUrl=`${Deno.env.get('SUPABASE_URL')}/functions/v1/instagram-feed?action=oauth-callback`;
  const form=new URLSearchParams({client_id:Deno.env.get('META_APP_ID')!,client_secret:Deno.env.get('META_APP_SECRET')!,grant_type:'authorization_code',redirect_uri:callbackUrl,code});
  const exchange=await fetch('https://api.instagram.com/oauth/access_token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:form});
  const short=await exchange.json();
  if(!exchange.ok||short.error)throw new Error(short.error_message||short.error?.message||'Instagram authorization code exchange failed.');
  const shortToken=short.data?.[0]||short;
  const longUrl=new URL(`${graphBase}/access_token`);
  longUrl.searchParams.set('grant_type','ig_exchange_token');
  longUrl.searchParams.set('client_secret',Deno.env.get('META_APP_SECRET')!);
  longUrl.searchParams.set('access_token',shortToken.access_token);
  const longResponse=await fetch(longUrl);
  const longToken=await longResponse.json();
  if(!longResponse.ok||longToken.error)throw new Error(longToken.error?.message||'Instagram long-lived token exchange failed.');
  const accessToken=longToken.data?.[0]||longToken;
  const profileUrl=new URL(`${graphBase}/me`);
  profileUrl.searchParams.set('fields','user_id,username,profile_picture_url');
  profileUrl.searchParams.set('access_token',accessToken.access_token);
  const profileResponse=await fetch(profileUrl);
  const profile=await profileResponse.json();
  if(!profileResponse.ok||profile.error)throw new Error(profile.error?.message||'Unable to read the authorized Instagram profile.');
  const profileData=profile.data?.[0]||profile;
  const settings=await getSettings(client);
  if(String(profileData.username||'').toLowerCase()!==settings.username.toLowerCase())throw new Error(`Authorized account is @${profileData.username||'unknown'}, not @${settings.username}.`);
  const expiresAt=new Date(Date.now()+(accessToken.expires_in||5184000)*1000).toISOString();
  const {error:saveError}=await client.from('instagram_private_connection').upsert({id:true,instagram_user_id:String(profileData.user_id||shortToken.user_id),username:profileData.username||'bellabyrt',profile_image_url:profileData.profile_picture_url||null,access_token:accessToken.access_token,token_expires_at:expiresAt,connected_at:new Date().toISOString()},{onConflict:'id'});
  if(saveError)throw saveError;
  await client.from('instagram_oauth_states').delete().eq('state',state);
  const appUrl=new URL('/admin/instagram-reels',oauth.redirect_origin);
  appUrl.searchParams.set('instagram_connection','connected');
  return Response.redirect(appUrl,303);
}

Deno.serve(async request=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
  const client=serviceClient();
  const url=new URL(request.url);
  const requestBody=request.method==='POST'?await request.clone().json().catch(()=>({})):{};
  const action=url.searchParams.get('action')||requestBody.action||'feed';
  try{
    if(action==='oauth-callback')return await handleCallback(request,client);
    if(action==='feed'||action==='more'){
      const result=await ensureFreshFeed(client);
      if(!result.configured)return response({success:false,code:'INSTAGRAM_NOT_CONFIGURED',message:'Instagram integration is not configured.'},503);
      if(action==='feed')return response({success:true,items:result.reels.map(publicItem),settings:publicSettings(result.settings),next_offset:result.nextOffset});
      const offset=Math.max(0,Number(url.searchParams.get('offset')??requestBody.offset)||0);
      const {data,error}=await client.from('instagram_reels').select('id,media_id,media_url,instagram_url,username,profile_image,thumbnail_url,category,caption,media_type,published_at,view_count,like_count,comment_count,product_id,shop_url,display_order').not('media_id','is',null).eq('is_active',true).order('published_at',{ascending:false}).range(offset,offset+pageSize-1);
      if(error)throw error;
      const reels=data||[];
      const {count}=await client.from('instagram_reels').select('id',{count:'exact',head:true}).not('media_id','is',null).eq('is_active',true);
      return response({success:true,items:reels.map(publicItem),next_offset:count!==null&&offset+reels.length<count?offset+reels.length:null});
    }
    const user=await requireAdmin(request);
    if(!user)return response({error:'Administrator access required.'},401);
    if(action==='connect'){
      const body=await request.json();
      const redirectOrigin=new URL(body.redirect_origin);
      if(!['https:','http:'].includes(redirectOrigin.protocol))return response({error:'Invalid admin redirect URL.'},400);
      const appId=Deno.env.get('META_APP_ID');
      const appSecret=Deno.env.get('META_APP_SECRET');
      if(!appId||!appSecret)return response({error:'Meta app credentials are not configured in Supabase Edge Function secrets.'},503);
      const state=crypto.randomUUID();
      await client.from('instagram_oauth_states').delete().lt('expires_at',new Date().toISOString());
      const {error}=await client.from('instagram_oauth_states').insert({state,admin_user_id:user.id,redirect_origin:redirectOrigin.origin,expires_at:new Date(Date.now()+10*60*1000).toISOString()});
      if(error)throw error;
      const redirectUri=`${Deno.env.get('SUPABASE_URL')}/functions/v1/instagram-feed?action=oauth-callback`;
      const authorize=new URL('https://www.instagram.com/oauth/authorize');
      authorize.searchParams.set('client_id',appId);
      authorize.searchParams.set('redirect_uri',redirectUri);
      authorize.searchParams.set('response_type','code');
      authorize.searchParams.set('scope','instagram_business_basic,instagram_business_manage_insights');
      authorize.searchParams.set('state',state);
      return response({authorize_url:authorize.toString()});
    }
    if(action==='status'){
      const [connection,settings]=await Promise.all([getConnection(client),getSettings(client)]);
      const tokenConfigured=Boolean(Deno.env.get('INSTAGRAM_ACCESS_TOKEN'));
      return response({connected:Boolean(connection||tokenConfigured),username:connection?.username|| (tokenConfigured?settings.username:null),connected_at:connection?.connected_at||null,last_synced_at:connection?.last_synced_at||settings.last_synced_at||null,settings:publicSettings(settings),meta_configured:Boolean(Deno.env.get('META_APP_ID')&&Deno.env.get('META_APP_SECRET'))});
    }
    if(action==='save-settings'){
      const body=await request.json();
      const allowed={username:String(body.username||'bellabyrt').replace(/^@/,''),profile_url:String(body.profile_url||'https://www.instagram.com/bellabyrt/'),reels_to_display:clampInt(body.reels_to_display,1,50,10),is_enabled:Boolean(body.is_enabled),autoplay_enabled:Boolean(body.autoplay_enabled),autoplay_interval_seconds:clampInt(body.autoplay_interval_seconds,3,10,3),desktop_cards:clampInt(body.desktop_cards,4,5,5),mobile_cards:Math.min(2,Math.max(1,Number(body.mobile_cards)||1.2))};
      if(!/^https:\/\/www\.instagram\.com\/[A-Za-z0-9._]+\/?$/.test(allowed.profile_url))return response({error:'Use a valid Instagram profile URL.'},400);
      if(allowed.username.toLowerCase()!=='bellabyrt'||new URL(allowed.profile_url).pathname.replaceAll('/','').toLowerCase()!=='bellabyrt')return response({error:'This integration is restricted to @bellabyrt.'},400);
      const {error}=await client.from('instagram_feed_settings').update(allowed).eq('id',true);
      if(error)throw error;
      return response({saved:true});
    }
    if(action==='refresh'){
      const connection=await currentToken(client);
      if(!connection)return response({error:'Connect @bellabyrt before refreshing the feed.'},409);
      const count=await syncReels(client,connection);
      return response({refreshed:count,last_synced_at:new Date().toISOString()});
    }
    if(action==='save-reel-link'){
      const body=await request.json();
      const shopUrl=body.shop_url?String(body.shop_url).trim():null;
      if(shopUrl&&!shopUrl.startsWith('/')&&!/^https:\/\//.test(shopUrl))return response({error:'Shop destination must be a site path or HTTPS URL.'},400);
      if(shopUrl?.startsWith('//'))return response({error:'Protocol-relative shop URLs are not allowed.'},400);
      const {data,error}=await client.from('instagram_reels').update({product_id:body.product_id||null,shop_url:shopUrl}).eq('id',body.id).not('media_id','is',null).select('id').maybeSingle();
      if(error)throw error;
      if(!data)return response({error:'Synced Reel not found.'},404);
      return response({saved:true});
    }
    if(action==='disconnect'){
      await client.from('instagram_private_connection').delete().eq('id',true);
      await client.from('instagram_reels').update({is_active:false}).not('media_id','is',null);
      await client.from('instagram_feed_settings').update({last_synced_at:null}).eq('id',true);
      return response({disconnected:true});
    }
    return response({success:false,code:'INSTAGRAM_API_ERROR',message:'Unable to retrieve Instagram media.'},400);
  }catch(error){
    console.error('Instagram feed request failed',action,error instanceof Error?error.name:'UnknownError');
    if(action==='feed'||action==='more')return response({success:false,code:'INSTAGRAM_API_ERROR',message:'Unable to retrieve Instagram media.'},502);
    return response({success:false,code:'INSTAGRAM_API_ERROR',message:error instanceof Error?error.message:'Instagram feed request failed.'},500);
  }
});

function clampInt(value:unknown,min:number,max:number,fallback:number){
  const parsed=Number.parseInt(String(value),10);
  return Number.isFinite(parsed)?Math.min(max,Math.max(min,parsed)):fallback;
}

function publicSettings(settings:Record<string,any>){
  return {username:settings.username,profile_url:settings.profile_url,reels_to_display:settings.reels_to_display,is_enabled:settings.is_enabled,autoplay_enabled:settings.autoplay_enabled,autoplay_interval_seconds:settings.autoplay_interval_seconds,desktop_cards:settings.desktop_cards,mobile_cards:Number(settings.mobile_cards),last_synced_at:settings.last_synced_at};
}