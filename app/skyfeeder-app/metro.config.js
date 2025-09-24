const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const config = getDefaultConfig(__dirname);

config.resolver.extraNodeModules = {
  buffer: require.resolve("buffer/"),
  events: require.resolve("events/"),
  process: require.resolve("process/browser"),
  stream: require.resolve("readable-stream"),
  util: require.resolve("util/"),
};

module.exports = config;
