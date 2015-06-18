# Enable RBD backend for ephemeral volumes
class ceph_external::ephemeral (
  $rbd_secret_uuid     = $::ceph_external::rbd_secret_uuid,
  $libvirt_images_type = $::ceph_external::libvirt_images_type,
  $pool                = $::ceph_external::compute_pool,
) {

  nova_config {
    'libvirt/images_type':      value => $libvirt_images_type;
    'libvirt/inject_key':       value => false;
    'libvirt/inject_partition': value => '-2';
    'libvirt/images_rbd_pool':  value => $pool;
  }
}
