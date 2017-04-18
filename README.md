# Testing PuppetDB on compile masters

## To Start the stack

```
vagrant destroy -f
vagrant up
vagrant ssh puppet-master-centos -c "sudo puppet agent -t"
```

## To Confirm you can run an agent against the compile master with PuppetDB

```
vagrant ssh compile-master-puppetdb -c "sudo puppet agent -t --server compile-master-puppetdb --certname test"

```

The setup is handled by the vagrant stack but here are the details

1.  Add `puppet_enterprise::profile::puppetdb' to your compile master
2.  Configure puppetdb.conf on the compile master to connect to the local puppetdb
  - This causes the compile masters to connect to the puppetdb_host that is local to it I suppose it also makes the MoM connect to it's puppetdb but it was already doing that.  
  - You could provide a comma delimited list of $clientcert and the fqdn of your MoM if you wanted the master to fail over to the MoM when it can't connect to the local puppetdb
    - I recommend that if the local puppetdb on the compile master stops working that you instead remove the compile master from your load balancer instead of failing over just puppetdb traffic.  

The setup used by the stack is somewhat fragile and likely to break in future versions of PE.  However, the basic idea that you can run puppetdb on a compile master is proved and it's not complicated.


# Puppet Debugging Kit
_The only good bug is a dead bug._

This project provides a batteries-included Vagrant environment for debugging Puppet powered infrastructures.

# Tuning PuppetDB and Puppet Server Together

## Disable gc-interval on PuppetDB

Only one PuppetDB should ever perform GC on the database so each compile master should disable [gc-interval](https://docs.puppet.com/puppetdb/latest/configure.html#gc-interval).

## CPUs = puppet server jrubies + puppetdb command processing threads + 1

In order to prevent a situation in which a thundering herd of traffic would cause puppet server and puppetdb to compete for resources you want to make sure jrubies + command processing threads < # CPUs.

I recommend setting PuppetDB command processing threads to 1 to start with and see if that allows for adequate throughput.  You can monitor the QueueSize in PuppetDB with the [pe_metric_curl_cron_jobs](https://github.com/npwalker/pe_metric_curl_cron_jobs) to make sure you're not seeing a backup of commands.  If you do see a backup then add a command processing thread and reduce by one jruby.

## Set max_connections in PostgreSQL to 1000

Each PuppetDB uses 50 connections to PostgreSQL by default.  So, you need to increase max_connections to allow for all of those connections.

If you are adding more than 4 puppetdb nodes then you might want to consider tuning down the connection pools to reduce the connection overhead on the postgresql side.  There are parameters for read and write connection pool sizes in the puppet_enterprise module.

My understanding is that you need a read connection for each jruby instance and you need roughly 2x command processing threads for write connections.  This assumes the console will use the PuppetDB instance on the MoM for it's read queries.

## Setup

Getting the debugging kit ready for use consists of three steps:

  - Ensure the proper Vagrant plugins are installed.

  - Create VM definitions in `config/vms.yaml`.

  - Clone Puppet Open Source projects to `src/puppetlabs` (optional).

Rake tasks and templates are provided to help with all three steps.

### Install Vagrant Plugins

Two methods are avaible depending on whether a global Vagrant installation, such as provided by the official packages from [vagrantup.com](http://vagrantup.com), is in use:

  - `rake setup:global`:
    This Rake task will add all plugins required by the debugging kit to a global Vagrant installation.

  - `rake setup:sandboxed`:
    This Rake task will use Bundler to create a completely sandboxed Vagrant installation that includes the plugins required by the debugging kit.
    The contents of the sandbox can be customized by creating a `Gemfile.local` that specifies additional gems and Bundler environment parameters.

### Create VM Definitions

Debugging Kit virtual machine definitions are stored in the file `config/vms.yaml` and an example is provided as `config/vms.yaml.example`.
The example can simply be copied to `config/vms.yaml` but it contains a large number of VM definitions which adds some notable lag to Vagrant start-up times.
Start-up lag can be remedied by pruning unwanted definitions after copying the example file.

### Clone Puppet Open Source Projects

The `poss-envpuppet` role is designed to run Puppet in guest machines directly from Git clones located on the host machine at `src/puppetlabs/`.
This role is useful for inspecting and debugging changes in behavior between versions without re-installing packages.
The required Git clones can be created by running the following Rake task:

    rake setup:poss


## Usage

Use of the debugging kit consists of:

  - Creating a new VM definition in `config/vms.yaml`.
    The `box` component determines which Vagrant basebox will be used.
    The default baseboxes can be found in [`data/puppet_debugging_kit/boxes.yaml`](https://github.com/puppetlabs/puppet-debugging-kit/blob/internal/data/puppet_debugging_kit/boxes.yaml).

  - Assigning a list of "roles" that customize the VM behavior.
    The role list can be viewed as a stack in which the last entry is applied first.
    Most VMs start with the `base` role which auto-assigns an IP address and sets up network connectivity.
    The default roles can be found in [`data/puppet_debugging_kit/roles.yaml`](https://github.com/puppetlabs/puppet-debugging-kit/blob/internal/data/puppet_debugging_kit/roles.yaml) and are explained in more detail below.


### PE Specific Roles

There are three roles that assist with creating PE machines:

  - `pe-forward-console`:
    This role sets up a port forward for console accesss from 443 on the guest VM to 4443 on the host machine.
    If some other running VM is already forwarding to 4443 on the host, Vagrant will choose a random port number that will be displayed in the log output when the VM starts up.

  - `pe-<version>-master`:
    This role performs an all-in-one master installation of PE `<version>` on the guest VM.
    When specifying the version number, remove any separators such that `3.2.1` becomes `321`.
    The PE console is configured with username `admin@puppetlabs.com` and password `puppetlabs`.

  - `pe-<version>-agent`:
    This role performs an agent installation of PE `<version>` on the guest VM.
    The agent is configured to contact a master running at `pe-<version>-master.puppetdebug.vlan` --- so ensure a VM with that hostname is configured and running before bringing up any agents.


### POSS Specific Roles

There are a few roles that assist with creating VMs that run Puppet Open Source Software (POSS).

  - `poss-apt-repos`:
    This role configures access to the official repositories at apt.puppetlabs.com for Debian and Ubuntu VMs.

  - `poss-yum-repos`:
    This role configures access to the official repositories at yum.puppetlabs.com for CentOS and Fedora VMs.


## Extending and Contributing

The debugging kit can be thought of as a library of configuration and data for [Oscar](https://github.com/adrienthebo/oscar).
Data is loaded from two sets of YAML files:

```
config
└── *.yaml         # <-- User-specific customizations
data
└── puppet_debugging_kit
    └── *.yaml     # <-- The debugging kit library
```

Everything under `data/puppet_debugging_kit` is loaded first.
In order to avoid merge conflicts when the library is updated, these files should never be edited unless you plan to submit your changes as a pull request.

The contents of `config/*.yaml` are loaded next and can be used to extend or override anything provided by `data/puppet_debugging_kit`.
These files are not tracked by Git and are where user-specific customizations should go.

---
<p align="center">
  <img src="http://i.imgur.com/TFTT0Jh.png" />
</p>
