ini_setting { 'reject-large-commands' :
  ensure  => present,
  path    => '/etc/puppetlabs/puppetdb/conf.d/config.ini',
  section => 'command-processing',
  setting => 'reject-large-commands',
  value   => 'false',
  notify  => Service['pe-puppetdb'],
}

service { 'pe-puppetdb' :
  ensure => 'running',
} 
