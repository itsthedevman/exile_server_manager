module.exports = {
  apps : [{
    name: "ESM",
    script: 'bin/prod',
    exec_interpreter: "bash",
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
