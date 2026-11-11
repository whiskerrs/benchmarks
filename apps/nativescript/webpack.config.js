const webpack = require('@nativescript/webpack');

module.exports = (env) => {
  webpack.init(env);

  // Optional build-time API endpoint (used on Android; iOS also reads the
  // SHOP_API_URL launch environment variable at runtime, which takes priority).
  webpack.chainWebpack((config) => {
    config.plugin('DefinePlugin').tap((args) => {
      Object.assign(args[0], {
        __SHOP_API_URL__: JSON.stringify(process.env.SHOP_API_URL || ''),
      });
      return args;
    });
  });

  return webpack.resolveConfig();
};
