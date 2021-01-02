module.exports = {
  apps : [{
    name: "ESM",
    script: 'bin/start_prod.rb',
    exec_interpreter: "bundle exec /home/wolf/.rbenv/shims/ruby",
    exec_mode: "fork_mode",
    instances: -1,
    autorestart: true,
    watch: true,
    env_production : {
      RAILS_ENV: "production",
      ESM_ENV: "production",
      RACK_ENV: "production"
    }
  }]
};
