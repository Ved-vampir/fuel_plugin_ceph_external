# configure the nova_compute parts if present
class ceph_external::nova_compute (
  $rbd_secret_uuid     = $::ceph_external::rbd_secret_uuid,
  $user                = $::ceph_external::compute_user,
  $compute_pool        = $::ceph_external::compute_pool,
) {

  file {'/root/secret.xml':
    content => template('ceph_external/secret.erb')
  }
  
  file { '/root/script.sh':
   ensure => present,
   path   => '/root/script.sh',
   source => "puppet:///modules/ceph_external/script.sh",
   mode => '0775',
  }

  exec {'Set Ceph RBD secret for Nova':
    # TODO: clean this command up
#    command => "virsh secret-set-value --secret $( \
#      virsh secret-define --file /root/secret.xml | \
#      egrep -o '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') \
#      --base64 $(ceph auth get-key client.${user}) && \
#      rm /root/secret.xml",
    command => "virsh secret-set-value --secret $( \
      virsh secret-define --file /root/secret.xml | \
      egrep -o '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') \
      --base64 $(/root/script.sh $user) && \
      rm /root/secret.xml",
 
 }

  nova_config {
    'libvirt/rbd_secret_uuid':          value => $rbd_secret_uuid;
    'libvirt/rbd_user':                 value => $user;
  }

  File['/root/secret.xml'] ->
  File['/root/script.sh'] ->
  Exec['Set Ceph RBD secret for Nova']
}
