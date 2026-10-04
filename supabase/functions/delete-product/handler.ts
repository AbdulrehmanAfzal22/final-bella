const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type, x-supabase-api-version, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};

export function createDeleteProductHandler(getClient) {
  const respond = (status, body) => new Response(JSON.stringify(body), {
    status, headers: {...cors, 'Content-Type': 'application/json'},
  });
  return async function deleteProduct(request) {
    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: cors});
    if (request.method !== 'POST') return respond(405, {success: false, error: 'Use POST to delete one product.'});
    const authorization = request.headers.get('authorization') || '';
    if (!/^Bearer \S+$/i.test(authorization)) return respond(401, {success: false, error: 'Authentication required.'});
    let body;
    try {
      const text = await request.text();
      if (text.length > 4096) return respond(413, {success: false, error: 'Request is too large.'});
      body = JSON.parse(text);
    } catch {
      return respond(400, {success: false, error: 'Enter a valid product ID.'});
    }
    if (!body || typeof body !== 'object' || Array.isArray(body) || typeof body.product_id !== 'string' || !UUID.test(body.product_id) ||
        Object.keys(body).some(key => !['product_id', 'cleanup_only'].includes(key)) ||
        (body.cleanup_only !== undefined && typeof body.cleanup_only !== 'boolean')) {
      return respond(400, {success: false, error: 'A single valid product ID is required.'});
    }
    const productId = body.product_id.toLowerCase();
    let deleted = false;
    const pending = () => respond(207, {
      success: false, product_deleted: true, storage_cleanup_pending: true,
      product_id: productId,
      error: 'The product was deleted, but image cleanup could not finish. Please retry image cleanup.',
    });
    try {
      // User JWT stays on every RPC and Storage request. No service-role client.
      const client = getClient(authorization);
      const {data: auth, error: authError} = await client.auth.getUser();
      if (authError || !auth?.user) return respond(401, {success: false, error: 'Authentication required.'});
      const {data: admin, error: adminError} = await client.rpc('is_admin');
      if (adminError || admin !== true) return respond(403, {success: false, error: 'Admin access required.'});
      const {data, error} = await client.rpc('admin_delete_product', {
        p_product_id: productId, p_cleanup_only: body.cleanup_only === true,
      });
      if (error) {
        const status = error.code === 'P0002' ? 404 : error.code === '23503' ? 409 :
          error.code === '42501' ? 403 : error.code === '28000' ? 401 :
          ['55P03', '40P01', '40001', '57014'].includes(error.code) ? 409 : 500;
        const safe = ['P0002', '23503', '42501', '28000', '22023'].includes(error.code);
        return respond(status, {success: false, product_deleted: false, error: safe ? error.message : 'Product could not be deleted. Please try again.'});
      }
      if (!data?.product_deleted || data.product_id !== productId || data.storage_bucket !== 'product-images') {
        return respond(502, {success: false, error: 'Deletion could not be confirmed. Refresh the product list before retrying.'});
      }
      deleted = true;
      const paths = data.storage_paths;
      if (!Array.isArray(paths) || paths.some(path => typeof path !== 'string' ||
          !path.startsWith(`${productId}/`) || path.includes('\\') ||
          path.split('/').some(part => part === '..' || part === '.'))) return pending();

      // Do not remove media if another admin recreated the same product UUID.
      const {data: existing, error: lookupError} = await client.from('products').select('id').eq('id', productId).maybeSingle();
      if (lookupError || existing) return pending();
      for (let offset = 0; offset < paths.length; offset += 1000) {
        const {error: storageError} = await client.storage.from('product-images').remove(paths.slice(offset, offset + 1000));
        if (storageError) return pending();
      }
      return respond(200, {success: true, product_deleted: true, storage_cleanup_pending: false,
        product_id: productId, message: 'Product deleted successfully.'});
    } catch {
      return deleted ? pending() : respond(503, {success: false, error: 'Product could not be deleted. Please refresh the product list before retrying.'});
    }
  };
}
