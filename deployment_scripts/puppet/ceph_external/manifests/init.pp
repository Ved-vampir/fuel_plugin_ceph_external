# ceph configuration and resource relations

class ceph_external (
      # General settings
#      $cluster_node_address = $::ipaddress, #This should be the cluster service address
#      $primary_mon          = $::hostname, #This should be the first controller
#      $mon_hosts            = nodes_with_roles($::fuel_settings['nodes'],
#                                               ['primary-controller', 'controller', 'ceph-mon'],
#                                               'name'),
#      $mon_ip_addresses     = nodes_with_roles($::fuel_settings['nodes'],
#                                               ['primary-controller', 'controller', 'ceph-mon'],
#                                               'internal_address'),
#      $osd_devices          = split($::osd_devices_list, ' '),
      $use_ssl              = false,
      $use_rgw              = false,

      # ceph.conf Global settings
#      $auth_supported            = 'cephx',
#      $osd_journal_size          = '2048',
#      $osd_mkfs_type             = 'xfs',
#      $osd_pool_default_size     = $::fuel_settings['storage']['osd_pool_size'],
#      $osd_pool_default_min_size = '1',
#      $osd_pool_default_pg_num   = $::fuel_settings['storage']['pg_num'],
#      $osd_pool_default_pgp_num  = $::fuel_settings['storage']['pg_num'],
#      $cluster_network           = undef,
#      $public_network            = undef,

      # RadosGW settings
#      $rgw_host                         = $::hostname,
#      $rgw_port                         = '6780',
#      $swift_endpoint_port              = '8080',
#      $rgw_keyring_path                 = '/etc/ceph/keyring.radosgw.gateway',
#      $rgw_socket_path                  = '/tmp/radosgw.sock',
#      $rgw_log_file                     = '/var/log/ceph/radosgw.log',
#      $rgw_use_keystone                 = true,
#      $rgw_use_pki                      = false,
#      $rgw_keystone_url                 = "${cluster_node_address}:5000",
#      $rgw_keystone_admin_token         = $::fuel_settings['keystone']['admin_token'],
#      $rgw_keystone_token_cache_size    = '10',
#      $rgw_keystone_accepted_roles      = '_member_, Member, admin, swiftoperator',
#      $rgw_keystone_revocation_interval = $::ceph::rgw_use_pki ? { false => 1000000, default => 60},
#      $rgw_data                         = '/var/lib/ceph/radosgw',
#      $rgw_dns_name                     = "*.${::domain}",
#      $rgw_print_continue               = true,
#      $rgw_nss_db_path                  = '/etc/ceph/nss',

      # Keystone settings
#      $rgw_pub_ip = $cluster_node_address,
#      $rgw_adm_ip = $cluster_node_address,
#      $rgw_int_ip = $cluster_node_address,

      # Cinder settings
      $volume_driver      = 'cinder.volume.drivers.rbd.RBDDriver',
      $glance_api_version = '2',
      $cinder_user        = $::fuel_settings['ceph_external']['cinder_user'],
      $cinder_key         = $::fuel_settings['ceph_external']['cinder_key'],
      $cinder_pool        = $::fuel_settings['ceph_external']['cinder_pool'],
      # TODO: generate rbd_secret_uuid
      $rbd_secret_uuid    = 'a5d0dd94-57c4-ae55-ffe0-7e3732a24455',

      # Glance settings
      $glance_backend        = 'ceph',
      $glance_user           = $::fuel_settings['ceph_external']['glance_user'],
      $glance_key            = $::fuel_settings['ceph_external']['glance_key'],
      $glance_pool           = $::fuel_settings['ceph_external']['glance_pool'],
      $show_image_direct_url = 'True',

      # Compute settings
      $compute_user          = $::fuel_settings['ceph_external']['compute_user'],
      $compute_key           = $::fuel_settings['ceph_external']['compute_key'],
      $compute_pool          = $::fuel_settings['ceph_external']['compute_pool'],
      $libvirt_images_type   = 'rbd',

      # Log settings
      $use_syslog            = false,
      $syslog_log_facility   = 'daemon',
      $syslog_log_level      = 'info',
) {

  Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
         cwd  => '/root',
  }

  # Re-enable ceph::yum if not using a Fuel iso with Ceph packages
  #include ceph::yum

  if $::fuel_settings['role'] =~ /controller|ceph|compute|cinder/ {
    # the regex above includes all roles that require ceph.conf
    include ceph_external::params
    include ceph_external::conf
    Class[['ceph_external::params']] -> Class['ceph_external::conf']
  }

#  if $::fuel_settings['role'] =~ /controller|ceph/ {
#    service {'ceph':
#      ensure  => 'running',
#      enable  => true,
#      require => Class['ceph_external::conf']
#    }
#    Package<| title == 'ceph' |> ~> Service<| title == 'ceph' |>
#    if !defined(Service['ceph']) {
#      notify{ "Module ${module_name} cannot notify service ceph on packages update": }
#    }
#  }

  case $::fuel_settings['role'] {
    'primary-controller', 'controller': {
      include cinder::volume


      package { 'cinder':
        name    => $::cinder::params::package_name,
        ensure => installed,
      }

      class {'cinder::volume::rbd':
        rbd_pool        => $::ceph_external::cinder_pool,
        rbd_user        => $::ceph_external::cinder_user,
        rbd_secret_uuid => $::ceph_external::rbd_secret_uuid,
      } ->

      exec {'cinder_volume_service_hack':
        command => "/bin/sed -i 's/manual//' $::cinder::params::ceph_init_override",
      }


      Class['ceph_external::conf'] ->
      Class['cinder::volume::rbd'] ~> Service[$::ceph_external::params::service_cinder_volume]

      service {$::ceph_external::params::service_glance_api:
        ensure => true
      }

      glance_api_config {
        'glance_store/stores':  value => 'glance.store.rbd.Store,glance.store.http.Store';
      } ->

      class {'glance::backend::rbd':
        rbd_store_user         => $::ceph_external::glance_user,
        rbd_store_ceph_conf    => '/etc/ceph/ceph.conf',
        rbd_store_pool         => $::ceph_external::glance_pool,
      }

      Class['ceph_external::conf'] ->
      Class['glance::backend::rbd'] ~> Service[$::ceph_external::params::service_glance_api]
    }

    'compute': {

      include ceph_external::nova_compute

      service {$::ceph_external::params::service_nova_compute:
        ensure => true
      }


      if ($::fuel_settings['ceph_external']['ephemeral_ceph']) {
        include ceph_external::ephemeral
        Class['ceph_external::conf'] -> Class['ceph_external::ephemeral'] ~>
        Service[$::ceph_external::params::service_nova_compute]
      }

      Class['ceph_external::conf'] ->
      Class['ceph_external::nova_compute'] ~>
      Service[$::ceph_external::params::service_nova_compute]
    }


    default: {}
  }
}
