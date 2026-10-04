import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
	plugins:[react()],
	server:{host:'0.0.0.0',port:4173,allowedHosts:['terminal.local']},
	build:{
		rollupOptions:{
			output:{
				manualChunks(id){
					if(!id.includes('node_modules'))return;
					if(id.includes('/framer-motion/')||id.includes('/motion-dom/')||id.includes('/motion-utils/'))return 'motion-vendor';
					if(id.includes('/@supabase/'))return 'supabase-vendor';
				}
			}
		}
	}
});
