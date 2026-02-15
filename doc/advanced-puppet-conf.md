# Configuring puppet.conf for catalog compilation

octocatalog-diff allows you to specify puppet configuration settings that will be used during catalog compilation. This is useful when your Puppet code depends on specific puppet.conf settings.

## Options

There are two ways to configure puppet settings:

1. **`--puppet-conf`**: Provide a path to an existing puppet.conf file
2. **`--puppet-config`**: Specify individual settings on the command line

Both options support per-branch variants (`--from-puppet-conf`, `--to-puppet-conf`, etc.) allowing you to test the effects of configuration changes.

## Using --puppet-conf

Specify a path to a puppet.conf file that will be copied to the compilation directory:

```bash
# Absolute path
octocatalog-diff -n node.example.com --puppet-conf /etc/puppetlabs/puppet/puppet.conf

# Relative path (relative to basedir)
octocatalog-diff -n node.example.com --puppet-conf puppet.conf
```

### Per-branch puppet.conf

You can use different puppet.conf files for each catalog:

```bash
octocatalog-diff -n node.example.com \
  --from-puppet-conf /path/to/old/puppet.conf \
  --to-puppet-conf /path/to/new/puppet.conf
```

## Using --puppet-config

Specify individual settings without needing a puppet.conf file:

```bash
octocatalog-diff -n node.example.com \
  --puppet-config basemodulepath=/opt/modules \
  --puppet-config environment_timeout=unlimited
```

### Setting format

Settings can be specified in two formats:

- `setting=value` - Places the setting in the `[main]` section
- `section/setting=value` - Places the setting in a specific section

Examples:

```bash
# Settings for [main] section
--puppet-config basemodulepath=/opt/modules
--puppet-config environment_timeout=unlimited

# Settings for [agent] section
--puppet-config agent/server=puppet.example.com

# Settings for [master] section
--puppet-config master/storeconfigs=true
```

### Per-branch settings

```bash
octocatalog-diff -n node.example.com \
  --from-puppet-config environment_timeout=0 \
  --to-puppet-config environment_timeout=unlimited
```

## Combining --puppet-conf and --puppet-config

When both options are used, settings from `--puppet-config` will override values from the `--puppet-conf` file:

```bash
octocatalog-diff -n node.example.com \
  --puppet-conf /etc/puppetlabs/puppet/puppet.conf \
  --puppet-config basemodulepath=/custom/modules
```

## Configuration file

You can set these options in your configuration file:

```ruby
# Using a puppet.conf file
settings[:puppet_conf] = '/etc/puppetlabs/puppet/puppet.conf'

# Using individual settings
settings[:puppet_config] = [
  'basemodulepath=/opt/modules',
  'environment_timeout=unlimited',
  'agent/server=puppet.example.com'
]
```

## Disabling puppet.conf

If you need to explicitly prevent puppet.conf installation (e.g., to override a configuration file setting):

```bash
octocatalog-diff -n node.example.com --no-puppet-conf
```
