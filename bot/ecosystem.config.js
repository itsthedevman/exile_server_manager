module.exports = {
  apps : [{
    name: "ESM",
    script: 'bin/start.rb',
    instances: -1,
    autorestart: true,
    watch: true,
    env_production : {
      "RAILS_ENV": "production",
      "ESM_ENV": "production"
    }
  }]
};
