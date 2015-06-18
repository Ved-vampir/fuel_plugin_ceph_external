# create new conf on primary Ceph MON, pull conf on all other nodes
class ceph_external::conf {

  $rbd_cinder_user = $::ceph_external::cinder_user
  $rbd_nova_user   = $::ceph_external::compute_user
  $rbd_glance_user = $::ceph_external::glance_user
  $rbd_cinder_key  = $::ceph_external::cinder_key
  $rbd_nova_key    = $::ceph_external::compute_key
  $rbd_glance_key  = $::ceph_external::glance_key

  file { 'ceph_dir':
   ensure => directory,
   path => '/etc/ceph',
  }
  file { 'ceph_conf':
   ensure => present,
   path   => '/etc/ceph/ceph.conf',
   source => "puppet:///modules/ceph/ceph.conf",
   mode => '0664',
   require => File['ceph_dir'],
  }

  file { 'keyring_bin':
   ensure => present,
   content => template('ceph_external/keyring.bin.erb'),
   path   => '/etc/ceph/keyring.bin',
   mode => '0664',
   require => File['ceph_dir'],
  }
 # file { 'keyring_bin':
 #  ensure => present,
 #  path   => '/etc/ceph/keyring.bin',
 #  source => "puppet:///modules/ceph/keyring.bin",
 #  mode => '0664',
 #  require => File['ceph_dir'],
 # }

  File['ceph_conf'] -> File['keyring_bin']

}
