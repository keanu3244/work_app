import { createSSRApp } from 'vue';
import App from '@/App.vue';
import setupPlugins from '@/plugins';
import { setupRealtime } from '@/services/realtime';
import { bootstrapSession } from '@/utils/auth';
// 引入UnoCSS
import 'virtual:uno.css';

export function createApp() {
  bootstrapSession();
  setupRealtime();
  const app = createSSRApp(App);
  app.use(setupPlugins);

  return {
    app,
  };
}
