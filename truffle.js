module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8500,
      network_id: "default" // Match any network id
    },
    prod: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    }
  }
};
